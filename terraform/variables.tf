variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "key_name" {
  description = "Existing EC2 key pair name, used for your own SSH access"
  type        = string
}

variable "my_ip_cidr" {
  description = "Your public IP in CIDR form, e.g. 1.2.3.4/32 (curl ifconfig.me)"
  type        = string
}

variable "controller_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "agent_instance_type" {
  type    = string
  default = "t3.small"
}

variable "agent_count" {
  type    = number
  default = 1
}
