# Settings for tflint.
# Modules get their Terraform and provider versions from the root (versions.tf),
# so we turn off these two rules that want versions inside every module.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}
