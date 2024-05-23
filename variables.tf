###################################################################################################################
### Global Variables ##############################################################################################
###################################################################################################################
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}



###################################################################################################################
### Route53  Variables ############################################################################################
###################################################################################################################
variable "domain_name" {
  description = "The domain name to register and manage"
  type        = string
  default     = "valo-pfe.com"
}

###################################################################################################################
### Cloudfront variables ############################################################################################
###################################################################################################################

variable "create_distribution" {
  description = "Controls if CloudFront distribution should be created."
  type        = bool
  default     = true
}

variable "aliases" {
  description = "Extra CNAMEs (alternate domain names), if any, for this distribution."
  type        = list(string)
  default     = null
}

variable "comment" {
  description = "Any comments you want to include about the distribution."
  type        = string
  default     = null
}

variable "default_root_object" {
  description = "The object that you want CloudFront to return (for example, index.html) when an end user requests the root URL."
  type        = string
  default     = "index.html"
}

variable "enabled" {
  description = "Whether the distribution is enabled to accept end user requests for content."
  type        = bool
  default     = true
}

variable "http_version" {
  description = "The maximum HTTP version to support on the distribution. Allowed values are http1.1 and http2. The default is http2."
  type        = string
  default     = "http2"
}

variable "is_ipv6_enabled" {
  description = "Whether the IPv6 is enabled for the distribution."
  type        = bool
  default     = null
}

variable "price_class" {
  description = "The price class for this distribution. One of PriceClass_All, PriceClass_200, PriceClass_100."
  type        = string
  default     = "PriceClass_100"
}

variable "retain_on_delete" {
  description = "Disables the distribution instead of deleting it when destroying the resource through Terraform. If this is set, the distribution needs to be deleted manually afterwards."
  type        = bool
  default     = false
}

variable "wait_for_deployment" {
  description = "If enabled, the resource will wait for the distribution status to change from InProgress to Deployed. Setting this tofalse will skip the process."
  type        = bool
  default     = true
}

variable "web_acl_id" {
  description = "If you're using AWS WAF to filter CloudFront requests, the Id of the AWS WAF web ACL that is associated with the distribution. The WAF Web ACL must exist in the WAF Global (CloudFront) region and the credentials configuring this argument must have waf:GetWebACL permissions assigned. If using WAFv2, provide the ARN of the web ACL."
  type        = string
  default     = null
}

variable "tags" {
  type = object({
    application_code    = string
    account_category    = string
    data_classification = optional(string)
    owner               = string
    cost_center         = string
    name                = optional(string)
    context             = optional(string)
    namespace           = optional(string)
    id                  = optional(string)
    critical_data       = optional(string)
    environment         = optional(string)
    reverse             = optional(bool)
    backup              = optional(bool)
    schedule            = optional(string)
    schedule_exception  = optional(string)
  })

  description = "(Required) Details the tags mandatory to apply to BPI landing zone."

  validation {
    condition     = contains(["c0", "c1", "c2", "c3"], var.tags.data_classification)
    error_message = "Valid values: `c0`, `c1`, `c2`, `c3` (lower case)."
  }

  default = null
}


variable "origin" {
  type = list(object({
    domain_name              = string
    origin_id                = string
    origin_path              = optional(string)
    connection_attempts      = optional(string)
    connection_timeout       = optional(string)
    origin_access_control_id = optional(string)

    custom_headers = optional(list(object({
      name  = optional(string)
      value = optional(string)
    })))

    custom_origin_config = optional(object({
      http_port                = number
      https_port               = number
      origin_protocol_policy   = string
      origin_ssl_protocols     = list(string)
      origin_keepalive_timeout = optional(number)
      origin_read_timeout      = optional(number)
    }))
    s3_origin_config = optional(object({
      origin_access_identity = string
    }))
  }))
  description = "One or more s3/custom origins for this distribution (multiples allowed). See documentation for configuration options description https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#origin-arguments."

  default = [
    {
      domain_name              = aws_s3_bucket.default.bucket_regional_domain_name
      origin_id                = aws_s3_bucket.default.id
      origin_path              = "/"
      connection_attempts      = "3"
      connection_timeout       = "10"
      origin_access_control_id = aws_cloudfront_origin_access_identity.my_oai.id
    }
  ]
}

variable "origin_group" {
  description = "None, one or more origin_group for this distribution (multiples allowed)."
  type = list(object({
    origin_id = string
    failover_criteria = object({
      status_codes = list(string)
    })
    primary_member = object({
      origin_id = string
    })
    secondary_member = object({
      origin_id = string
    })
  }))
  default = []
}


