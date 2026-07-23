#!/bin/bash
set -euo pipefail
DIR="/home/d0sch1/forum"
TOKENS_DIR="${DIR}/tokens"
mkdir -p "$TOKENS_DIR"

COUNT="${1:-10}"
if ! [[ "$COUNT" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <count>" >&2
  exit 1
fi

DB_PASS=$(cat "${DIR}/secrets/db_password.txt")
OUT="${TOKENS_DIR}/tokens-$(date +%Y%m%d-%H%M%S).txt"

for i in $(seq 1 "$COUNT"); do
  token=$(openssl rand -base64 32)
  sg docker -c "docker exec forum-db mysql -u fluxbb -p${DB_PASS} fluxbb -e \"INSERT IGNORE INTO registration_tokens (token) VALUES ('${token}');\"" >/dev/null
  printf '%s\n' "$token" >> "$OUT"
done

chmod 600 "$OUT"
ln -sf "$(basename "$OUT")" "${TOKENS_DIR}/latest.txt"
echo "Generated $COUNT tokens to ${OUT}"
