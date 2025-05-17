# EKS Cluster using the official module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8.5" // Check for the latest stable version of the EKS module

  cluster_name    = "my-eks-cluster"
  cluster_version = "1.32" // Specify your desired Kubernetes version (check AWS supported versions)

  vpc_id     = aws_vpc.main.id
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id] // Worker nodes in private subnets

  cluster_endpoint_public_access = true // Allows kubectl access from anywhere (Jenkins)

  eks_managed_node_groups = {
    default_nodegroup = {
      name           = "default-nodegroup"
      instance_types = ["t3.medium"] // Choose appropriate instance types
      min_size       = 1
      max_size       = 2
      desired_size   = 1
      capacity_type = "SPOT" // For cost savings, if your workload tolerates interruptions

      # Ensure these subnets are tagged correctly for EKS if not using the ones created above
      subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    }
  }

  tags = {
    Environment = "dev" // Or "prod", "staging"
    Project     = "my-nodejs-app"
    CreatedBy   = "Terraform"
  }
}

