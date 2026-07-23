# landline-forum

A maintained hard fork of **FluxBB 1.5.9**, running the "landline" forum.
FluxBB upstream is effectively unmaintained (last core commit 2019), so this
repo carries the small set of local patches needed to keep the forum secure
and running on modern PHP (7.4, with 8.x compatibility notes).

## What this repo contains

- `src/` — the FluxBB application code (PHP). Secrets are **never** read from
  files in `src/`; `config.php` is generated at container startup from Docker
  secrets mounted at `/run/secrets/...`.
- `Dockerfile`, `docker-compose.yml`, `scripts/` — container build & runtime.
- `.gitignore` — deliberately excludes `secrets/`, `tokens/`, `backups/`,
  `*.log`, the Cloudflare/Caddy infra files, `config.php` and `install.php`.

## Local patches vs upstream 1.5.9

### (a) Reverse-proxy-aware client IP — `src/include/common.php`
Defines `FORUM_BEHIND_REVERSE_PROXY` so `get_remote_address()`
(`include/functions.php`) trusts `X-Forwarded-For`. Required because the forum
is published through a Cloudflare quick tunnel / Caddy, which would otherwise
make every poster/registration IP show up as the proxy address — breaking IP
bans and logs.

### (b) BBCode XSS hardening — `src/include/parser.php`
- `handle_url_tag()`: scheme-whitelist (http/https/ftp/irc) + `htmlspecialchars`
  on the generated `href`. Neutralises `[url=javascript:...]` style payloads
  (they become a harmless `http://javascript:...` link, not an executable
  pseudo-protocol) and prevents attribute break-outs via crafted quotes.
- `handle_img_tag()`: `htmlspecialchars` on the image URL / `alt` attribute,
  preventing injection through `[img]` URLs.

## Known latent issues (PHP 8.x blockers)

These are **not** fixed here and will cause fatal errors if the container is
ever moved to PHP 8.0+:

- `create_function()` used in `include/parser.php` (6 calls) and
  `include/functions.php` (1 call). Removed in PHP 8.0 — replace with native
  anonymous functions.
- `get_magic_quotes_gpc()` / `set_magic_quotes_runtime()` in
  `include/common.php`, `install.php`, `db_update.php`. Removed in PHP 8.1.

Stay on PHP 7.4 until these are addressed.

## Building / running

```sh
docker-compose build forum
docker-compose up -d forum
```

`config.php` is created at runtime by `scripts/docker-entrypoint.sh` from the
Docker secrets `db_password` and `cookie_seed`.

## License

GPL v2 or later — same as FluxBB/PunBB upstream.
