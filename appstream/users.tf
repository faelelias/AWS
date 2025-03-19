# Criar usuários para o AppStream
resource "aws_appstream_user" "users" {
  for_each = toset(var.users)

  authentication_type = "USERPOOL"
  user_name          = each.value
  first_name         = split(".", each.value)[0]
  last_name          = split(".", each.value)[1]
  enabled            = true
}

# Associar usuários ao Stack
resource "aws_appstream_user_stack_association" "user_stack_association" {
  for_each = toset(var.users)

  user_name   = each.value
  stack_name  = aws_appstream_stack.windows_stack.name
  send_email_notification = true
}

# Adicionar variável para lista de usuários
variable "users" {
  description = "Lista de usuários para o AppStream (formato: nome.sobrenome)"
  type        = list(string)
  default     = [
    "usuario1.sobrenome1",
    "usuario2.sobrenome2"
  ]
} 