variable "viewer_certificate" {
  description = "The SSL configuration for this distribution."
  type = object({
    acm_certificate_arn            = optional(string)
    cloudfront_default_certificate = bool
    iam_certificate_id             = optional(string)
    minimum_protocol_version       = optional(string)
    ssl_support_method             = optional(string)
  })
}

variable "geo_restriction" {
  description = "The restriction configuration for this distribution (geo_restrictions) - At least RU should be blocked."
  type = object({
    restriction_type = string
    locations        = list(string)
  })
}

variable "logging_config" {
  description = "The logging configuration that controls how logs are written to your distribution (maximum one)."
  type = object({
    bucket          = string
    prefix          = string
    include_cookies = optional(bool)
  })
}

variable "custom_error_response" {
  # http://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/custom-error-pages.html#custom-error-pages-procedure
  # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#custom-error-response-arguments
  type = list(object({
    error_caching_min_ttl = optional(string)
    error_code            = string
    response_code         = optional(string)
    response_page_path    = optional(string)
  }))

  description = "List of one or more custom error response element maps."
  default     = []
}

variable "default_cache_behavior" {
  type = object({
    target_origin_id       = string
    viewer_protocol_policy = string
    allowed_methods        = list(string)
    cached_methods         = list(string)
    compress               = optional(bool)
    smooth_streaming       = optional(bool)
    trusted_signers        = optional(list(string))
    trusted_key_groups     = optional(list(string))

    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = string
    realtime_log_config_arn    = optional(string)


    min_ttl     = optional(number)
    default_ttl = optional(number)
    max_ttl     = optional(number)

    use_forwarded_values      = bool
    forward_query_string      = optional(bool)
    query_string_cache_keys   = optional(list(string))
    forward_header_values     = optional(list(string))
    forward_cookies           = optional(string)
    cookies_whitelisted_names = optional(list(string))

    lambda_function_association = optional(list(object({
      event_type   = string
      include_body = optional(bool)
      lambda_arn   = string
    })))

    function_association = optional(list(object({
      event_type   = string
      function_arn = string
    })))
  })
  description = <<DESCRIPTION
A Default list of cache behaviors resource for this distribution. List from top to bottom in order of precedence. The topmost cache behavior will have precedence 0.
The fields can be described by the other variables in this file. For example, the field 'lambda_function_association' in this object has
a description in var.lambda_function_association variable earlier in this file. The only difference is that fields on this object are in ordered caches, whereas the rest
of the vars in this file apply only to the default cache. Put value `""` on field `target_origin_id` to specify default s3 bucket origin.
See : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#default-cache-behavior-arguments
DESCRIPTION
}

variable "ordered_cache_behavior" {
  type = list(object({
    path_pattern           = string
    target_origin_id       = string
    viewer_protocol_policy = string
    allowed_methods        = list(string)
    cached_methods         = list(string)
    compress               = optional(bool)
    smooth_streaming       = optional(bool)
    trusted_signers        = optional(list(string))
    trusted_key_groups     = optional(list(string))

    cache_policy_id            = optional(string)
    origin_request_policy_id   = optional(string)
    response_headers_policy_id = string
    realtime_log_config_arn    = optional(string)


    min_ttl     = optional(number)
    default_ttl = optional(number)
    max_ttl     = optional(number)

    use_forwarded_values      = bool
    forward_query_string      = optional(bool)
    query_string_cache_keys   = optional(list(string))
    forward_header_values     = optional(list(string))
    forward_cookies           = optional(string)
    cookies_whitelisted_names = optional(list(string))

    lambda_function_association = optional(list(object({
      event_type   = string
      include_body = optional(bool)
      lambda_arn   = string
    })))

    function_association = optional(list(object({
      event_type   = string
      function_arn = string
    })))
  }))
  default     = []
  description = <<DESCRIPTION
An ordered list of cache behaviors resource for this distribution. List from top to bottom in order of precedence. The topmost cache behavior will have precedence 0.
The fields can be described by the other variables in this file. For example, the field 'lambda_function_association' in this object has
a description in var.lambda_function_association variable earlier in this file. The only difference is that fields on this object are in ordered caches, whereas the rest
of the vars in this file apply only to the default cache. Put value `""` on field `target_origin_id` to specify default s3 bucket origin.
See : https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudfront_distribution#default-cache-behavior-arguments
DESCRIPTION
}

