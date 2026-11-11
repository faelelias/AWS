"""Machine failover, not application HA. No credentials embedded."""
import json
import os
import time
import uuid

import boto3
from botocore.exceptions import ClientError

ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')
elb = boto3.client('elbv2')
sfn = boto3.client('stepfunctions')
sns = boto3.client('sns')
table = boto3.resource('dynamodb').Table(os.environ['TABLE'])
instances = json.loads(os.environ['INSTANCES'])
groups = json.loads(os.environ['GROUPS'])


def notify(message):
    sns.publish(TopicArn=os.environ['TOPIC'], Message=message)


def state():
    try:
        table.put_item(Item={'id': 'role', 'active': 'primary', 'phase': 'idle', 'misses': 0},
                       ConditionExpression='attribute_not_exists(id)')
    except ClientError as exc:
        if exc.response['Error']['Code'] != 'ConditionalCheckFailedException':
            raise
    return table.get_item(Key={'id': 'role'}, ConsistentRead=True)['Item']


def machine_status(instance):
    rows = ec2.describe_instance_status(InstanceIds=[instance], IncludeAllInstances=True)['InstanceStatuses']
    if not rows:
        return 'unknown'
    row = rows[0]
    if row['InstanceState']['Name'] != 'running':
        return 'bad'
    checks = [row.get(k, {}).get('Status', 'initializing') for k in ('SystemStatus', 'InstanceStatus')]
    if 'impaired' in checks:
        return 'bad'
    return 'ok' if checks == ['ok', 'ok'] else 'unknown'


def command(instance, role):
    response = ssm.send_command(InstanceIds=[instance], DocumentName=os.environ['DOCUMENT'],
                                Parameters={'Role': [role]}, TimeoutSeconds=30)
    cmd_id = response['Command']['CommandId']
    deadline = time.monotonic() + 95
    while time.monotonic() < deadline:
        try:
            result = ssm.get_command_invocation(CommandId=cmd_id, InstanceId=instance)
            status = result['Status']
            if status == 'Success':
                return
            if status in ('Cancelled', 'TimedOut', 'Failed'):
                raise RuntimeError(f'SSM {cmd_id} status {status}; inspect command output')
        except ClientError as exc:
            if exc.response['Error']['Code'] != 'InvocationDoesNotExist':
                raise
        time.sleep(3)
    raise RuntimeError(f'SSM {cmd_id} timeout; command can still run; manual inspection required')


def owned(req):
    current = state()
    if current.get('owner') != req['owner'] or current['phase'] != 'switching':
        raise RuntimeError('Execution does not own the lock')


