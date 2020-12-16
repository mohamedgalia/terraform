variable "image_id" {
  type        = string
  description = "The id of the machine image (AMI) to use for the server."
  default = "ami-0502e817a62226e03"
}

variable "availability_zone_names" {
  type    = list(string)
  default = ["eu-central-1", "eu-central-1a", "eu-central-1b"]
}

variable "access_key_var" {
  type        = string
  default = ""
}

variable "secret_key_var" {
  type        = string
  default = ""
}

variable "vpc_ip" {
  type        = string
  default = "10.30.0.0/16"
}

variable "subnets_names" {
  type    = list(string)
  default = ["10.30.1.0/24", "10.30.10.0/24"]
}

variable "privte_ip" {
  type    = list(string)
  default = ["10.30.1.50"]
}
