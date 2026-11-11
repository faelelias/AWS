# Newcon IIS APIs — ativo/passivo em EC2 existentes

Primeira versao para validacao em HML. Nao aplicada na AWS. Nao representa homologacao pela Newcon.

## Comportamento solicitado

Sensedia -> ALB interno HTTPS/443 -> um dos dois target groups HTTPS/443, cada um com uma EC2. As EC2 devem estar em AZs diferentes da mesma VPC. FSx e RDS existentes nao sao criados nem modificados. O backend SQL Server permanece TCP/1433.

EventBridge chama Lambda a cada minuto. Duas observacoes distintas consecutivas com instancia fora de running ou status EC2 System/Instance impaired disparam Step Functions. Status desconhecido/initializing nao promove. A reserva deve estar running, saudavel e SSM Online antes de solicitar stop da ativa.

A automacao solicita StopInstances normal, sem Force; apos resposta de sucesso espera 180 segundos, inicia componentes listados na reserva via SSM, aguarda HTTP 200 no health check do ALB e troca o listener inteiro para o target group reserva. Nao usa pesos 100/0 no listener de producao nem registra as duas EC2 no mesmo grupo ativo. O grupo reserva recebe health checks, mas nao trafego de producao antes da troca. Um listener tecnico HTTPS/8443 associa permanentemente ambos os grupos ao ALB para permitir health checks; NAO existe regra de entrada para 8443. Nunca abrir essa porta no SG nem publica-la no Sensedia, pois ela encaminharia trafego a ambos os grupos.

Se a solicitacao StopInstances falhar, bloqueia; nao interpreta erro como desligamento iniciado. Se o principal ainda estiver running/stopping apos 180 segundos, promove mesmo assim, conforme solicitado. Isso NAO e fencing: podem ocorrer processamento simultaneo, transacoes duplicadas, concorrencia em arquivos e perda de consistencia. Mesmo removido do ALB, o antigo principal pode executar tarefas e acessar RDS/FSx. A automacao NAO garante exclusividade Newcon e NAO monitora continuamente a conclusao do stop. Operacoes deve acompanhar a EC2 anterior ate stopped.

Nao ha failback automatico. Uma falha posterior da reserva gera alerta e exige intervencao. A tabela DynamoDB registra o papel ativo; Terraform ignora alteracoes do default_action para nao desfazer a troca em novo apply. Nao destruir/recriar listener, tabela ou state machine durante operacao.

## Tempo de recuperacao

Deteccao aproximada de 1–2 minutos + 180 segundos de espera + SSM/inicializacao/health check. Pode superar 5 minutos. O disparo depende do plano de controle EC2, EventBridge, DynamoDB, Step Functions, Lambda, SSM e ELB. Este projeto nao garante RTO de 5 minutos nem protege contra indisponibilidade regional. Grafana permanece observabilidade independente; falha de IIS com EC2 saudavel nao dispara troca nesta versao.

## Pre-requisitos obrigatorios

- Duas EC2 Windows existentes, mesmo modulo IIS APIs, mesmo pool `newcon-pool`, em AZs diferentes habilitadas no ALB; AMI/snapshot apenas para copia inicial, sem sincronizacao continua de disco local.
- SSM Agent atualizado com suporte a interpolationType ENV_VAR, instancias Online, IAM instance profile e conectividade SSM adequados. Terraform nao altera os perfis existentes.
- WebAdministration instalado, sites/bindings/certificados IIS ja configurados, FSx e RDS acessiveis por ambas as EC2. Caminhos, identidades de pool, segredos e permissoes precisam funcionar na copia.
- Liste TODOS os servicos e tarefas de negocio nas variaveis. Somente `newcon-pool` e conhecido. Nao se inicia todo o processamento do Windows. Se houver processos disparados por outros mecanismos, inventariar antes de habilitar.
- O documento standby desabilita tarefas, solicita parada, para servicos listados e configura Manual, configura pool autoStart=false e o para. Confirmar que processos filhos terminaram; Stop-ScheduledTask nao equivale a fencing de processos externos. Nunca executar standby na ativa em producao sem janela.
- O documento active inicia WAS/W3SVC, servicos listados e pool; habilita tarefas para seus proximos triggers, sem Start-ScheduledTask indiscriminado. Mantem servicos Manual e pool autoStart=false. Configuracoes originais devem ser registradas antes da preparacao. Reboot da ativa exige recuperacao operacional; nao ha auto-start condicionado a papel.
- URL GET existente, sem efeitos colaterais, retornando 200. IIS deve aceitar o Host baseado no IP privado usado pelo health check ALB; validar bindings/SNI. Preservar Host do Sensedia nao muda o Host dos health checks.
- Certificado ACM na mesma regiao e DNS do backend correspondente; rede Sensedia -> ALB interno. DNS/Sensedia nao sao alterados por este projeto.
- Cookies devem ser preservados para sticky sessions. Sticky nao transfere memoria/sessoes ASP.NET entre maquinas; requisicoes em andamento podem falhar e exigir novo login. Retry de escrita no gateway exige idempotencia validada.
- SNS criado sem assinantes: conectar a canal corporativo existente e confirmar entrega antes dos testes. Alarme de erros Lambda incluido. Falhas/timeouts de Step Functions tambem devem ser acompanhados pela operacao; timeout global pode deixar trava switching para intervencao manual.
- As regras SG adicionadas permitem ALB -> EC2/443, mas nao removem acessos existentes. Nao misturar regras inline autoritativas de SG em outro Terraform sem reconciliar ownership.

