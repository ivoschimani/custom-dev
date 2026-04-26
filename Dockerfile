FROM alpine:3.23

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

RUN apk --no-cache --update add tzdata php83 php83-fpm php83-pdo_mysql php83-mysqli php83-json php83-iconv php83-openssl \
    php83-curl php83-ctype php83-zlib php83-xml php83-phar php83-intl php83-session php83-simplexml php83-soap \
    php83-fileinfo php83-dom php83-tokenizer php83-pdo php83-xmlreader php83-xmlwriter php83-mbstring php83-gd \
    php83-pecl-imagick php83-pecl-mongodb php83-zip php83-bcmath php83-gmp php83-ftp php83-pecl-ssh2 php83-sodium libwebp-dev libzip-dev \
    libjpeg-turbo-dev supervisor curl git openssh-client mysql-client imagemagick-dev libtool imagemagick \
    ghostscript && ln -s /usr/bin/php83 /usr/bin/php

RUN rm -rf /etc/localtime \
    && ln -s /usr/share/zoneinfo/"Europe/Berlin" /etc/localtime \
    && echo "Europe/Berlin" > /etc/timezone

RUN rm -rf /var/cache/apk/*

RUN set -ex \
  && php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
  && php composer-setup.php --2.9 --install-dir=/usr/local/bin --filename=composer \
  && php -r "unlink('composer-setup.php');" \
  && chmod +x /usr/local/bin/composer

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY config/php.ini /etc/php83/conf.d/zzz_custom.ini

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