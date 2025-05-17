output "vpc_id" {
  value = aws_vpc.main.id
}

output "jenkins_server_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "jenkins_server_public_dns" {
  value = aws_instance.jenkins_server.public_dns
}

# output "jenkins_ec2_iam_role_arn" {
#   value = aws_iam_role.jenkins_ec2_iam_role.arn
# }

output "eks_cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_name" {
  description = "Kubernetes Cluster Name."
  value       = module.eks.cluster_name
}

output "eks_cluster_oidc_issuer_url" {
  description = "OIDC Issuer URL for the EKS cluster, useful for IAM Roles for Service Accounts (IRSA)."
  value       = module.eks.cluster_oidc_issuer_url
}

output "eks_cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = module.eks.cluster_security_group_id
}

# output "eks_node_group_role_arn" {
#   value = aws_iam_role.eks_nodegroup_role.arn
# }