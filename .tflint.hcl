# Versions are set once in the root versions.tf, not in every module.
rule "terraform_required_version" {
  enabled = false
}

rule "terraform_required_providers" {
  enabled = false
}
