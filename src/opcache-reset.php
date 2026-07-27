<?php
/**
 * LAN-only OPcache reset helper for Landline forum deploys.
 *
 * After `docker cp` of a changed PHP file into /var/www/html, OPcache
 * (validate_timestamps=Off) keeps serving the old in-RAM bytecode. Hitting
 * this endpoint flushes OPcache so the freshly copied file takes effect —
 * WITHOUT restarting Apache (which would drop live sessions).
 *
 * Protected: only reachable from localhost or RFC1918 private address space
 * (LAN / Docker bridge). Public internet callers are rejected.
 * Deploy script calls: curl -s http://192.168.178.129:8081/opcache-reset.php
 */
if (PHP_SAPI === 'cli') {
    fwrite(STDERR, "This endpoint must be called over HTTP, not CLI.\n");
    exit(1);
}

/**
 * True if $ip is loopback or an RFC1918 private address (not publicly routable).
 * Accepts IPv4 only; IPv6 non-loopback is rejected by default.
 */
function is_private_or_loopback($ip)
{
    if ($ip === '127.0.0.1' || $ip === '::1')
        return true;

    if (filter_var($ip, FILTER_VALIDATE_IP, FILTER_FLAG_IPV4) === false)
        return false;

    // RFC1918 + carrier-grade NAT (100.64/10) + loopback (already covered)
    $privateRanges = array(
        '10.0.0.0/8',
        '172.16.0.0/12',
        '192.168.0.0/16',
        '100.64.0.0/10',
    );
    foreach ($privateRanges as $range) {
        if (ip_in_range($ip, $range))
            return true;
    }
    return false;
}

/**
 * Minimal CIDR match (IPv4), avoids extra deps.
 */
function ip_in_range($ip, $range)
{
    list($subnet, $bits) = explode('/', $range);
    $ipLong    = ip2long($ip);
    $subLong   = ip2long($subnet);
    if ($ipLong === false || $subLong === false)
        return false;
    $mask = ~((1 << (32 - (int)$bits)) - 1) & 0xFFFFFFFF;
    return ($ipLong & $mask) === ($subLong & $mask);
}

$client = $_SERVER['REMOTE_ADDR'] ?? '';
if (!is_private_or_loopback($client)) {
    header('HTTP/1.1 403 Forbidden');
    header('Content-Type: text/plain');
    echo "Forbidden\n";
    exit;
}

if (!function_exists('opcache_reset')) {
    header('Content-Type: text/plain');
    echo "opcache not enabled / opcache_reset unavailable\n";
    exit;
}

$ok = opcache_reset();
header('Content-Type: text/plain');
echo $ok ? "opcache reset OK\n" : "opcache_reset() returned false\n";
