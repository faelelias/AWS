variable "region" { default = "ca-central-1" }
variable "name" { default = "newcon-api-hml" }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "instance_ids" {
  type = map(string)
  validation {
    condition     = length(var.instance_ids) == 2 && contains(keys(var.instance_ids), "primary") && contains(keys(var.instance_ids), "standby") && length(distinct(values(var.instance_ids))) == 2
    error_message = "Informe primary e standby com IDs distintos."
  }
}
variable "ec2_security_group_ids" { type = set(string) }
variable "sensedia_cidrs" { type = set(string) }
variable "certificate_arn" { type = string }
variable "health_check_path" {
  type        = string
  description = "Caminho GET existente, sem efeitos colaterais, retornando HTTP 200; nao testa a saude de negocio."
}
variable "pool_name" { default = "newcon-pool" }
variable "services" {
  type    = list(string)
  default = []
}
variable "scheduled_tasks" {
  type    = list(object({ name = string, path = string }))
  default = []
}
variable "enable_automatic_failover" {
  type        = bool
  default     = false
  description = "Ativar somente depois de preparar a reserva e testar em HML."
}
variable "standby_prepared" {
  type    = bool
  default = false
}
variable "accept_overlap_risk" {
  type        = bool
  default     = false
  description = "Promover apos 180 segundos mesmo sem confirmar stopped; permite processamento duplicado."
}
