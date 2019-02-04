provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

resource "null_resource" "validate_worspace" {
  count = "${terraform.workspace == var.stage ? 0 : 1}"
  "\nERROR: You are trying to run ${var.stage} stage in the ${terraform.workspace} workspace.\nCreate/Select the correct workspace first." = true
}

data "aws_vpc" "vpc" {
  id = "${var.vpc}"
}

# Amazon Linux 2
data "aws_ami" "selected" {
  owners      = ["137112412989"] # Amazon
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.????????-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "random_string" "erlang_cookie" {
  length  = 64
  special = false
}

resource "random_string" "admin_password" {
  length  = 16
  special = false
}

resource "random_string" "rabbit_password" {
  length  = 16
  special = false
}
