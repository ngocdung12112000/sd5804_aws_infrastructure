
# Find latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "jenkins_server" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t3.large"             // Jenkins can be memory/CPU intensive; t3.medium might also work.
  subnet_id              = aws_subnet.public_a.id // Deploy in a public subnet for easier initial access
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  #iam_instance_profile   = aws_iam_instance_profile.jenkins_ec2_instance_profile.name
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
              sudo amazon-linux-extras install docker -y
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

  # Explicit dependency on the EKS module because the jenkins_ec2_iam_role.arn is used in module.eks.aws_auth_roles
  # This ensures the role exists before the EKS module tries to use its ARN.
  depends_on = [module.eks]
}

