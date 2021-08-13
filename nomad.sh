#!/bin/bash

CA_CERT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/ca-cert)
NOMAD_EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nomad-external-ip)
VAULT_EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/vault-external-ip)
EXTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
GOSSIP_ENCRYPTION_KEY=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/gossip-encryption-key)
NOMAD_CERT=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nomad-cert)
NOMAD_KEY=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/nomad-key)

apt-get update
apt-get install -y wget unzip

## Download Nomad
wget -O nomad_1.1.3_linux_amd64.zip \
  https://releases.hashicorp.com/nomad/1.1.3/nomad_1.1.3_linux_amd64.zip

## Install Nomad
unzip nomad_1.1.3_linux_amd64.zip

chmod +x nomad
mv nomad /usr/local/bin

rm nomad_1.1.3_linux_amd64.zip

## Configure and Start Nomad
mkdir -p /etc/nomad
mkdir -p /etc/nomad/tls
mkdir -p /var/lib/nomad

echo "${CA_CERT}" > /etc/nomad/tls/ca.pem
echo "${NOMAD_CERT}" > /etc/nomad/tls/nomad.pem
echo "${NOMAD_KEY}" > /etc/nomad/tls/nomad-key.pem

cat > /etc/nomad/client.hcl <<EOF
advertise {
  http = "${EXTERNAL_IP}:4646"
  rpc = "${EXTERNAL_IP}:4647"
}

bind_addr = "0.0.0.0"

client {
  enabled = true
  options {
    "driver.raw_exec.enable" = "1"
  }

  server_join {
    retry_join = [ "${NOMAD_EXTERNAL_IP}" ]
    retry_max = 3
    retry_interval = "15s"
  }
}

data_dir = "/var/lib/nomad"
log_level = "DEBUG"

tls {
  ca_file = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  http = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
  rpc = true
  verify_https_client = true
}

vault {
  address = "https://${VAULT_EXTERNAL_IP}:8200"
  ca_path = "/etc/nomad/tls/ca.pem"
  cert_file = "/etc/nomad/tls/nomad.pem"
  enabled = true
  key_file = "/etc/nomad/tls/nomad-key.pem"
}
EOF

cat > /etc/systemd/system/nomad.service <<'EOF'
[Unit]
Description=Nomad
Documentation=https://nomadproject.io/docs

[Service]
ExecStart=/usr/local/bin/nomad agent -config /etc/nomad/client.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nomad
systemctl start nomad
