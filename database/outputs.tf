output "database_dns" {
  value = aws_route53_record.aurora_pg_dns.fqdn
}

output "database_sg_id" {
  value = aws_security_group.rds_sg.id
}
