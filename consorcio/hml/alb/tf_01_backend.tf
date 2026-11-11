# Configurar o backend remoto corporativo ANTES de aplicar.
# Nenhum bucket/key/role foi presumido a partir das imagens.
# HML e PRD devem utilizar keys e states distintos.
# Exemplo somente (descomentar e fornecer backend.hcl real):
# terraform {
#   backend "s3" {}
# }
# terraform init -backend-config=backend.hcl
