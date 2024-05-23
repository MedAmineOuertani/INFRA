##############################################################################
# Create S3 Bucket
##############################################################################
locals {
  // check if kms key id is set
  require_kms_encryption = var.kms_master_key_id != null
}

#tfsec:ignore:AWS002
resource "aws_s3_bucket" "default" {
  #checkov:skip=CKV_AWS_144: Ensure that S3 bucket has cross-region replication enabled
  #checkov:skip=CKV_AWS_19: "Ensure all data stored in the S3 bucket is securely encrypted at rest"
  #checkov:skip=CKV_AWS_145: "Ensure that S3 buckets are encrypted with KMS by default"
  #checkov:skip=CKV2_AWS_62: "Ensure S3 buckets should have event notifications enabled"


  # depends_on = [aws_s3_bucket.replication]
  tags = merge(var.tags, {
    git_commit = "818fcfce9e8f7171e2009dd1c00d08fda22163ea"
    git_repo   = "CLD/public/terraform/aws/terraform-aws-s3-bucket"
    yor_trace  = "c1004fb5-d30d-4591-a6fb-35ee84842f74"
  })
  bucket              = var.name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
}

resource "aws_s3_bucket_accelerate_configuration" "accelerate_default" {
  count  = var.transfer_acceleration_enabled ? 1 : 0
  bucket = aws_s3_bucket.default.bucket
  status = var.transfer_acceleration_enabled ? "Enabled" : "Suspended"
}

// Define Object Lock configuration rule
resource "aws_s3_bucket_object_lock_configuration" "object_lock_default" {
  bucket = aws_s3_bucket.default.bucket
  // count = var.object_lock_configuration != null ? 1 : 0
  // DAP@Team : Enable versioning is required on your s3 bucket to be able to update later its conf.
  count = var.object_lock_configuration != null && var.versioning_enabled == true ? 1 : 0

  rule {
    default_retention {
      mode  = var.object_lock_configuration.mode
      days  = var.object_lock_configuration.days
      years = var.object_lock_configuration.years
    }
  }

  // You must contact AWS support for the bucket's "Object Lock token".
  // The token is generated in the back-end when versioning is enabled on a bucket.
  // DAP@Team see https://registry.terraform.io/providers/hashicorp%20%20/aws/latest/docs/resources/s3_bucket_object_lock_configuration
}

