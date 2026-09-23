#!/bin/bash
# ============================================================
# PATO Desempenho — Setup do servidor de compartilhamento
# Rode como root no VPS: bash setup.sh SEU_DOMINIO
# Ex: bash setup.sh pato-api.duckdns.org
# ============================================================
set -e

DOMAIN="${1:?Uso: bash setup.sh SEU_DOMINIO (ex: pato-api.duckdns.org)}"
APP_DIR="/opt/pato-api"

echo "=== Instalando Node.js 20 ==="
if ! command -v node &>/dev/null; then
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi
echo "Node $(node -v)"

echo "=== Instalando Caddy (HTTPS automático) ==="
if ! command -v caddy &>/dev/null; then
  apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
  curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list
  apt-get update
  apt-get install -y caddy
fi
echo "Caddy $(caddy version)"

echo "=== Copiando servidor ==="
mkdir -p "$APP_DIR"
cp server.js "$APP_DIR/server.js"
echo '{}' > "$APP_DIR/shares.json"

echo "=== Configurando Caddy (HTTPS → Node) ==="
cat > /etc/caddy/Caddyfile <<EOF
${DOMAIN} {
    reverse_proxy localhost:3000
}
EOF

echo "=== Criando serviço systemd ==="
cat > /etc/systemd/system/pato-api.service <<EOF
[Unit]
Description=PATO Desempenho API
After=network.target

[Service]
Type=simple
WorkingDirectory=${APP_DIR}
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

echo "=== Abrindo portas 80 e 443 ==="
if command -v ufw &>/dev/null; then
  ufw allow 80/tcp
  ufw allow 443/tcp
fi

echo "=== Iniciando serviços ==="
systemctl daemon-reload
systemctl enable pato-api
systemctl restart pato-api
systemctl restart caddy

echo ""
echo "============================================"
echo " PRONTO!"
echo " API rodando em: https://${DOMAIN}"
echo " Health check:   https://${DOMAIN}/api/health"
echo "============================================"
echo ""
echo "Teste com:"
echo "  curl https://${DOMAIN}/api/health"
