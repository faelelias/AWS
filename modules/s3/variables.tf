variable "bucket_name" {
  description = "Nome do bucket S3"
  type        = string
}

variable "tags" {
  description = "Tags para o bucket S3"
  type        = map(string)
  default     = {}
}

variable "enable_versioning" {
  description = "Habilitar versionamento do bucket"
  type        = bool
  default     = false
}

variable "block_public_access" {
  description = "Bloquear todo acesso público ao bucket"
  type        = bool
  default     = true
} 