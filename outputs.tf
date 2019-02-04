output "erlang_cookie" {
  value = "${random_string.erlang_cookie.result}"
  sensitive = true
}

output "admin_password" {
  value = "${random_string.admin_password.result}"
  sensitive = true
}

output "rabbitmq_management" {
  value = "http://${aws_elb.rabbitmq.dns_name}/"
}

output "rabbitmq_server" {
  value = "${aws_elb.rabbitmq.dns_name}:5672"
}
