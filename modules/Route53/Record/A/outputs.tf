output "record_dns_name" {
  description = "The DNS name of the Route53 A record"
  value       = aws_route53_record.record_type_a_dns.fqdn
}