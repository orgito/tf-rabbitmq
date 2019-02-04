resource "aws_launch_configuration" "rabbitmq" {
  name_prefix          = "${lower("${var.namespace}${var.stage}_rabbitmq-")}"
  image_id             = "${data.aws_ami.selected.id}"
  instance_type        = "${var.instance_type}"
  security_groups      = ["${aws_security_group.rabbitmq.id}"]
  key_name             = "${var.ssh_key_pair}"
  user_data            = "${data.template_cloudinit_config.provision.rendered}"
  iam_instance_profile = "${aws_iam_instance_profile.profile.id}"

  root_block_device {
    volume_size           = "${var.storage_size}"
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "rabbitmq" {
  name                      = "${aws_launch_configuration.rabbitmq.name}"
  min_size                  = "${var.instance_count}"
  max_size                  = "${var.instance_count}"
  desired_capacity          = "${var.instance_count}"
  launch_configuration      = "${aws_launch_configuration.rabbitmq.name}"
  vpc_zone_identifier       = ["${var.subnets}"]
  load_balancers            = ["${aws_elb.rabbitmq.name}"]
  force_delete              = true
  wait_for_capacity_timeout = "20m"

  tag {
    key                 = "Name"
    value               = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = "${var.stage}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Provision"
    value               = "terraform"
    propagate_at_launch = true
  }
}

resource "aws_elb" "rabbitmq" {
  name = "${lower("${var.namespace}${var.stage}-rabbitmq")}"

  listener {
    instance_port     = 5672
    instance_protocol = "tcp"
    lb_port           = 5672
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 15672
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    interval            = 30
    unhealthy_threshold = 10
    healthy_threshold   = 2
    timeout             = 3
    target              = "TCP:5672"
  }

  subnets         = ["${var.subnets}"]
  idle_timeout    = 3600
  internal        = true
  security_groups = ["${aws_security_group.rabbitmq_lb.id}"]

  tags {
    Name        = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}

resource "aws_security_group" "rabbitmq" {
  name        = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
  description = "Allow inbound traffic to RabbitMQ"
  vpc_id      = "${var.vpc}"

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MQTT clients"
    from_port   = 1883
    to_port     = 1883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MQTT clients with TLS"
    from_port   = 8883
    to_port     = 8883
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "epmd"
    from_port   = 4369
    to_port     = 4369
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "AMQP"
    from_port   = 5671
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP API"
    from_port   = 15672
    to_port     = 15672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "STOMP/MQTT over WebSockets"
    from_port   = 15674
    to_port     = 15675
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Erlang distribution server"
    from_port   = 25672
    to_port     = 25672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Erlang distribution client"
    from_port   = 35672
    to_port     = 35682
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "STOMP clients"
    from_port   = 61613
    to_port     = 61614
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}

resource "aws_security_group" "rabbitmq_lb" {
  name        = "${lower("${var.namespace}${var.stage}_rabbitmq_lb")}"
  vpc_id      = "${var.vpc}"
  description = "Security Group for the rabbitmq elb"

  ingress {
    description = "AMQP"
    from_port   = 5671
    to_port     = 5672
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags {
    Name        = "${lower("${var.namespace}${var.stage}_rabbitmq_lb")}"
    Environment = "${var.stage}"
    Provision   = "terraform"
  }
}

data "aws_iam_policy_document" "rabbitmq" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rabbitmq" {
  name               = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
  assume_role_policy = "${data.aws_iam_policy_document.rabbitmq.json}"
}

resource "aws_iam_role_policy" "policy" {
  name = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
  role = "${aws_iam_role.rabbitmq.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "autoscaling:DescribeAutoScalingInstances",
                "ec2:DescribeInstances"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_instance_profile" "profile" {
  name_prefix = "${lower("${var.namespace}${var.stage}_rabbitmq")}"
  role        = "${aws_iam_role.rabbitmq.name}"
}
