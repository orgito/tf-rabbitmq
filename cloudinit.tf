data "template_file" "conf" {
  template = "${file("${path.module}/files/rabbitmq.conf")}"

  vars {
    region = "${var.region}"
  }
}

data "template_file" "provision" {
  template = "${file("${path.module}/files/provision.sh")}"

  vars {
    cluster_name     = "${lower("${var.namespace}${var.stage}")}"
    rabbitmq_version = "${var.rabbitmq_version}"
    admin_password   = "${random_string.admin_password.result}"
    rabbit_password  = "${random_string.rabbit_password.result}"
    erlang_cookie    = "${random_string.erlang_cookie.result}"
    rabbitmq_conf    = "${data.template_file.conf.rendered}"
    region           = "${var.region}"
  }
}

locals {
  ci_config = <<-CONFIG
    run_cmd:
      - rpm --import https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
    yum_repos:
      rabbitmq-server:
        name: bintray-rabbitmq-rpm
        baseurl: https://dl.bintray.com/rabbitmq/rpm/rabbitmq-server/v3.7.x/el/7/
        enabled: true
        gpgcheck: true
        gpgkey: https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
      rabbitmq-erlang:
        name: bintray-rabbitmq-erlang-rpm
        baseurl: https://dl.bintray.com/rabbitmq-erlang/rpm/erlang/21/el/7/
        enabled: true
        gpgcheck: true
        gpgkey: https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc
    CONFIG
}

data "template_cloudinit_config" "provision" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    content      = "${local.ci_config}"
  }

  part {
    content_type = "text/x-shellscript"
    content      = "${data.template_file.provision.rendered}"
  }
}
