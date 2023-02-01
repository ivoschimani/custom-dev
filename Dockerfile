FROM alpine:3.17

LABEL org.opencontainers.image.authors="ivo@schimani.de"

ARG LOCAL_USER_ID=1000
ARG LOCAL_GROUP_ID=1000

RUN apk update \
  && apk upgrade

# Create user
RUN mkdir -p /var/www && \
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

RUN apk --no-cache --update add tzdata php81 php81-fpm php81-pdo_mysql php81-json php81-iconv php81-openssl \
    php81-curl php81-ctype php81-zlib php81-xml php81-phar php81-intl php81-session php81-simplexml php81-soap \
    php81-fileinfo php81-dom php81-tokenizer php81-pdo php81-xmlreader php81-xmlwriter php81-mbstring php81-gd \
    php81-pecl-imagick php81-zip php81-bcmath php81-gmp php81-ftp php81-pecl-ssh2 libwebp-dev libzip-dev \
    libjpeg-turbo-dev supervisor curl git openssh-client mysql-client imagemagick-dev libtool imagemagick \
    ghostscript

RUN rm -rf /etc/localtime \
    && ln -s /usr/share/zoneinfo/"Europe/Berlin" /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone

RUN rm -rf /var/cache/apk/*

RUN set -ex \
  && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php --2.2 --install-dir=/usr/local/bin --filename=composer \
  && php -r "unlink('composer-setup.php');" \
  && chmod +x /usr/local/bin/composer

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php81/php-fpm.d/www.conf
COPY config/php.ini /etc/php81/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy Entrypoint
COPY start.sh /

RUN chown -R www-data:www-data /var/www

WORKDIR /var/www

# Expose the port nginx is reachable on
EXPOSE 8080

ENTRYPOINT ["/start.sh"]