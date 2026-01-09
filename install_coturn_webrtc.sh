#!/bin/bash
set -e

echo "=============================="
echo " Coturn TURN/STUN Installer"
echo " WebRTC Audio - UDP ONLY"
echo "=============================="

TURN_PORT=3478
RELAY_MIN=49152
RELAY_MAX=65535
TTL=86400

PUBLIC_IP=$(curl -s http://checkip.amazonaws.com || curl -s ifconfig.me)

if [ -z "$PUBLIC_IP" ]; then
  echo "❌ No se pudo detectar la IP pública"
  exit 1
fi

TURN_SECRET=$(openssl rand -hex 32)

echo "🌐 IP Pública detectada: $PUBLIC_IP"
echo "🔐 Generando secret seguro..."

sudo apt update -y
sudo apt install -y coturn curl openssl

sudo sed -i 's/#TURNSERVER_ENABLED=1/TURNSERVER_ENABLED=1/' /etc/default/coturn

sudo tee /etc/turnserver.conf > /dev/null <<EOF
############################################
# Coturn TURN/STUN Configuration
# WebRTC Audio - UDP Only
############################################

listening-port=${TURN_PORT}
listening-ip=0.0.0.0
relay-ip=${PUBLIC_IP}
external-ip=${PUBLIC_IP}

no-tcp
no-tls
no-dtls

lt-cred-mech
use-auth-secret
static-auth-secret=${TURN_SECRET}
realm=${PUBLIC_IP}

fingerprint
no-loopback-peers
no-multicast-peers
stale-nonce

min-port=${RELAY_MIN}
max-port=${RELAY_MAX}

total-quota=0
bps-capacity=0

log-file=/var/log/turnserver.log
simple-log
EOF

sudo chown turnserver:turnserver /etc/turnserver.conf
sudo chmod 600 /etc/turnserver.conf

sudo systemctl daemon-reexec
sudo systemctl enable coturn
sudo systemctl restart coturn

sleep 2

if systemctl is-active --quiet coturn; then
  echo "✅ Coturn está corriendo correctamente"
else
  echo "❌ Coturn NO inició correctamente"
  sudo journalctl -u coturn --no-pager | tail -n 50
  exit 1
fi

echo ""
echo "=============================="
echo " TURN SERVER READY"
echo "=============================="
echo ""
echo "TURN_HOSTNAME: ${PUBLIC_IP}"
echo "TURN_PORT: ${TURN_PORT}"
echo "TURN_SECRET: ${TURN_SECRET}"
echo "TURN_CREDENTIAL_TTL: ${TTL}"
echo ""
