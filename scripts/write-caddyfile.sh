#!/bin/bash
set -euo pipefail
DOMAIN="${1:-}"
if [ -z "$DOMAIN" ]; then
  echo "Usage: $0 <domain>" >&2
  exit 1
fi

cat > /home/d0sch1/forum/Caddyfile <<EOF
$DOMAIN {
  encode gzip
  reverse_proxy http://forum:80
  tls internal
}
EOF

echo "Caddyfile written for $DOMAIN"
