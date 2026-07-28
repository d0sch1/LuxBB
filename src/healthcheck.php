<?php
/**
 * Lightweight health-check endpoint for Docker / orchestration.
 *
 * It boots the real FluxBB stack (common.php loads the config, connects to the
 * database, and initialises the user session) so a green response proves that
 * PHP, the generated config.php, the DB link and the app bootstrap all work.
 *
 * Unlike index.php it does NOT perform per-forum guest read-permission checks,
 * so it returns 200 regardless of whether guests are allowed to browse the
 * boards. That keeps the container "healthy" even when the forums are
 * intentionally guest-restricted (which would otherwise make curl -f / 403).
 */

define('PUN_ROOT', __DIR__.'/');

// Boot the actual application: config.php (from secret), DB connection, session.
require PUN_ROOT.'include/common.php';

// If we got here, PHP + config + DB + session init all succeeded.
http_response_code(200);
header('Content-Type: text/plain; charset=utf-8');
echo "OK\n";
exit;
