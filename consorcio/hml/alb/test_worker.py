"""Offline behavior tests; no calls to AWS."""
import importlib.util
import os
import sys
import types
import unittest
from unittest.mock import MagicMock, patch

os.environ.update(TABLE='test', INSTANCES='{"primary":"i-a","standby":"i-b"}',
                  GROUPS='{"primary":"tg-a","standby":"tg-b"}', LISTENER='listener',
                  DOCUMENT='doc', TOPIC='topic', MACHINE='machine', ENABLED='true',
                  PREPARED='true', ACCEPT_OVERLAP='true')
boto = types.ModuleType('boto3')
boto.client = MagicMock()
boto.resource = MagicMock()
sys.modules['boto3'] = boto
errors = types.ModuleType('botocore.exceptions')
errors.ClientError = type('ClientError', (Exception,), {})
sys.modules['botocore'] = types.ModuleType('botocore')
sys.modules['botocore.exceptions'] = errors
spec = importlib.util.spec_from_file_location('worker', os.path.join(os.path.dirname(__file__), 'worker.py'))
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)


class FailoverTests(unittest.TestCase):
    def setUp(self):
        self.req = {'source': 'primary', 'target': 'standby', 'owner': 'execution', 'stop_accepted_at': 0}
        w.ec2, w.elb, w.ssm, w.table, w.sns, w.sfn = [MagicMock() for _ in range(6)]

    def test_no_promotion_before_180_seconds(self):
        with patch.object(w, 'owned'), patch.object(w.time, 'time', return_value=179):
            with self.assertRaises(RuntimeError):
                w.handler({'action': 'promote', 'request': self.req}, None)
        w.ssm.send_command.assert_not_called()
        w.elb.modify_listener.assert_not_called()

    def test_promotes_even_if_source_still_running_after_wait(self):
        w.ec2.describe_instances.return_value = {'Reservations': [{'Instances': [{'State': {'Name': 'running'}}]}]}
        w.elb.describe_target_health.return_value = {'TargetHealthDescriptions': [{'Target': {'Id': 'i-b'}, 'TargetHealth': {'State': 'healthy'}}]}
        with patch.object(w, 'owned'), patch.object(w.time, 'time', return_value=181), patch.object(w, 'machine_status', return_value='ok'), patch.object(w, 'command') as cmd:
            w.handler({'action': 'promote', 'request': self.req}, None)
        cmd.assert_called_once_with('i-b', 'active')
        self.assertEqual(w.elb.modify_listener.call_args.kwargs['DefaultActions'][0]['TargetGroupArn'], 'tg-b')
        self.assertTrue(any('WARNING' in c.kwargs['Message'] for c in w.sns.publish.call_args_list))

    def test_unhealthy_reserve_does_not_route(self):
        w.ec2.describe_instances.return_value = {'Reservations': [{'Instances': [{'State': {'Name': 'stopped'}}]}]}
        with patch.object(w, 'owned'), patch.object(w.time, 'time', return_value=181), patch.object(w, 'machine_status', return_value='bad'), patch.object(w, 'command') as cmd:
            with self.assertRaises(RuntimeError):
                w.handler({'action': 'promote', 'request': self.req}, None)
        cmd.assert_not_called()
        w.elb.modify_listener.assert_not_called()

    def test_automatic_failback_rejected(self):
        with patch.object(w, 'state', return_value={'active': 'standby', 'phase': 'idle', 'misses': 2}):
            with self.assertRaises(RuntimeError):
                w.claim({'request': {'mode': 'automatic', 'target': 'primary'}, 'owner': 'execution'})
        w.ec2.stop_instances.assert_not_called()
        w.table.update_item.assert_not_called()

    def test_stop_error_propagates_before_wait(self):
        w.ec2.stop_instances.side_effect = RuntimeError('stop denied')
        with patch.object(w, 'owned'):
            with self.assertRaises(RuntimeError):
                w.handler({'action': 'stop', 'request': self.req}, None)
        w.elb.modify_listener.assert_not_called()


if __name__ == '__main__':
    unittest.main()