## Implantacao (validar em HML primeiro)

1. Executar na pasta `consorcio/hml/alb` (ou `consorcio/prd/alb` apos homologacao). Copiar `terraform.tfvars.example` para `terraform.tfvars`; substituir TODOS os placeholders. Usar estado/backend remoto corporativo com locking. Backend propositalmente nao inventado. HML e PRD precisam de states separados, nomes e IDs distintos.
2. `terraform init` e `terraform fmt -check`; executar `terraform validate` e `terraform plan -var-file=terraform.tfvars`. Conferir criacoes e regras SG. O apply NAO cria EC2, nao prepara Windows e nao redireciona Sensedia automaticamente.
3. `terraform apply -var-file=terraform.tfvars` com as tres flags false. Conectar SNS. Verificar que primary e o destino do listener e que o health check funciona.
4. Preparar a RESERVA pelo documento SSM, apos listar servicos/tarefas. Exemplo PowerShell:

```powershell
aws ssm send-command --region ca-central-1 --instance-ids i-STANDBY --document-name newcon-api-hml-role --parameters 'Role=standby'
```

5. Registrar resultado do CommandId, confirmar Status Success e verificar pool/tarefas/servicos e processos filhos. Preparar tambem o comportamento de boot da ativa em janela: pool autoStart=false, servicos listados Manual; manter pool/servicos atualmente em execucao. Tarefas da antiga ativa devem permanecer desabilitadas quando ela for religada para preparacao. Esse preparo e operacional e nao e executado automaticamente pelo apply.
6. Ajustar `standby_prepared=true` e `accept_overlap_risk=true`. Para teste manual manter `enable_automatic_failover=false`; aplicar. Todas as promocoes, inclusive manuais, exigem essas duas flags.
7. Testar troca manual com JSON em arquivo, sem inline escaping:

```json
{"mode":"manual","target":"standby"}
```

Salvar como `switch.json` e executar:

```powershell
aws stepfunctions start-execution --region ca-central-1 --state-machine-arn ARN_DO_OUTPUT --input file://switch.json
```

8. Verificar principal em stopping/stopped, 180 segundos completos antes de promover, reserva saudavel e listener alterado; confirmar requisicoes reais via Sensedia, banco e FSx. Medir RTO e conferir duplicidade de processamento.
9. Habilitar `enable_automatic_failover=true` somente depois da preparacao e teste. Duas observacoes de falha de maquina disparam o fluxo. Um stop intencional da ativa tambem dispara failover: desabilitar flag antes de manutencao.

## Retorno manual fora do expediente

1. Desabilitar failover automatico no tfvars e aplicar; registrar papel atual e listener.
2. Antigo principal: impedir disparo de tarefas/processamento no boot antes de religa-lo; preparar pool/servicos/tarefas em standby. Nao religar uma copia com tarefas habilitadas. Validar SSM, FSx, RDS e versao da aplicacao; garantir maquina running e saudavel.
3. Executar state machine com `{"mode":"manual","target":"primary"}`. O mesmo fluxo para a reserva ativa, aguarda 180s e promove primary. Esta versao nao liga EC2 parada automaticamente.
4. Conferir listener e DynamoDB, voltar a preparar a reserva e habilitar monitoramento automatico quando apropriado.

