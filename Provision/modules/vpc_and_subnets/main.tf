# setup aws terraform provider version to be used
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.6.2"
    }
  }
}

# to retrieve the availability zones
data "aws_availability_zones" "available" {}


locals {
  # newbits is the new mask for the subnet, which means it will divide the VPC into 256 (2^(32-24)) subnets.
  newbits = 8

  # netcount is the number of subnets that we need, which is 6 in this case
  netcount = 6

  # cidrsubnet function is used to divide the VPC CIDR block into multiple subnets
  all_subnets = [for i in range(local.netcount) : cidrsubnet(var.vpc_cidr, local.newbits, i)]

  # we create 3 public subnets and 3 private subnets using these subnet CIDRs
  public_subnets  = slice(local.all_subnets, 0, 3)
  private_subnets = slice(local.all_subnets, 3, 6)
}

# vpc module to create vpc, subnets, NATs, IGW etc..
module "vpc_and_subnets" {
  # invoke public vpc module
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  # vpc name
  name = var.name

  # availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # vpc cidr
  cidr = var.vpc_cidr

  # public and private subnets
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets

  # create nat gateways
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  one_nat_gateway_per_az = var.one_nat_gateway_per_az

  # enable dns hostnames and support
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  # tags for public, private subnets and vpc
  tags                = var.tags
  public_subnet_tags  = var.additional_public_subnet_tags
  private_subnet_tags = var.additional_private_subnet_tags

  # create internet gateway
  create_igw       = var.create_igw
  instance_tenancy = var.instance_tenancy

}

// ecr.tf
resource "aws_ecr_repository" "frontend_app" {
  name                 = "bndz/frontend" 
  image_tag_mutability = "MUTABLE"       
  force_delete         = true            

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "frontend-app-ecr"
    Project   = "bndz-app"
    CreatedBy = "Terraform"
  }
}

resource "aws_ecr_repository" "backend_app" {
  name                 = "bndz/backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name      = "backend-app-ecr"
    Project   = "bndz-app"
    CreatedBy = "Terraform"
  }
}


# Security Group for Jenkins EC2
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH, HTTP, and Jenkins port"
  vpc_id      = module.vpc_and_subnets.vpc_id

  ingress {
    from_port   = 22 // SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // IMPORTANT: Restrict this to your IP for production
  }
  ingress {
    from_port   = 80 // HTTP
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080 // Jenkins default port
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] // IMPORTANT: Restrict this
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "jenkins-sg"
  }
}

resource "aws_instance" "jenkins_server" {
  ami                    = "ami-0afc7fe9be84307e4"
  instance_type          = "t3.medium"             
  subnet_id              = element(module.vpc_and_subnets.public_subnets, 0) 
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id, module.vpc_and_subnets.default_security_group_id] 

  associate_public_ip_address = true 
  key_name = var.ec2_key_name

  # User data script to install Jenkins, Docker, kubectl, AWS CLI
  user_data = <<-EOF
              #!/bin/bash
              sudo yum update -y

              # Install Java (Jenkins requirement - Amazon Corretto 11 or 17 recommended)
              sudo yum install java-17-amazon-corretto-devel -y

              # Install Jenkins
              sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
              sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key # Check for latest key
              sudo yum install jenkins -y
              sudo systemctl enable jenkins
              sudo systemctl start jenkins

              # Install Docker
              sudo yum install docker -y
              sudo systemctl enable docker
              sudo systemctl start docker
              sudo usermod -a -G docker ec2-user
              sudo usermod -a -G docker jenkins # Allow jenkins user to run docker commands

              # Install Git
              sudo yum install git -y

              # Install kubectl
              # Check for the latest stable version compatible with your EKS cluster_version (1.29 in this example)
              curl -LO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
              sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
              rm kubectl

              # Install AWS CLI v2 (often pre-installed on AL2, but good to ensure)
              # Check if already installed and at a good version
              if ! command -v aws &> /dev/null || ! aws --version | grep -q 'aws-cli/2'; then
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                unzip awscliv2.zip
                sudo ./aws/install --update
                rm -rf awscliv2.zip aws
              fi

              # (Optional) Install Helm for Kubernetes package management
              # curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
              # chmod 700 get_helm.sh
              # ./get_helm.sh
              # rm get_helm.sh

              # Ensure jenkins user's shell is bash for easier `sudo su - jenkins`
              sudo chsh -s /bin/bash jenkins
              sudo systemctl restart jenkins # To apply docker group changes and shell change

              EOF

  tags = {
    Name      = "jenkins-server"
    Project   = "my-nodejs-app"
    CreatedBy = "Terraform"
  }

}
