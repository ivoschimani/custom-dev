FROM php:8.3-fpm-alpine3.23

LABEL org.opencontainers.image.authors="ivo@schimani.de"

ARG LOCAL_USER_ID=1000
ARG LOCAL_GROUP_ID=1000

COPY --from=mlocati/php-extension-installer:2 /usr/bin/install-php-extensions /usr/local/bin/

RUN apk update \
  && apk upgrade

# Recreate user (the php base image ships www-data with uid 82)
RUN deluser www-data 2>/dev/null; \
    addgroup -S -g 82 www-data 2>/dev/null; \
    mkdir -p /var/www && \
    adduser -D --home /var/www -u $LOCAL_USER_ID -g $LOCAL_GROUP_ID -s /bin/sh www-data -G www-data && \
    chown -R www-data:www-data /var/www

RUN mkdir -p /run/nginx

# Install nginx
# Create cachedir and fix permissions
RUN apk --no-cache --update add \
    nginx && \
    mkdir -p /var/cache/nginx && \
    mkdir -p /var/tmp/php && \
    mkdir -p /var/tmp/nginx && \
    chown -R www-data:www-data /var/cache/nginx && \
    chown -R www-data:www-data /var/lib/nginx && \
    chown -R www-data:www-data /var/tmp/nginx && \
    chown -R www-data:www-data /var/tmp/php

RUN install-php-extensions pdo_mysql mysqli intl soap gd imagick mongodb zip bcmath gmp ftp ssh2

RUN apk --no-cache --update add tzdata supervisor curl git openssh-client mysql-client imagemagick ghostscript

RUN rm -rf /etc/localtime \
    && ln -s /usr/share/zoneinfo/"Europe/Berlin" /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone

RUN rm -rf /var/cache/apk/*

RUN set -ex \
  && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php --2.9 --install-dir=/usr/local/bin --filename=composer \
  && php -r "unlink('composer-setup.php');" \
  && chmod +x /usr/local/bin/composer

# Configure PHP-FPM (replace the base image pool files, zz-docker.conf would override listen)
RUN rm -f /usr/local/etc/php-fpm.d/*.conf
COPY config/fpm-pool.conf /usr/local/etc/php-fpm.d/www.conf
COPY config/php.ini /usr/local/etc/php/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy Entrypoint
COPY start.sh /
RUN chmod +x /start.sh

RUN chown -R www-data:www-data /var/www

WORKDIR /var/www

# Expose the port nginx is reachable on
EXPOSE 8080

ENTRYPOINT ["/start.sh"]
