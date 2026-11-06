#!/bin/bash
# Corrige o conflito de porta no VPS: o container Docker do controlcheck-api volta
# sozinho na porta 3000 a cada reboot, então o PATO passa a rodar na 3100 e o nginx
# encaminha só /api/share e /api/vistoria/ para ele.
# Uso (no PowerShell do Windows, uma linha):
#   ssh root@80.190.78.56 "curl -fsSL https://raw.githubusercontent.com/wagnerxm/pato-desempenho/main/server/corrigir-porta.sh | bash"

echo "=== 1. Atualizando o servidor do PATO ==="
mkdir -p /opt/pato-api && cd /opt/pato-api
cp server.js server.js.bak 2>/dev/null
curl -fsSL https://raw.githubusercontent.com/wagnerxm/pato-desempenho/main/server/server.js -o server.js.novo && mv server.js.novo server.js
sed -i "s/^const PORT *= *3000;/const PORT = Number(process.env.PORT) || 3100;/" server.js
grep -n "const PORT" server.js

echo "=== 2. Serviço do PATO na porta 3100 ==="
cat > /etc/systemd/system/pato-api.service <<'EOF'
[Unit]
Description=PATO Desempenho API
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/pato-api
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=5
Environment=PORT=3100

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable pato-api
systemctl restart pato-api
sleep 3
echo -n "Teste local: "; curl -s http://localhost:3100/api/health; echo

echo "=== 3. Nginx: rotas do PATO para a porta 3100 ==="
NGX=$(grep -l "controlcheck.duckdns.org" /etc/nginx/sites-enabled/* | head -1)
echo "Arquivo: $NGX"
if [ -z "$NGX" ]; then
  echo "ATENCAO: nao achei a config do controlcheck.duckdns.org no nginx — me mande esta saida"
  exit 1
fi
BKP=/root/nginx-backup-$(date +%s).conf
cp "$NGX" "$BKP"
if grep -q "PATO Desempenho API" "$NGX"; then
  echo "Rotas do PATO já existem no nginx"
elif grep -q "# Admin Panel" "$NGX"; then
  # ^~ garante prioridade sobre qualquer location regex que pegue /api
  sed -i --follow-symlinks 's|# Admin Panel|# PATO Desempenho API (porta 3100)\n    location ^~ /api/share { proxy_pass http://127.0.0.1:3100; proxy_set_header Host $host; }\n    location ^~ /api/vistoria/ { proxy_pass http://127.0.0.1:3100; proxy_set_header Host $host; }\n\n    # Admin Panel|' "$NGX"
  echo "Rotas adicionadas"
else
  echo "ATENCAO: nao achei '# Admin Panel' no arquivo — me mande esta saida"
fi
if nginx -t; then
  systemctl reload nginx
  echo "Nginx recarregado"
else
  cp "$BKP" "$NGX"; echo "ERRO no nginx — config original restaurada"
fi

echo "=== 4. Teste final pela internet ==="
curl -s -X POST https://controlcheck.duckdns.org/api/share -H 'Content-Type: application/json' -d '{"contrato":{"id":"teste","numero":"000"}}'
echo
