variable "project_name" {
  description = "Prefix for resource naming"
  type        = string
}

variable "web_key_pair_name" {
  description = "Key pair names to Associate with instances"
  type        = string
}

variable "web_instance_size" {
  description = "web EC2 Instace family and size"
  type        = string
}

variable "app_instance_size" {
  description = "app EC2 Instace family and size"
  type        = string
}

variable "app_key_pair_name" {

  description = "Prefix for resource naming"
  type        = string
}

variable "instance_size" {
  description = "EC2 instance size"
  type        = string
}
