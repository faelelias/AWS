variable "ami_id" {
  description = "ID da AMI para a instância EC2"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
  default     = "t2.micro"
}

variable "subnet_id" {
  description = "ID da subnet onde a instância será criada"
  type        = string
}

variable "security_group_ids" {
  description = "Lista de IDs dos grupos de segurança"
  type        = list(string)
  default     = []
}

variable "key_name" {
  description = "Nome do par de chaves SSH"
  type        = string
}

variable "root_volume_size" {
  description = "Tamanho do volume raiz em GB"
  type        = number
  default     = 8
}

variable "root_volume_type" {
  description = "Tipo do volume raiz (gp2, gp3, io1, etc)"
  type        = string
  default     = "gp2"
}

variable "root_volume_encrypted" {
  description = "Se o volume raiz deve ser criptografado"
  type        = bool
  default     = true
}

variable "instance_name" {
  description = "Nome da instância EC2"
  type        = string
}

variable "tags" {
  description = "Tags adicionais para a instância"
  type        = map(string)
  default     = {}
}

variable "create_eip" {
  description = "Se deve criar um Elastic IP para a instância"
  type        = bool
  default     = false
} 