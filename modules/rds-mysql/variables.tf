variable "identifier" {
  description = "Identificador da instância RDS"
  type        = string
}

variable "engine_version" {
  description = "Versão do MySQL"
  type        = string
  default     = "8.0"
}

variable "instance_class" {
  description = "Tipo da instância RDS"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Tamanho do armazenamento em GB"
  type        = number
  default     = 20
}

variable "storage_type" {
  description = "Tipo de armazenamento (gp2, gp3, io1)"
  type        = string
  default     = "gp2"
}

variable "storage_encrypted" {
  description = "Se o armazenamento deve ser criptografado"
  type        = bool
  default     = true
}

variable "database_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "username" {
  description = "Nome do usuário master"
  type        = string
}

variable "password" {
  description = "Senha do usuário master"
  type        = string
  sensitive   = true
}

variable "vpc_security_group_ids" {
  description = "Lista de IDs dos grupos de segurança"
  type        = list(string)
}

variable "db_subnet_group_name" {
  description = "Nome do grupo de subnet do RDS"
  type        = string
}

variable "multi_az" {
  description = "Se deve ser implantado em múltiplas AZs"
  type        = bool
  default     = false
}

variable "publicly_accessible" {
  description = "Se a instância deve ser acessível publicamente"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Número de dias para reter backups"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Janela de backup preferida"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Janela de manutenção preferida"
  type        = string
  default     = "Mon:04:00-Mon:05:00"
}

variable "skip_final_snapshot" {
  description = "Se deve pular o snapshot final ao deletar a instância"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags para a instância RDS"
  type        = map(string)
  default     = {}
} 