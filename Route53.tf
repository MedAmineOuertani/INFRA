resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name
}

resource "aws_route53_record" "site_domain" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "root_domain" {
  zone_id = aws_route53_zone.hosted_zone.zone_id
  name    = var.domain_name # Replace with your domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.frontend.domain_name
    zone_id                = aws_cloudfront_distribution.frontend.hosted_zone_id
    evaluate_target_health = false
  }
}