variable "create_monitoring_subscription" {
  description = "If enabled, the resource for monitoring subscription will created."
  type        = bool
  default     = false
}

variable "realtime_metrics_subscription_status" {
  description = "A flag that indicates whether additional CloudWatch metrics are enabled for a given CloudFront distribution. Valid values are `Enabled` and `Disabled`."
  type        = string
  default     = "Enabled"
}

###################################################################################################################
### S3_frontend variables #########################################################################################
###################################################################################################################

##############################################################################
# Tags
##############################################################################
variable "tags" {
  type = object({
    application_code    = string
    account_category    = string
    data_classification = string
    owner               = string
    cost_center         = string
    name                = optional(string)
    context             = optional(string)
    namespace           = optional(string)
    id                  = optional(string)
    critical_data       = optional(string)
    environment         = string
    reverse             = bool
    backup              = bool
    schedule            = optional(string)
    schedule_exception  = optional(string)
  })

  description = "(Required) Details the tags mandatory to apply to BPI landing zone."

  validation {
    condition     = contains(["c0", "c1", "c2", "c3"], var.tags.data_classification)
    error_message = "Valid values:  `c0`, `c1`, `c2`, `c3` (lower case)."
  }
}

##############################################################################
# Inputs
##############################################################################
variable "name" {
  type        = string
  default     = null
  description = "Name for the bucket. If omitted, Terraform will assign a random, unique name."
}


variable "policy" {
  type        = string
  default     = null
  description = "A valid bucket policy JSON document. Note that if the policy document is not specific enough (but still valid), Terraform may view the policy as constantly changing in a `terraform plan`. In this case, please make sure you use the verbose/specific version of the policy."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "A boolean that indicates all objects (including any [locked objects](https://docs.aws.amazon.com/AmazonS3/latest/dev/object-lock-overview.html)) should be deleted from the bucket so that the bucket can be destroyed without error. These objects are `not̀ recoverable."
}

variable "transfer_acceleration_enabled" {
  type        = bool
  default     = false
  description = "Set this to `true` to enable S3 Transfer Acceleration for the bucket. **Note** : unavailable in `cn-north-1` or `us-gov-west-1`"
}

variable "versioning_enabled" {
  type        = bool
  default     = true
  description = "A state of [versioning](https://docs.aws.amazon.com/AmazonS3/latest/dev/Versioning.html). Versioning is a means of keeping multiple variants of an object in the same bucket"
}

# variable "create_replication_bucket" {
#   type        = bool
#   default     = false
#   description = "Set this to `true` to create a source bucket with a replication rule and a destination bucket"
# }
######## Bucket logging inputs ########

variable "logging" {
  type = object({
    target_bucket_name = string
    target_prefix      = string
  })
  default     = null
  description = <<EOF
A configuration for bucket access logging : https://docs.aws.amazon.com/AmazonS3/latest/userguide/ServerLogs.html </br>
Server access logging provides detailed records for the requests that are made to a bucket.

`target_bucket_name` : The name of the bucket that will receive the log objects.
`target_prefix`      : To specify a key prefix for log objects (optional).

:warning: **Note** : You will have to declare all objects properties when using this module variable input.
EOF
}

######## Bucket Inventory inputs ########

