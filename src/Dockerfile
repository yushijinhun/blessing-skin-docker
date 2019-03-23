FROM ubuntu:bionic as builder
RUN export DEBIAN_FRONTEND=noninteractive \
 && apt-get update -y \
 && apt-get install -y software-properties-common curl zip unzip \
 && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
 && add-apt-repository "deb https://dl.yarnpkg.com/debian/ stable main" \
 &&            COMPOSER_VERSION_UBUNTU=1.6.3-1 \
 &&                YARN_VERSION_UBUNTU=1.15.2-1 \
 &&                 PHP_VERSION_UBUNTU=7.2.15-0ubuntu0.18.04.1 \
 && apt-get install -y        composer=$COMPOSER_VERSION_UBUNTU \
                                  yarn=$YARN_VERSION_UBUNTU \
                                php7.2=$PHP_VERSION_UBUNTU \
                          php7.2-mysql=$PHP_VERSION_UBUNTU \
                        php7.2-sqlite3=$PHP_VERSION_UBUNTU \
                             php7.2-gd=$PHP_VERSION_UBUNTU \
                       php7.2-mbstring=$PHP_VERSION_UBUNTU
COPY src /blessing-skin-server-src
COPY revision /
RUN mkdir -p /root/.ssh \
 && echo "Host *\n StrictHostKeyChecking no" >> /root/.ssh/config \
 && cd /blessing-skin-server-src \
 && RELEASE_TAG=`cat /revision` ./scripts/release.sh
RUN unzip /blessing-skin-server-src/blessing-skin-server-*.zip -d /blessing-skin-server \
 && find /blessing-skin-server -name .gitignore -delete \
 && rm /blessing-skin-server/public/.htaccess /blessing-skin-server/public/web.config


FROM alpine:3.9.2
RUN    NGINX_VERSION_ALPINE=1.14.2-r0 \
 &&      PHP_VERSION_ALPINE=7.2.14-r0 \
 &&     BASH_VERSION_ALPINE=4.4.19-r1 \
 && apk add --no-cache \
                       bash=$BASH_VERSION_ALPINE \
                      nginx=$NGINX_VERSION_ALPINE \
                   php7-fpm=$PHP_VERSION_ALPINE \
              php7-calendar=$PHP_VERSION_ALPINE \
                 php7-ctype=$PHP_VERSION_ALPINE \
                  php7-curl=$PHP_VERSION_ALPINE \
                   php7-dom=$PHP_VERSION_ALPINE \
                  php7-exif=$PHP_VERSION_ALPINE \
              php7-fileinfo=$PHP_VERSION_ALPINE \
                   php7-ftp=$PHP_VERSION_ALPINE \
                    php7-gd=$PHP_VERSION_ALPINE \
               php7-gettext=$PHP_VERSION_ALPINE \
                 php7-iconv=$PHP_VERSION_ALPINE \
                  php7-json=$PHP_VERSION_ALPINE \
              php7-mbstring=$PHP_VERSION_ALPINE \
                php7-mysqli=$PHP_VERSION_ALPINE \
               php7-mysqlnd=$PHP_VERSION_ALPINE \
               php7-openssl=$PHP_VERSION_ALPINE \
                 php7-pcntl=$PHP_VERSION_ALPINE \
                   php7-pdo=$PHP_VERSION_ALPINE \
             php7-pdo_mysql=$PHP_VERSION_ALPINE \
            php7-pdo_sqlite=$PHP_VERSION_ALPINE \
                  php7-phar=$PHP_VERSION_ALPINE \
                 php7-posix=$PHP_VERSION_ALPINE \
               php7-session=$PHP_VERSION_ALPINE \
                 php7-shmop=$PHP_VERSION_ALPINE \
             php7-simplexml=$PHP_VERSION_ALPINE \
               php7-sockets=$PHP_VERSION_ALPINE \
                php7-sodium=$PHP_VERSION_ALPINE \
               php7-sqlite3=$PHP_VERSION_ALPINE \
               php7-sysvmsg=$PHP_VERSION_ALPINE \
               php7-sysvsem=$PHP_VERSION_ALPINE \
               php7-sysvshm=$PHP_VERSION_ALPINE \
             php7-tokenizer=$PHP_VERSION_ALPINE \
                  php7-wddx=$PHP_VERSION_ALPINE \
                   php7-xml=$PHP_VERSION_ALPINE \
             php7-xmlreader=$PHP_VERSION_ALPINE \
             php7-xmlwriter=$PHP_VERSION_ALPINE \
                   php7-xsl=$PHP_VERSION_ALPINE \
               php7-opcache=$PHP_VERSION_ALPINE \
                   php7-zip=$PHP_VERSION_ALPINE
COPY --from=builder /blessing-skin-server /var/www/blessing-skin-server
COPY entrypoint.sh /opt/blessing-skin-server/entrypoint.sh
COPY cfg/php-fpm.conf /etc/php7/php-fpm.conf
COPY cfg/php-fpm-extra.conf /etc/php7/php-fpm.d/extra.conf
COPY cfg/nginx-bs.conf /etc/nginx/conf.d/blessing-skin-server.conf
RUN rm /etc/php7/php-fpm.d/www.conf \
 && mkdir -p /var/run/nginx \
 && rm /etc/nginx/conf.d/default.conf \
 && echo 'daemon off;' >> /etc/nginx/nginx.conf \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && adduser -D -g www www \
 && sed -i 's/^\s*expose_php\s*=.*$/expose_php = off/g' /etc/php7/php.ini \
 && < /var/www/blessing-skin-server/.env \
        sed 's/^\s*DB_CONNECTION\s*=.*$/DB_CONNECTION = sqlite/g' | \
        sed 's/^\s*DB_DATABASE\s*=.*$/DB_DATABASE = \/var\/lib\/blessing-skin-server\/data\/database.db/g' \
    > /var/www/blessing-skin-server/.env.docker \
 && rm /var/www/blessing-skin-server/.env \
 && chmod 755 /var/www/blessing-skin-server -R \
 && chmod -x+X /var/www/blessing-skin-server -R \
 && chown www:www /var/www/blessing-skin-server -R
VOLUME [ "/var/lib/blessing-skin-server" ]
EXPOSE 80/tcp
WORKDIR "/var/www/blessing-skin-server"
ENTRYPOINT [ "/opt/blessing-skin-server/entrypoint.sh" ]

