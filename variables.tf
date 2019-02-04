variable "aws_access_key" {}
variable "aws_secret_key" {}

variable "namespace" {
  description = "Namespace, which could be your organization name or abbreviation, e.g. 'co' or 'company'"
}

variable "stage" {
  description = "Stage, e.g. 'prod', 'staging', 'dev'"
}

variable "vpc" {
  description = "VPC ID where to deploy the instances"
}

variable "region" { }

variable "subnets" {
  description = "Subnet IDs where to deploy the instances. At least 2 subnets in distinct availability zones."
  type        = "list"
}

variable "instance_type" {
  description = "RabbitMQ instance type"
}

variable "instance_count" {
  description = "How many nodes to deploy"
  default = "3"
}

variable "ssh_key_pair" {
  description = "EC2 SSH key name to manage the instances"
}

variable "rabbitmq_version" {
  description = "RabbitMQ version. (3.7.x)"
  default = "3.7.11"
}

variable "storage_size" {
  description = "Neo4j nodes storage size (GB)"
  default     = 10
}
