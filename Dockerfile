FROM php:7.4-apache

RUN apt-get update && apt-get install -y \
    libpng-dev libjpeg-dev libfreetype6-dev libzip-dev libicu-dev unzip libonig-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) gd mbstring intl opcache zip mysqli \
    && a2enmod rewrite headers expires \
    && rm -f /etc/apache2/conf-enabled/security.conf \
    && printf '%s\n' 'ServerTokens Prod' 'ServerSignature Off' > /etc/apache2/conf-available/zz-hardening.conf \
    && ln -s /etc/apache2/conf-available/zz-hardening.conf /etc/apache2/conf-enabled/zz-hardening.conf \
    && printf '%s\n' '<VirtualHost *:80>' \
        '    DocumentRoot /var/www/html' \
        '    Header set X-Content-Type-Options "nosniff"' \
        '    Header set X-Frame-Options "SAMEORIGIN"' \
        '    Header set X-XSS-Protection "1; mode=block"' \
        '    Header set Content-Security-Policy "default-src '\''self'\''; script-src '\''self'\'' '\''unsafe-inline'\'' '\''unsafe-eval'\''; style-src '\''self'\'' '\''unsafe-inline'\''; img-src '\''self'\'' data:; frame-src '\''self'\'' https://www.youtube.com https://www.youtube-nocookie.com; frame-ancestors '\''self'\'';"' \
        '    <Location "/install.php">' \
        '        Require all denied' \
        '    </Location>' \
        '    <Location "/cache/">' \
        '        Require all denied' \
        '    </Location>' \
        '    <Location "/files/">' \
        '        Require all denied' \
        '    </Location>' \
        '    <Directory "/var/www/html/img">' \
        '        # Upload directories: never execute PHP, regardless of .htaccess.' \
        '        <FilesMatch "\\.php$">' \
        '            Require all denied' \
        '        </FilesMatch>' \
        '        php_flag engine off' \
        '        AllowOverride None' \
        '    </Directory>' \
        '    <FilesMatch "\\.(css|js|png|jpe?g|gif|ico|svg|woff2?|ttf|eot|webp)$">' \
        '        ExpiresActive On' \
        '        ExpiresDefault "access plus 1 week"' \
        '        Header append Cache-Control "public"' \
        '    </FilesMatch>' \
        '</VirtualHost>' > /etc/apache2/sites-available/000-default.conf \
    && ln -sf /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default.conf

COPY src/ /var/www/html/
COPY scripts/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 755 {} \; \
    && find /var/www/html -type f -exec chmod 644 {} \; \
    && mkdir -p /var/www/html/cache /var/www/html/img/avatars /var/www/html/img/memes \
    && chown -R www-data:www-data /var/www/html/cache /var/www/html/img/avatars /var/www/html/img/memes \
    && chmod 770 /var/www/html/cache /var/www/html/img/avatars /var/www/html/img/memes \
    && printf '%s\n' \
        'expose_php = Off' \
        'display_errors = Off' \
        'log_errors = On' \
        'error_reporting = E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED' \
        'session.cookie_httponly = 1' \
        'session.cookie_secure = 0' \
        'opcache.enable = 1' \
        'opcache.memory_consumption = 128' \
        'opcache.interned_strings_buffer = 8' \
        'opcache.max_accelerated_files = 10000' \
        'opcache.revalidate_freq = 60' \
        'opcache.enable_file_override = 1' \
        'opcache.validate_timestamps = 0' \
        > /usr/local/etc/php/conf.d/99-hardening.ini

# config.php is generated at runtime by the entrypoint from the Docker secret,
# so a rebuild is self-healing and no DB password is baked into the image.
CMD ["/usr/local/bin/docker-entrypoint.sh"]
