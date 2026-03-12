output "publics_alb_dns" {
  description = "Public DNS fromALB, the public door to the 3 tier architecture"
  value       = aws_lb.web_alb.dns_name
}