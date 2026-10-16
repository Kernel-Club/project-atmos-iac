terraform {
  backend "s3" {
    bucket       = "project-atmos-tfstate-155980439303"
    key          = "project-atmos/terraform.tfstate"
    region       = "ap-northeast-2"
    encrypt      = true
    use_lockfile = true
  }
}
# Tells Terraform to keep its state file in the S3 bucket we made in bootstrap.
# - key: the path of the state file inside the bucket.
# - encrypt: the file is stored encrypted.
# - use_lockfile: Terraform creates a small lock file in S3 while it works,
#   so two people (or two terminals) cannot change the infrastructure at once.
# Note: backend blocks cannot use variables, so the values are written directly.
