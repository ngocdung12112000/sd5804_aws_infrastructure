variable "aws_region" {
  default = "ap-southeast-1"
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "ec2_key_name" {
  description = "EC2 Key pair name"
  type        = string
  default     = "bndz-key-pair"
}

variable "eks_cluster_name" {
  default = "my-eks-cluster"
}
