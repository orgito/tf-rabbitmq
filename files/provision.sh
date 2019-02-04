#!/bin/bash -x

exec > >(tee "/var/log/cloud.log") 2>&1

# Exit if already executed
if [ -f ~/.terraform_provisioned ]; then exit; fi

cat > /etc/profile.d/locale.sh <<EOF
#!/bin/bash
localedef -c -f UTF-8 -i en_US en_US.UTF-8
export LC_ALL=en_US.UTF-8
EOF
chmod +x /etc/profile.d/locale.sh

echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

yum install -q -y rabbitmq-server-${rabbitmq_version}
rabbitmq-plugins --offline enable rabbitmq_peer_discovery_aws
rabbitmq-plugins --offline enable rabbitmq_management

# Setup Erlang cookie
printf ${erlang_cookie} > /var/lib/rabbitmq/.erlang.cookie
printf ${erlang_cookie} > /root/.erlang.cookie
printf ${erlang_cookie} > /home/ec2-user/.erlang.cookie
chown rabbitmq.rabbitmq /var/lib/rabbitmq/.erlang.cookie
chown ec2-user.ec2-user /home/ec2-user/.erlang.cookie
chmod 400 /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie /home/ec2-user/.erlang.cookie

# Configure
cat > /etc/rabbitmq/rabbitmq.conf << EOF
${rabbitmq_conf}
EOF
chown rabbitmq.rabbitmq /etc/rabbitmq/rabbitmq.conf

# Increse the limits
mkdir -p /etc/systemd/system/rabbitmq-server.service.d/
cat > /etc/systemd/system/rabbitmq-server.service.d/limits.conf << EOF
[Service]
LimitNOFILE=65536
EOF

systemctl enable rabbitmq-server
systemctl daemon-reload
systemctl start rabbitmq-server

sleep 5
aws configure set default.region ${region}
NODES=$(aws autoscaling describe-auto-scaling-instances | grep -c InstanceId)
QUORUM=$[$NODES/2+1]

rabbitmqctl add_user admin ${admin_password}
rabbitmqctl set_user_tags admin administrator
rabbitmqctl add_user rabbit ${rabbit_password}
rabbitmqctl set_policy ha-quorum  "^haq\." "{\"ha-mode\":\"exactly\", \"ha-params\":$${QUORUM}, \"ha-sync-mode\":\"automatic\"}"
rabbitmqctl set_policy ha-all  "^hax\." '{"ha-mode":"all", "ha-sync-mode":"automatic"}'
rabbitmqctl set_permissions admin ".*" ".*" ".*"
rabbitmqctl set_permissions rabbit ".*" ".*" ".*"
rabbitmqctl delete_user guest
rabbitmqctl set_cluster_name ${cluster_name}

echo "Node Provisioned" > ~/.terraform_provisioned
chattr +i ~/.terraform_provisioned
