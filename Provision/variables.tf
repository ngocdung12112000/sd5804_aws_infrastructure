variable "region" {
  type        = string
  description = "aws region where the resources are being created"
}

variable "vpc_name" {
  type        = string
  description = "name of the vpc to be created"
  default     = "eks-vpc"
}

variable "vpc_cidr" {
  type        = string
  description = "vpc cidr block to be used"
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "eks cluster name"
  default     = "devops-eks"
}

variable "k8s_version" {
  type        = string
  description = "k8s version"
  default     = "1.32"
}