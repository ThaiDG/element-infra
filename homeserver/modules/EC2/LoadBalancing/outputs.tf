output "target_group_arn" {
  value       = aws_lb_target_group.lb_target_group.arn
  description = "ARN of the load balancer target group"
}

output "listener_arn" {
  value = aws_lb_listener.lb_listener.arn
}