variable "inventory_rules" {
  type = object({
    name                     = string
    enabled                  = bool
    included_object_versions = string
    filter = object({
      prefix = string
    })
    schedule = object({
      frequency = string
    })
    optional_fields = list(string)
    destination = object({
      bucket = object({
        account_id        = string
        format            = string
        bucket_arn        = string
        prefix            = string
        encryption_type   = string
        encryption_key_id = string
      })
    })
  })
  default     = null
  description = <<EOF
Bucket Inventory Rules to use

`name` : Unique identifier of the inventory configuration for the bucket.
`enabled` : Specifies whether the inventory is enabled or disabled.
`included_object_versions` : Object versions to include in the inventory list. Valid values: All, Current.
`filter` : Specifies an inventory filter. The inventory only includes objects that meet the filter's criteria
  `prefix` : The prefix that an object must have to be included in the inventory results.
`schedule` : Specifies the schedule for generating inventory results
  `frequency` : Specifies how frequently inventory results are produced. Valid values: Daily, Weekly.
`optional_fields` : List of optional fields that are included in the inventory results. Valid values:
  - BucketKeyStatus
  - ChecksumAlgorithm
  - ETag
  - EncryptionStatus
  - IntelligentTieringAccessTier
  - IsMultipartUploaded
  - LastModifiedDate
  - ObjectLockLegalHoldStatus
  - ObjectLockMode
  - ObjectLockRetainUntilDate
  - ReplicationStatus
  - Size
  - StorageClass
`destination` : Contains information about where to publish the inventory results
  `bucket` : The S3 bucket configuration where inventory results are published (documented below).
    - bucket_arn : The Amazon S3 bucket ARN of the destination.
    - format : Specifies the output format of the inventory results. Can be CSV, ORC or Parquet.
    - account_id : The ID of the account that owns the destination bucket. Recommended to be set to prevent problems if the destination bucket ownership changes.
    - prefix : The prefix that is prepended to all inventory results.
    - encryption_type : Contains the type of server-side encryption to use to encrypt the inventory. Can be sse_kms, sse_s3
    - encryption_key_id : (Required if encryption_type=sse_kms) The ARN of the KMS customer master key (CMK) used to encrypt the inventory file.

:warning: **Note** : You will have to declare all objects properties when using this module variable input. As examples, the "prefix" cannot be omitted and needs to be declared as "null", or if you declare an "destination" object, you'll also have to declare all its unused properties as "null").
EOF
}

######## Bucket lifecycles inputs ########

variable "lifecycle_rules" {
  type = list(object({
    id                                     = string
    prefix                                 = optional(string)
    enabled                                = optional(bool)
    abort_incomplete_multipart_upload_days = optional(number) // Should Appear at least once
    transition = optional(list(object({
      days          = optional(string)
      date          = optional(string)
      storage_class = optional(string)
    })))
    expiration = optional(object({
      days                         = optional(string)
      date                         = optional(string)
      expired_object_delete_marker = optional(bool)
    }))
    filter = optional(object({
      prefix = optional(string)
    }))
    noncurrent_version_transition = optional(list(object({
      newer_noncurrent_versions = optional(number)
      days                      = optional(number)
      storage_class             = optional(string)
    })))
    noncurrent_version_expiration = optional(list(object({
      newer_noncurrent_versions = optional(number)
      days                      = optional(number)
    })))
  }))
  default = [{
    id      = "MandatoryLifecycle"
    enabled = true

    abort_incomplete_multipart_upload_days = 1
    noncurrent_version_transition = [{
      days                      = 7
      newer_noncurrent_versions = 7
      storage_class             = "INTELLIGENT_TIERING"
    }]
    noncurrent_version_expiration = [{
      days                      = 90
      newer_noncurrent_versions = 7
    }]
  }]
  description = <<EOF
Bucket lifecycle Rules to use

`id` : Unique identifier for the rule
`prefix` : Object key prefix identifying one or more objects to which the rule applies.
`tags` : Specifies object tags key and value.
`enabled` : Specifies lifecycle rule status
`abort_incomplete_multipart_upload_days` : Specifies the number of days after initiating a multipart upload when the multipart upload must be completed. Should appear at least once.
`transition` : A lifecycle transitions map supporting 3 keys. Should appear at least once.
  - Date : Specifies the date after which you want the corresponding action to take effect.
  - Days : Specifies the number of days after object creation when the specific rule action takes effect.
  - Storage Class : Specifies the Amazon S3 storage class to which you want the object to transition. Can be ONEZONE_IA, STANDARD_IA, INTELLIGENT_TIERING, GLACIER, or DEEP_ARCHIVE.
`expiration` : A lifecycle expiration map consisting of 3 keys.
  - Date : Specifies the date after which you want the corresponding action to take effect.
  - Days : Specifies the number of days after object creation when the specific rule action takes effect.
  - Expired_object_delete_marker : On a versioned bucket (versioning-enabled or versioning-suspended bucket), you can add this element in the lifecycle configuration to direct Amazon S3 to delete expired object delete markers
`noncurrent_version_transition` : A lifecycle transitions map for the noncurrent_version objects, supporting 2 keys.
  - Days : Specifies the number of days noncurrent object versions transition.
  - Storage Class : Specifies the Amazon S3 storage class to which you want the noncurrent object versions to transition. Can be ONEZONE_IA, STANDARD_IA, INTELLIGENT_TIERING, GLACIER, or DEEP_ARCHIVE.
`noncurrent_version_expiration` : (Optional) Specifies the number of days noncurrent object versions expire.
  - Days : Specifies the number of days after object creation when the specific rule action takes effect.
  - Newer Noncurrent Versions : Specifies the number of version to retain
:warning: **Note** : You will have to declare all objects properties when using this module variable input. As examples, the "prefix" cannot be omitted and needs to be declared as "null", or if you declare an "expiration" object, you'll also have to declare all its unused properties as "null").
EOF
}

