# Backend values cannot be variables. use_lockfile stops two runs at the same time.
terraform {
  backend "s3" {
    bucket       = "project-atmos-tfstate-155980439303"
    key          = "project-atmos/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
