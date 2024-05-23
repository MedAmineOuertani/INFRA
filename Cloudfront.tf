resource "aws_cloudfront_origin_access_identity" "my_oai" {
  comment = "My CloudFront Origin Access Identity"
}
resource "aws_cloudfront_response_headers_policy" "this" {
  name    = "cloudfront-response-headers-policy"
  comment = "A sample response headers policy"

  cors_config {
    access_control_allow_credentials = false
    access_control_allow_headers     = ["*"]
    access_control_allow_methods     = ["GET", "HEAD"]
    access_control_allow_origins     = ["*"]
    access_control_expose_headers    = ["ETag"]
    origin_override                  = true
  }

  custom_headers_config {
    items {
      header   = "X-Example-Header"
      value    = "ExampleValue"
      override = true
    }
  }

  security_headers_config {
    content_security_policy {
      content_security_policy = "default-src 'self';"
      override                = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      override                   = true
    }
    xss_protection {
      mode_block = true
      override   = true
      protection = true
    }
    referrer_policy {
      referrer_policy = "no-referrer-when-downgrade"
      override        = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
  }
}



resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV2_AWS_47: Ensure AWS CloudFront attached WAFv2 WebACL is configured with AMR for Log4j Vulnerability
  #checkov:skip=CKV2_AWS_32: Ensure CloudFront distribution has a response headers policy attached
  count = var.create_distribution ? 1 : 0

  aliases             = var.aliases
  comment             = var.comment
  default_root_object = var.default_root_object
  enabled             = var.enabled
  http_version        = var.http_version
  is_ipv6_enabled     = var.is_ipv6_enabled
  price_class         = var.price_class
  retain_on_delete    = var.retain_on_delete
  wait_for_deployment = var.wait_for_deployment
  web_acl_id          = var.web_acl_id
  tags = merge(var.tags, {
    yor_trace = "611a4b4a-75a8-4487-abcf-516eb1da17fa"
    }, {
    git_commit = "cd679179b71c55c7f8af01f7cc42a91386178696"
    git_repo   = "CLD/public/terraform/aws/terraform-aws-cloudfront-basic"
  })

  dynamic "logging_config" {
    for_each = length(keys(var.logging_config)) == 0 ? [] : [var.logging_config]

    content {
      bucket          = logging_config.value.bucket
      prefix          = lookup(logging_config.value, "prefix", null)
      include_cookies = lookup(logging_config.value, "include_cookies", null)
    }
  }

  dynamic "origin" {
    for_each = var.origin
    content {
      domain_name              = origin.value.domain_name
      origin_id                = lookup(origin.value, "origin_id", origin.key)
      origin_path              = lookup(origin.value, "origin_path", "")
      connection_attempts      = lookup(origin.value, "connection_attempts", null)
      connection_timeout       = lookup(origin.value, "connection_timeout", null)
      origin_access_control_id = lookup(origin.value, "origin_access_control_id", null)

      dynamic "s3_origin_config" {
        for_each = lookup(origin.value, "s3_origin_config", null) == null ? [] : [lookup(origin.value, "s3_origin_config", {})]
        content {
          origin_access_identity = lookup(s3_origin_config.value, "origin_access_identity", null)
        }
      }

      dynamic "custom_origin_config" {
        for_each = lookup(origin.value, "custom_origin_config", null) == null ? [] : [lookup(origin.value, "custom_origin_config", {})]
        content {
          http_port                = custom_origin_config.value.http_port
          https_port               = custom_origin_config.value.https_port
          origin_protocol_policy   = custom_origin_config.value.origin_protocol_policy
          origin_ssl_protocols     = custom_origin_config.value.origin_ssl_protocols
          origin_keepalive_timeout = lookup(custom_origin_config.value, "origin_keepalive_timeout", 60)
          origin_read_timeout      = lookup(custom_origin_config.value, "origin_read_timeout", 60)
        }
      }

      dynamic "custom_header" {
        for_each = lookup(origin.value, "custom_header", null) == null ? [] : [lookup(origin.value, "custom_header", {})]
        content {
          name  = custom_header.value.name
          value = custom_header.value.value
        }
      }

      dynamic "origin_shield" {
        for_each = lookup(origin.value, "origin_shield", null) == null ? [] : [lookup(origin.value, "origin_shield", {})]

        content {
          enabled              = origin_shield.value.enabled
          origin_shield_region = origin_shield.value.origin_shield_region
        }
      }
    }
  }
  dynamic "origin_group" {
    for_each = var.origin_group
    content {
      origin_id = lookup(origin_group.value, "origin_id", null)
      failover_criteria {
        status_codes = lookup(origin_group.value.failover_criteria, "status_codes", null)
      }
      member {
        origin_id = lookup(origin_group.value.primary_member, "origin_id", null)
      }
      member {
        origin_id = lookup(origin_group.value.secondary_member, "origin_id", null)
      }
    }
  }

  dynamic "default_cache_behavior" {
    for_each = [var.default_cache_behavior]
    iterator = i

    content {
      target_origin_id       = i.value["target_origin_id"]
      viewer_protocol_policy = i.value["viewer_protocol_policy"]

      allowed_methods = lookup(i.value, "allowed_methods", ["GET", "HEAD", "OPTIONS"])
      cached_methods  = lookup(i.value, "cached_methods", ["GET", "HEAD"])
      compress        = lookup(i.value, "compress", null)
      # field_level_encryption_id = lookup(i.value, "field_level_encryption_id", null)
      smooth_streaming   = lookup(i.value, "smooth_streaming", null)
      trusted_signers    = lookup(i.value, "trusted_signers", null)
      trusted_key_groups = lookup(i.value, "trusted_key_groups", null)

      cache_policy_id            = lookup(i.value, "cache_policy_id", null)
      origin_request_policy_id   = lookup(i.value, "origin_request_policy_id", null) // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
      response_headers_policy_id = lookup(i.value, "response_headers_policy_id", null)
      realtime_log_config_arn    = lookup(i.value, "realtime_log_config_arn", null)

      min_ttl     = lookup(i.value, "min_ttl", 0)
      default_ttl = lookup(i.value, "default_ttl", 3600)
      max_ttl     = lookup(i.value, "max_ttl", 86400)

      dynamic "forwarded_values" {
        for_each = lookup(i.value, "use_forwarded_values", true) ? [true] : []

        content {
          query_string            = lookup(i.value, "forward_query_string", false)
          query_string_cache_keys = lookup(i.value, "query_string_cache_keys", [])
          headers                 = lookup(i.value, "forward_header_values", [])

          cookies {
            forward           = lookup(i.value, "forward_cookies", "none")
            whitelisted_names = lookup(i.value, "cookies_whitelisted_names", null)
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = lookup(i.value, "lambda_function_association", null) == null ? {} : { for l in lookup(i.value, "lambda_function_association", null) : l.event_type => l }
        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lookup(lambda_function_association.value, "include_body", null)
        }
      }

      dynamic "function_association" {
        for_each = lookup(i.value, "function_association", null) == null ? {} : { for l in lookup(i.value, "function_association", null) : l.event_type => l }

        content {
          event_type   = function_association.key
          function_arn = function_association.value.function_arn
        }
      }
    }
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behavior
    iterator = i

    content {
      path_pattern           = i.value["path_pattern"]
      target_origin_id       = i.value["target_origin_id"]
      viewer_protocol_policy = i.value["viewer_protocol_policy"]

      allowed_methods           = lookup(i.value, "allowed_methods", ["GET", "HEAD", "OPTIONS"])
      cached_methods            = lookup(i.value, "cached_methods", ["GET", "HEAD"])
      compress                  = lookup(i.value, "compress", null)
      field_level_encryption_id = lookup(i.value, "field_level_encryption_id", null)
      smooth_streaming          = lookup(i.value, "smooth_streaming", null)
      trusted_signers           = lookup(i.value, "trusted_signers", null)
      trusted_key_groups        = lookup(i.value, "trusted_key_groups", null)

      cache_policy_id            = lookup(i.value, "cache_policy_id", null)
      origin_request_policy_id   = lookup(i.value, "origin_request_policy_id", null) // https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/using-managed-origin-request-policies.html
      response_headers_policy_id = lookup(i.value, "response_headers_policy_id", null)
      realtime_log_config_arn    = lookup(i.value, "realtime_log_config_arn", null)

      min_ttl     = lookup(i.value, "min_ttl", 0)
      default_ttl = lookup(i.value, "default_ttl", 3600)
      max_ttl     = lookup(i.value, "max_ttl", 86400)

      dynamic "forwarded_values" {
        for_each = lookup(i.value, "use_forwarded_values", true) ? [true] : []

        content {
          query_string            = lookup(i.value, "query_string", false)
          query_string_cache_keys = lookup(i.value, "query_string_cache_keys", [])
          headers                 = lookup(i.value, "headers", [])

          cookies {
            forward           = lookup(i.value, "cookies_forward", "none")
            whitelisted_names = lookup(i.value, "cookies_whitelisted_names", null)
          }
        }
      }

      dynamic "lambda_function_association" {
        for_each = lookup(i.value, "lambda_function_association", null) == null ? {} : { for l in lookup(i.value, "lambda_function_association", null) : l.event_type => l }

        content {
          event_type   = lambda_function_association.value.event_type
          lambda_arn   = lambda_function_association.value.lambda_arn
          include_body = lookup(lambda_function_association.value, "include_body", null)
        }
      }

      dynamic "function_association" {
        for_each = lookup(i.value, "function_association", null) == null ? {} : { for l in lookup(i.value, "function_association", null) : l.event_type => l }
        content {
          event_type   = function_association.key
          function_arn = function_association.value.function_arn
        }
      }
    }
  }

  viewer_certificate {
    acm_certificate_arn            = lookup(var.viewer_certificate, "acm_certificate_arn", null)
    cloudfront_default_certificate = lookup(var.viewer_certificate, "cloudfront_default_certificate", null)
    iam_certificate_id             = lookup(var.viewer_certificate, "iam_certificate_id", null)

    minimum_protocol_version = lookup(var.viewer_certificate, "minimum_protocol_version", "TLSv1.2_2021")
    ssl_support_method       = lookup(var.viewer_certificate, "ssl_support_method", null)
  }

  dynamic "custom_error_response" {
    for_each = var.custom_error_response
    content {
      error_code            = lookup(custom_error_response.value, "error_code", null)
      response_code         = lookup(custom_error_response.value, "response_code", null)
      error_caching_min_ttl = lookup(custom_error_response.value, "error_caching_min_ttl", null)
      response_page_path    = lookup(custom_error_response.value, "response_page_path", null)
    }
  }

  restrictions {
    dynamic "geo_restriction" {
      for_each = [var.geo_restriction]
      content {
        restriction_type = lookup(geo_restriction.value, "restriction_type", "none")
        locations        = lookup(geo_restriction.value, "locations", [])
      }
    }
  }
}

resource "aws_cloudfront_monitoring_subscription" "this" {
  count = var.create_distribution && var.create_monitoring_subscription ? 1 : 0

  distribution_id = aws_cloudfront_distribution.this[0].id

  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = var.realtime_metrics_subscription_status
    }
  }
}