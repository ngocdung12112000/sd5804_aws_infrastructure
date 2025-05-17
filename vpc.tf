// vpc.tf
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "bndz-vpc"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "bndz-igw"
  }
}

# Public Subnets (for Load Balancers, NAT Gateway, Jenkins if public)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name                                   = "bndz-public-subnet-a"
    "kubernetes.io/cluster/my-eks-cluster" = "shared" // For EKS load balancer discovery
    "kubernetes.io/role/elb"               = "1"      // For EKS load balancer discovery
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name                                   = "bndz-public-subnet-b"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }
}

# Private Subnets (for EKS worker nodes and potentially Jenkins)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.101.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]
  tags = {
    Name                                   = "bndz-private-subnet-a"
    "kubernetes.io/cluster/my-eks-cluster" = "shared" // For EKS
    "kubernetes.io/role/internal-elb"      = "1"      // For EKS internal load balancers
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.102.0/24"
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name                                   = "bndz-private-subnet-b"
    "kubernetes.io/cluster/my-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"      = "1"
  }
}

# NAT Gateway for private subnets
resource "aws_eip" "nat_eip_a" {
  domain     = "vpc" # Changed from 'vpc = true' for newer provider versions
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name = "bndz-nat-eip-a"
  }
}

resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_eip_a.id
  subnet_id     = aws_subnet.public_a.id # NAT Gateway resides in a public subnet
  tags = {
    Name = "bndz-nat-gw-a"
  }
  depends_on = [aws_internet_gateway.gw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "bndz-public-rt"
  }
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw_a.id
  }
  tags = {
    Name = "bndz-private-rt-a"
  }
}

resource "aws_route_table_association" "private_a_assoc" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b_assoc" { # Assuming both private subnets use the same NAT GW for simplicity
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_a.id # Could create a second NAT GW in public_b for HA
}

# Security Group for Jenkins EC2
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow SSH, HTTP, and Jenkins port"
  vpc_id      = aws_vpc.main.id

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