# --------------------------------------------------------------------------
# -> cors_rule Configuration
# Use dynamic and for_each
# --------------------------------------------------------------------------
resource "aws_s3_bucket_cors_configuration" "cors_default" {
  bucket = aws_s3_bucket.default.bucket
  count  = var.cors_rules != null ? 1 : 0

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# -> Logging Configuration
resource "aws_s3_bucket_logging" "logging_default" {
  count  = var.logging != null ? 1 : 0
  bucket = aws_s3_bucket.default.id

  target_bucket = var.logging.target_bucket_name
  target_prefix = var.logging.target_prefix
}

# -> website Configuration
resource "aws_s3_bucket_website_configuration" "website_configuration_default" {
  count  = var.website_configurations != null ? 1 : 0
  bucket = aws_s3_bucket.default.id

  index_document {
    suffix = var.website_configurations.index_document
  }

  error_document {
    key = var.website_configurations.error_document
  }

  # Maybe conflicts between these 2 :
  routing_rules = var.website_configurations.routing_rules

  dynamic "redirect_all_requests_to" {
    for_each = var.website_configurations.redirect_all_requests_to != null ? [1] : []
    content {
      host_name = redirect_all_requests_to.value.host_name
      protocol  = redirect_all_requests_to.value.protocol
    }
  }
  # redirect_all_requests_to {
  #   host_name = var.website_configurations.redirect_all_requests_to.host_name
  #   protocol  = var.website_configurations.redirect_all_requests_to.protocol
  # }
}

# --------------------------------------------------------------------------
# -> Lifecycle Configuration
# --------------------------------------------------------------------------
resource "aws_s3_bucket_lifecycle_configuration" "bucket_config_default" {
  #checkov:skip=CKV_AWS_300: "Ensure S3 lifecycle configuration sets period for aborting failed uploads"
  // Rule is skipped because set to default and specified in multiple documentation
  // Even in the variable description, it is however mandatory to have
  // Lifecycles for failed upload, but even for old versions
  // And A transition condition is mandatory is possible
  // An expiration is strongly recommanded and mandatory depending on
  // The French, european or worldwide regulations you application falls under.
  bucket = aws_s3_bucket.default.id

  dynamic "rule" {

    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"

      abort_incomplete_multipart_upload {
        days_after_initiation = rule.value.abort_incomplete_multipart_upload_days != null ? rule.value.abort_incomplete_multipart_upload_days : 1
      }

      # -> transition
      dynamic "transition" {
        # for_each = each.value.transition
        for_each = rule.value.transition != null ? rule.value.transition : []
        content {
          storage_class = transition.value.storage_class
          days          = transition.value.days
          date          = transition.value.date
        }
      }

      filter {
        prefix = rule.value.filter != null ? rule.value.filter.prefix : null
      }
      # -> expiration
      expiration {
        days                         = rule.value.expiration != null ? rule.value.expiration.days : null
        date                         = rule.value.expiration != null ? rule.value.expiration.date : null
        expired_object_delete_marker = rule.value.expiration != null ? rule.value.expiration.expired_object_delete_marker : null
      }
      # -> noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transition != null ? rule.value.noncurrent_version_transition : []
        content {
          newer_noncurrent_versions = noncurrent_version_transition.value.newer_noncurrent_versions
          storage_class             = noncurrent_version_transition.value.storage_class
          noncurrent_days           = noncurrent_version_transition.value.days
        }
      }
      # -> noncurrent_version_expiration
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? rule.value.noncurrent_version_expiration : []
        content {
          newer_noncurrent_versions = noncurrent_version_expiration.value.newer_noncurrent_versions
          noncurrent_days           = noncurrent_version_expiration.value.days
        }
      }
    }
  }
}

# --------------------------------------------------------------------------
# -> DAP@Team Inventory Configuration
# --------------------------------------------------------------------------
resource "aws_s3_bucket_inventory" "inventory_config_default" {
  count  = var.inventory_rules != null ? 1 : 0
  bucket = aws_s3_bucket.default.id

  name                     = var.inventory_rules.name
  included_object_versions = var.inventory_rules.included_object_versions
  enabled                  = var.inventory_rules.enabled
  optional_fields          = var.inventory_rules.optional_fields

  # -> schedule
  schedule {
    frequency = var.inventory_rules.schedule.frequency
  }

  # -> filter
  filter {
    prefix = var.inventory_rules.filter.prefix
  }

  # -> destination
  destination {
    bucket {
      account_id = var.inventory_rules.destination.bucket.account_id
      format     = var.inventory_rules.destination.bucket.format
      bucket_arn = var.inventory_rules.destination.bucket.bucket_arn
      prefix     = var.inventory_rules.destination.bucket.prefix
      # -> encryption
      dynamic "encryption" {
        for_each = var.inventory_rules.destination.bucket.encryption_type == "sse_kms" || var.inventory_rules.destination.bucket.encryption_type == "sse_s3" ? [1] : []
        content {
          # -> sse_kms
          dynamic "sse_kms" {
            for_each = var.inventory_rules.destination.bucket.encryption_type == "sse_kms" ? [1] : []
            content {
              key_id = var.inventory_rules.destination.bucket.encryption_key_id
            }
          }
          # -> sse_s3
          dynamic "sse_s3" {
            for_each = var.inventory_rules.destination.bucket.encryption_type == "sse_s3" ? [1] : []
            content {}
          }
        }
      }
    }
  }
}

# --------------------------------------------------------------------------
# -> Define versioning
# --------------------------------------------------------------------------
resource "aws_s3_bucket_versioning" "versioning_default" {
  bucket = aws_s3_bucket.default.id
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Disabled"
  }
}

