variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "52.129.0.0/16"
}

variable "pub_subnet_cidr_block" {
  description = "The CIDR block for the public subnet"
  type        = string
  default     = "52.129.0.0/24"
}

variable "pub_subnet_cidr_block_2" {
  description = "The CIDR block for the second public subnet"
  type        = string
  default     = "52.129.6.0/24"
}

variable "priv_subnet_cidr_block_1" {
  description = "The CIDR block for the second private subnet"
  type        = string
  default     = "52.129.1.0/24"
}

variable "priv_subnet_cidr_block_2" {
  description = "The CIDR block for the third private subnet"
  type        = string
  default     = "52.129.2.0/24"
}

variable "bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "slyy-tata-backend-bucket"
}

variable "kms_key" {
  description = "Description for the KMS key"
  type        = string
  default     = "My KMS key"
}

variable "region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "docker-image" {
  description = "The Docker image to use for the container"
  type        = string
  default     = "slyytata/project1:v1"
}