variable "project_name" {
  description = "Nome base do projeto"
  type        = string
  default     = "analisador-camera"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "kinesis_shard_count" {
  description = "Quantidade de shards do Kinesis Data Stream"
  type        = number
  default     = 1
}

variable "create_producer_user" {
  description = "Se true, cria um usuário IAM e access keys para o produtor local"
  type        = bool
  default     = true
}
