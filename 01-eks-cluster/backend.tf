# Terraform Backend Configuration
# The remote S3 backend is disabled here because the current AWS identity
# does not have permission to access the configured bucket.
# Re-enable the S3 backend only after granting the required S3 permissions.

terraform {
  backend "local" {}
}