def monitor():
    current = state()
    if current['phase'] != 'idle':
        return {'phase': current['phase']}
    status = machine_status(instances[current['active']])
    misses = int(current.get('misses', 0)) + 1 if status == 'bad' else 0
    # Ignore duplicate schedule deliveries in the same minute.
    minute = int(time.time() // 60)
    try:
        table.update_item(Key={'id': 'role'},
                          UpdateExpression='SET misses=:m, last_minute=:minute',
                          ConditionExpression='#p=:idle AND active=:a AND (attribute_not_exists(last_minute) OR last_minute < :minute)',
                          ExpressionAttributeNames={'#p': 'phase'},
                          ExpressionAttributeValues={':m': misses, ':minute': minute, ':idle': 'idle', ':a': current['active']})
    except ClientError as exc:
        if exc.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return {'skipped': True}
        raise
    if misses >= 2:
        if current['active'] == 'primary' and os.environ['ENABLED'] == 'true':
            sfn.start_execution(stateMachineArn=os.environ['MACHINE'],
                                name='auto-' + uuid.uuid4().hex,
                                input=json.dumps({'mode': 'automatic', 'target': 'standby'}))
        elif misses == 2:
            notify(f'EC2 {current["active"]} impaired/stopped; automatic failover disabled or manual return required')
    return {'status': status, 'misses': misses}


def claim(event):
    req = event['request']
    mode, target = req.get('mode'), req.get('target')
    if mode not in ('automatic', 'manual') or target not in instances:
        raise ValueError('Required: mode automatic/manual and target primary/standby')
    if os.environ['PREPARED'] != 'true' or os.environ['ACCEPT_OVERLAP'] != 'true':
        raise RuntimeError('Prepare standby and accept overlap risk first')
    current = state()
    if current['active'] == target:
        raise RuntimeError('Target is already active')
    if mode == 'automatic' and (os.environ['ENABLED'] != 'true' or current['active'] != 'primary' or int(current.get('misses', 0)) < 2):
        raise RuntimeError('Automatic return is forbidden or failure not confirmed')
    if machine_status(instances[target]) != 'ok':
        raise RuntimeError('Reserve EC2 is not healthy/running; source untouched')
    info = ssm.describe_instance_information(Filters=[{'Key': 'InstanceIds', 'Values': [instances[target]]}])
    if not any(i['PingStatus'] == 'Online' for i in info['InstanceInformationList']):
        raise RuntimeError('Reserve SSM offline; source untouched')
    table.update_item(Key={'id': 'role'}, UpdateExpression='SET #p=:switch, owner=:owner',
                      ConditionExpression='#p=:idle AND active=:a',
                      ExpressionAttributeNames={'#p': 'phase'},
                      ExpressionAttributeValues={':switch': 'switching', ':owner': event['owner'], ':idle': 'idle', ':a': current['active']})
    return {'source': current['active'], 'target': target, 'owner': event['owner']}


def handler(event, context):
    action = event['action']
    if action == 'monitor':
        return monitor()
    if action == 'claim':
        return claim(event)
    req = event['request']
    owned(req)
    if action == 'stop':
        # Normal OS shutdown only. Do not force-stop Windows.
        ec2.stop_instances(InstanceIds=[instances[req['source']]])
        req['stop_accepted_at'] = int(time.time())
        notify(f'Stop accepted for {req["source"]}; promotion after 180s even if not stopped. Overlap risk accepted.')
        return req
    if action == 'promote':
        # Step Functions Wait is durable; no Lambda sleeping for three minutes.
        if time.time() - req['stop_accepted_at'] < 180:
            raise RuntimeError('180 second wait not completed')
        source = ec2.describe_instances(InstanceIds=[instances[req['source']]])['Reservations'][0]['Instances'][0]['State']['Name']
        if source != 'stopped':
            notify(f'WARNING: promoting with source state={source}; duplicate business processing possible')
        if machine_status(instances[req['target']]) != 'ok':
            raise RuntimeError('Reserve became unhealthy')
        command(instances[req['target']], 'active')
        deadline = time.monotonic() + 55
        while True:
            health = elb.describe_target_health(TargetGroupArn=groups[req['target']])['TargetHealthDescriptions']
            if any(t['Target']['Id'] == instances[req['target']] and t['TargetHealth']['State'] == 'healthy' for t in health):
                break
            if time.monotonic() >= deadline:
                raise RuntimeError('Reserve HTTPS target unhealthy; listener not changed; processing may already be active')
            time.sleep(5)
        elb.modify_listener(ListenerArn=os.environ['LISTENER'],
                            DefaultActions=[{'Type': 'forward', 'TargetGroupArn': groups[req['target']]}])
        table.update_item(Key={'id': 'role'}, UpdateExpression='SET active=:a, #p=:idle, misses=:zero REMOVE owner',
                          ConditionExpression='owner=:owner AND #p=:switch',
                          ExpressionAttributeNames={'#p': 'phase'},
                          ExpressionAttributeValues={':a': req['target'], ':idle': 'idle', ':zero': 0, ':owner': req['owner'], ':switch': 'switching'})
        notify(f'Active={req["target"]}; former source state={source}; return manual only. Inspect old machine before restart.')
        return req
    if action == 'block':
        table.update_item(Key={'id': 'role'}, UpdateExpression='SET #p=:blocked',
                          ConditionExpression='owner=:owner',
                          ExpressionAttributeNames={'#p': 'phase'},
                          ExpressionAttributeValues={':blocked': 'blocked', ':owner': req['owner']})
        notify('Failover blocked. Inspect Step Functions, SSM, both pools/tasks and listener BEFORE clearing lock. No automatic rollback.')
        return req
    raise ValueError('Unknown action')
