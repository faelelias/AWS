# Terraform AWS Modules

Este repositório contém módulos Terraform para provisionamento de recursos AWS:

## Módulos Disponíveis

- `modules/ec2-linux`: Módulo para criação de instâncias EC2 Linux
- `modules/s3`: Módulo para criação de buckets S3
- `modules/rds-mysql`: Módulo para criação de instâncias RDS MySQL

## Como Usar

Cada módulo possui sua própria documentação e exemplos de uso. Consulte o README dentro de cada diretório de módulo para mais informações.

## Requisitos

- Terraform >= 1.0
- AWS Provider
- Credenciais AWS configuradas

## Estrutura do Projeto

```
.
├── modules/
│   ├── ec2-linux/
│   ├── s3/
│   └── rds-mysql/
└── examples/
    ├── ec2-linux/
    ├── s3/
    └── rds-mysql/
```
