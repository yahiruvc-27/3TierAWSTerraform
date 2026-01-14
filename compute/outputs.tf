# Public DNS of ALB, the public door to the 3 tier architecture
output "publics_alb_dns" {
  value = aws_lb.web_alb.dns_name
}