# --------------------------------------------------------------------------
# -> Encryption Configuration (always encrypted) - no dynamic required
# --------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption_default" {
  bucket = aws_s3_bucket.default.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.kms_master_key_id
      sse_algorithm     = local.require_kms_encryption ? "aws:kms" : "AES256"
    }
    bucket_key_enabled = local.require_kms_encryption
  }
}

###############################################################################
# Bucket Policy
###############################################################################

## Uploads Encryption
data "aws_iam_policy_document" "bucket_policy" {

  # --------------------------------------------------------------------------
  # -> SSL Only statement Configuration
  # Use dynamic and for_each with a single value only if defined
  # --------------------------------------------------------------------------

  statement {
    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.my_oai.iam_arn]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.example.arn,
      "${aws_s3_bucket.example.arn}/*",
    ]
  }
  }

resource "aws_s3_bucket_policy" "default" {
  bucket = aws_s3_bucket.default.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}


  # --------------------------------------------------------------------------
  # -> Encryption statement Configuration
  # Use dynamic and for_each with a single value only if defined
  # --------------------------------------------------------------------------

  # -> DenyIncorrectEncryptionHeader
  dynamic "statement" {
    for_each = var.allow_encrypted_uploads_only && local.require_kms_encryption == false ? [1] : []
    content {
      sid       = "DenyIncorrectEncryptionHeader"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.default.arn}/*"]

      principals {
        identifiers = ["*"]
        type        = "*"
      }

      condition {
        test = "StringNotEquals"
        values = [
          "AES256",
          "aws:kms"
        ]
        variable = "s3:x-amz-server-side-encryption"
      }
    }
  }
  # -> DenyUnEncryptedObjectUploads
  dynamic "statement" {
    for_each = var.allow_encrypted_uploads_only && local.require_kms_encryption == false ? [1] : []
    content {
      sid       = "DenyUnEncryptedObjectUploads"
      effect    = "Deny"
      actions   = ["s3:PutObject"]
      resources = ["${aws_s3_bucket.default.arn}/*"]

      principals {
        identifiers = ["*"]
        type        = "*"
      }

      condition {
        test     = "Null"
        values   = ["true"]
        variable = "s3:x-amz-server-side-encryption"
      }
    }
  }

  # --------------------------------------------------------------------------
  # -> SSL Add Reverse Acl
  # --------------------------------------------------------------------------

  dynamic "statement" {
    for_each = var.reverse_enabled ? [1] : []

    content {
      sid       = "AllowReverseUsage"
      effect    = "Allow"
      actions   = ["s3:GetObject", "s3:ListBucket"]
      resources = [aws_s3_bucket.default.arn, "${aws_s3_bucket.default.arn}/*"]

      principals {
        identifiers = ["arn:aws:iam::373983172505:user/bpi-fr-clp-tech-reversibilite-ovh"]
        type        = "AWS"
      }
    }
  }
}

# Merge policy given by user with policy created
data "aws_iam_policy_document" "merged_policy" {
  source_policy_documents   = var.policy != null ? [var.policy] : [""]
  override_policy_documents = [data.aws_iam_policy_document.bucket_policy.json]
}

## Set policy on bucket if needed (policy given by user or by choosed options)


# Refer to the terraform documentation on s3_bucket_public_access_block at
# https://www.terraform.io/docs/providers/aws/r/s3_bucket_public_access_block.html
# for the details of the blocking options
resource "aws_s3_bucket_public_access_block" "default" {
  count                   = var.block_public_acls || var.block_public_policy || var.ignore_public_acls || var.restrict_public_buckets ? 1 : 0
  bucket                  = aws_s3_bucket.default.id
  block_public_acls       = var.block_public_acls
  block_public_policy     = var.block_public_policy
  ignore_public_acls      = var.ignore_public_acls
  restrict_public_buckets = var.restrict_public_buckets
}

###############################################################################
# Bucket Ownership
###############################################################################

resource "aws_s3_bucket_ownership_controls" "tfstate_bucket_ownership" {
  bucket = aws_s3_bucket.default.id

  rule {
    object_ownership = var.object_ownership
  }
}