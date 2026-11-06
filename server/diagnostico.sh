#!/bin/bash
# Diagnóstico do roteamento controlcheck.duckdns.org → API do PATO (somente leitura, não altera nada)
# Uso no VPS: curl -fsSL https://raw.githubusercontent.com/wagnerxm/pato-desempenho/main/server/diagnostico.sh | bash
J='{"contrato":{"id":"teste","numero":"000"}}'
echo "=== DNS ==="; getent hosts controlcheck.duckdns.org
echo "=== Quem escuta 80/443 ==="; ss -tlnp | grep -E ':(80|443)\s'
echo "=== Containers Docker ==="; docker ps --format '{{.Names}} | {{.Image}} | {{.Ports}}' 2>/dev/null
echo "=== Arquivos que o nginx carrega ==="; nginx -T 2>/dev/null | grep '^# configuration file'
echo "=== Rotas do nginx (server/listen/location/proxy) ==="
nginx -T 2>/dev/null | grep -nE 'server_name|listen |location|proxy_pass|PATO' | grep -v '^\s*#'
echo "=== Teste direto na 3100 ==="; curl -s -X POST http://127.0.0.1:3100/api/share -H 'Content-Type: application/json' -d "$J"; echo
echo "=== Teste via nginx local (443) ==="
curl -sk --resolve controlcheck.duckdns.org:443:127.0.0.1 -X POST https://controlcheck.duckdns.org/api/share -H 'Content-Type: application/json' -d "$J"; echo
echo "=== Teste pela internet ==="
curl -s -X POST https://controlcheck.duckdns.org/api/share -H 'Content-Type: application/json' -d "$J"; echo
