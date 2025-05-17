// ecr.tf
resource "aws_ecr_repository" "frontend_app" {
  name                 = "bndz/frontend" // Format: namespace/repository
  image_tag_mutability = "MUTABLE"       // Or IMMUTABLE for stricter versioning
  force_delete         = true            // Allows terraform destroy to remove non-empty repo. CAUTION in prod.

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
