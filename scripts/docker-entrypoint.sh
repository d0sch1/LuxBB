#!/bin/bash
# Runtime entrypoint for the forum container.
# Generates /var/www/html/config.php from the mounted Docker secret so a
# rebuild is self-healing (no hardcoded password in the image, no manual restore).
set -euo pipefail

CONFIG=/var/www/html/config.php
SECRET="${DB_PASSWORD_FILE:-/run/secrets/db_password}"
SEED_SECRET="${COOKIE_SEED_FILE:-/run/secrets/cookie_seed}"

# Docker secrets can mount a moment after container start; wait (bounded) so
# we never boot Apache without config.php.
DB_PASS=""
for _ in $(seq 1 30); do
  if [ -f "$SECRET" ]; then
    DB_PASS="$(cat "$SECRET")"
    [ -n "$DB_PASS" ] && break
  fi
  sleep 0.5
done
if [ -z "$DB_PASS" ]; then
  DB_PASS="${DB_PASSWORD:-}"
fi

# Cookie seed: a stable, persistent secret. FluxBB uses it to HMAC the auth
# cookie, so it MUST NOT change between boots — regenerating it would log every
# user out and invalidate all sessions. Falls back to a fixed default only if
# the secret is entirely absent (shouldn't happen with compose wiring).
COOKIE_SEED=""
if [ -f "$SEED_SECRET" ]; then
  COOKIE_SEED="$(cat "$SEED_SECRET")"
fi
if [ -z "$COOKIE_SEED" ]; then
  COOKIE_SEED="${COOKIE_SEED_FALLBACK:-fluxbb-default-cookie-seed}"
fi

if [ -n "$DB_PASS" ]; then
  cat > "$CONFIG" <<EOF
<?php
define('PUN', 1);
\$db_type = 'mysqli';
\$db_host = 'forum-db';
\$db_name = 'fluxbb';
\$db_username = 'fluxbb';
\$db_password = '${DB_PASS}';
\$db_prefix = '';
\$p_connect = false;
\$cookie_name = 'pun_cookie';
\$cookie_domain = '';
\$cookie_path = '/';
\$cookie_secure = 0;
\$cookie_seed = '${COOKIE_SEED}';
?>
EOF
  chown www-data:www-data "$CONFIG"
  chmod 640 "$CONFIG"
fi

# Defense-in-depth: the img/avatars dir is a named volume (overlaid at
# runtime), so a .htaccess COPYed during build is hidden. Write it now so
# uploaded files can never be executed as PHP.
AVATAR_DIR=/var/www/html/img/avatars
mkdir -p "$AVATAR_DIR"
cat > "$AVATAR_DIR/.htaccess" <<'HTEOF'
# Never execute PHP in the avatar upload directory.
<IfModule mod_php.c>
    php_flag engine off
</IfModule>
<IfModule mod_php7.c>
    php_flag engine off
</IfModule>
RemoveHandler .php .phtml .php3 .php4 .php5 .php7 .pht
RemoveType .php .phtml .php3 .php4 .php5 .php7 .pht
php_flag engine off
AddType text/plain .php .phtml .php3 .php4 .php5 .php7 .pht
HTEOF
chown www-data:www-data "$AVATAR_DIR/.htaccess"
chmod 644 "$AVATAR_DIR/.htaccess"

# Hand off to the base image's Apache foreground process.
exec apache2-foreground "$@"