variable "kms_master_key_id" {
  type        = string
  default     = null
  description = "The AWS KMS master key ID used for the SSE-KMS encryption"
}

variable "allow_encrypted_uploads_only" {
  type        = bool
  default     = true
  description = "Set to `true` to prevent uploads of unencrypted objects to S3 bucket"
}

######## Public visibility ########

variable "block_public_acls" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the blocking of new public access lists on the bucket"
}

variable "block_public_policy" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the blocking of new public policies on the bucket"
}

variable "ignore_public_acls" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the ignoring of public access lists on the bucket"
}

variable "restrict_public_buckets" {
  type        = bool
  default     = true
  description = "Set to `false` to disable the restricting of making the bucket public"
}


variable "object_lock_enabled" {
  type        = bool
  default     = false
  description = "Set to `true` to enable object lock for the bucket"
}

variable "object_lock_configuration" {
  type = object({
    mode  = string
    days  = number
    years = number
  })
  default     = null
  description = <<EOF
A configuration for S3 object locking : https://docs.aws.amazon.com/AmazonS3/latest/dev/object-lock.html </br>
With S3 Object Lock, you can store objects using a `write once, read many` (WORM) model.
Object Lock can help prevent objects from being deleted or overwritten for a fixed amount of time or indefinitely.

`mode`  : The default Object Lock retention mode you want to apply to new objects placed in this bucket. Valid values are `GOVERNANCE` and `COMPLIANCE`.
`days`  : The number of days that you want to specify for the default retention period (optional).
`years` : The number of years that you want to specify for the default retention period (optional).

:warning: **Note** : You will have to declare all objects properties when using this module variable input.
EOF
}

######## Website Configuration ########
variable "website_configurations" {
  type = object({
    index_document = optional(string)
    error_document = optional(string)
    redirect_all_requests_to = optional(object({
      host_name = optional(string)
      protocol  = optional(string)
    }))
    routing_rules = optional(string)
  })
  default     = null
  description = <<EOF
Specifies the configuration when using static website hosting for this bucket.

`index_document`           : Amazon S3 returns this index document when requests are made to the root domain or any of the subfolders Required, unless using `redirect_all_requests_to`).
`error_document`           : An absolute path to the document to return in case of a 4XX error (optional).
`redirect_all_requests_to` : A hostname to redirect all website requests for this bucket to. Hostname can optionally be prefixed with a protocol (`http://` or `https://`) to use when redirecting requests. The default is the protocol that is used in the original request (optional).
`routing_rules`            : A json array containing routing rules describing redirect behavior and when redirects are applied : https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-websiteconfiguration-routingrules.html </br>
:warning: **Note** : You will have to declare all objects properties when using this module variable input.
EOF
}

######## CORS Configuration ########

variable "cors_rules" {
  type = list(object({
    allowed_headers = list(string)
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = list(string)
    max_age_seconds = number
  }))
  default     = null
  description = <<EOF
Rules configuration when using CORS on this bucket : https://docs.aws.amazon.com/AmazonS3/latest/dev/cors.html </br>

`allowed_headers` : Specifies which headers are allowed (optional).
`allowed_methods` : Specifies which methods are allowed. Can be `GET`, `PUT`, `POST`, `DELETE` or `HEAD`.
`allowed_origins` : Specifies which origins are allowed.
`expose_headers`  : Specifies expose header in the response (optional).
`max_age_seconds` : Specifies time in seconds that browser can cache the response for a preflight request (optional).

:warning: **Note** : You will have to declare all objects properties when using this module variable input.
EOF
}

######## Bucket Ownership Controls ########
variable "object_ownership" {
  type        = string
  default     = "BucketOwnerEnforced"
  description = "Define default object ownership when object is uploaded."

  validation {
    condition     = contains(["BucketOwnerEnforced", "BucketOwnerPreferred", "ObjectWriter"], var.object_ownership)
    error_message = "Invalid value, can be either BucketOwnerEnforced, BucketOwnerPreferred or ObjectWriter."
  }
}

variable "reverse_enabled" {
  type        = bool
  default     = false
  description = "Whether or not to allow the bucket to be used to reverse purposes"
}