## Falha parcial / recuperacao

Trava DynamoDB nao expira automaticamente. Se erro apos claim, phase=blocked; se timeout global, pode permanecer switching. Nao limpar cegamente: uma execucao SSM pode ter iniciado processamento, e listener pode ter mudado antes de erro no DynamoDB/SNS. Inspecionar as duas EC2, todas as tarefas/servicos, listener e execucoes. Apos encerrar comandos/execucoes pendentes, reconciliar active com o destino real, remover owner, zerar misses e colocar phase=idle. So entao retomar. Nao ha rollback automatico que religue o antigo principal.

O estado default inicial e primary. Nao perder/apagar a tabela: recria-la durante failover pode causar nova tentativa incorreta. Restrinja start-execution e escrita na tabela a operadores autorizados. Falha de permissao de stop, SSM offline, reserva unhealthy e concorrencia devem ser testadas em HML.

## Validacao de fornecedor pendente

Nao foi localizada documentacao publica tecnica suficiente do Newcon para homologar esta topologia. O desenho fornecido registra sticky sessions por pedido da fornecedora e FSx compartilhado, mas nao confirma licenciamento, processamento concorrente ou semantica de tarefas. Confirmar esses pontos antes de PRD. Este pacote atende ao mecanismo AWS solicitado, com risco explicito de sobreposicao apos 3 minutos.

## Referencias oficiais

## Verificacoes realizadas nesta entrega

- Terraform 1.13.5: fmt -check e validate aprovados (AWS provider 6.72.0; archive 2.8.1, fixados em .terraform.lock.hcl).
- Cinco testes offline aprovados: bloqueio antes de 180s, promocao com principal ainda running, reserva sem saude, proibicao de retorno automatico e erro na solicitacao stop.
- Sintaxe PowerShell aprovada pelo parser do Windows PowerShell.
- Nao executados: terraform plan contra conta real, apply, SSM real, conectividade Sensedia/IIS, failover AWS e homologacao Newcon. Preencher variaveis e validar em HML.

Executar testes offline com Python 3.12: `python test_worker.py`.

### Documentacao

- https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_StopInstances.html
- https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/monitoring-system-instance-status-check.html
- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/rule-action-types.html
- https://docs.aws.amazon.com/elasticloadbalancing/latest/application/target-group-health-checks.html
- https://docs.aws.amazon.com/systems-manager/latest/userguide/documents-syntax-data-elements-parameters.html


## Organizacao conforme padrao do repositorio

Cada pasta alb e uma raiz Terraform independente. Executar comandos dentro dela.

| Arquivo | Conteudo |
| --- | --- |
| main.tf | ALB e locals |
| listener.tf | Listeners HTTPS e tecnico 8443 fechado no SG |
| target_group.tf | Target groups e associacoes das EC2 existentes |
| security_group.tf | Regras de acesso |
| automation.tf | Lambda, Step Functions, SSM, EventBridge, alertas e empacotamento |
| role.tf / policies.tf | Roles e permissoes IAM |
| data.tf | Consultas a conta, VPC/subnets e EC2 |
| variables.tf | Parametros |
| tf_01_backend.tf | Orientacao para backend corporativo, sem valores inventados |
| tf_02_provider.tf | Providers e versoes |
| tf_03_outputs.tf | Outputs |
| tf_04_states.tf | Estado operacional DynamoDB da troca (nao e terraform.tfstate) |

O backend Terraform nao esta configurado: o arquivo tf_01_backend.tf contem apenas comentarios. Definir o backend corporativo antes de apply; usar keys e states distintos para HML e PRD. Nao foi criado terraform_remote_state sem os outputs e backend reais do repositorio. EC2 seguem por IDs via data sources; nenhum recurso de criacao de EC2 foi adicionado.

Arquivos Terraform foram apenas separados; nomes e enderecos de recursos foram preservados. Se ja existir state da versao anterior em outro local, migrar/reutilizar esse state no ambiente correto antes de plan/apply. Nao executar apply com state vazio sobre recursos existentes.

HML e PRD possuem exemplos distintos, com as flags de promocao desabilitadas. Nao copiar IDs/credenciais de HML para PRD. Scripts sao iguais nos dois ambientes; aplicar futuras correcoes nos dois apos teste em HML.
