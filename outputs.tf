output "synapse_alb_dns" {
  description = "DNS name for Synapse ALB"
  value       = aws_lb.synapse_alb.dns_name
}

output "element_alb_dns" {
  description = "DNS name for Element ALB"
  value       = aws_lb.element_alb.dns_name
}

output "coturn_nlb_tcp_dns" {
  description = "DNS name for coTURN NLB (TCP)"
  value       = aws_lb.coturn_nlb_tcp.dns_name
}

output "coturn_nlb_udp_dns" {
  description = "DNS name for coTURN NLB (UDP)"
  value       = aws_lb.coturn_nlb_udp.dns_name
}

output "efs_id" {
  description = "EFS ID for storing certificates"
  value       = module.efs.efs_id
}
