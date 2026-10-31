# bucket and region are not written here. Pass them on init:
#   terraform init -backend-config="bucket=<project>-tfstate-<account id>" -backend-config="region=<region>"
# use_lockfile stops two runs at the same time.
terraform {
  backend "s3" {
    key          = "project-atmos/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
