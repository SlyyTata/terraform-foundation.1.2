variable "cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "52.129.0.0/16"
}

variable "subnet_cidr_block" {
  description = "The CIDR block for the subnet"
  type        = string
  default     = "52.129.0.0/24"
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