# Consorcio — Newcon IIS APIs / ALB

Projeto organizado conforme o padrao das imagens do repositorio.

- HML: `consorcio/hml/alb`
- PRD: `consorcio/prd/alb`
- Modulos: `consorcio/modules` (reservado)

Abra a pasta `consorcio` no VS Code. Execute Terraform dentro da pasta `alb` do ambiente escolhido; leia o README de cada ambiente antes de aplicar.

As EC2, FSx e RDS permanecem existentes. A regra de promocao apos 180 segundos, o risco de sobreposicao e o retorno manual foram preservados. Nao aplicado na AWS.

Use `terraform.tfvars.example` para preencher as variaveis de cada ambiente. Backend corporativo pendente em `tf_01_backend.tf`; nenhum valor real foi inventado. Flags automaticas desabilitadas por padrao.

Arquivos separados por responsabilidade: main, listener, target_group, security_group, automation, role, policies, data, variables, tf_01_backend, tf_02_provider, tf_03_outputs e tf_04_states.
