FROM alpine:latest
MAINTAINER Huey Lee <leejinhuey@gmail.com>
  
RUN set -xe && \
  apk update && apk upgrade && \
  apk --update --no-cache add \
    ca-certificates \
    busybox \
    s6 \
    gettext \
    git \
    busybox \
    nginx \
    openssl \
    postgresql-contrib \
    php8 \
    php8-curl \
    php8-dom \
    php8-fileinfo \
    php8-fpm \
    php8-gd \
    php8-json \
    php8-iconv \
    php8-intl \
    php8-mcrypt \
    php8-mbstring \
    php8-mysqlnd \
    php8-opcache \
    php8-openssl \
    php8-pcntl \
    php8-pdo_mysql \
    php8-pdo_pgsql \
    php8-pgsql \
    php8-posix \
    php8-session \
    php8-tokenizer \
    php8-xsl \
  && ln -sv /usr/bin/php8 /usr/bin/php \
  && apk add --no-cache --virtual=build-deps curl wget tar
    
# Add user www-data for php-fpm.
# 82 is the standard uid/gid for "www-data" in Alpine.
RUN adduser -u 82 -D -S -G www-data www-data

# add ttrss as the only nginx site
ADD ttrss.nginx.conf /etc/nginx/nginx.conf

# install ttrss and patch configuration
RUN rm -rf /var/www && \
  git clone https://git.tt-rss.org/fox/tt-rss --depth=1 /var/www
WORKDIR /var/www
RUN cp config.php-dist config.php

# install themes
WORKDIR /var/www/themes.local
RUN wget https://github.com/levito/tt-rss-feedly-theme/archive/master.zip && unzip master.zip \
  && cp -r tt-rss-feedly-theme-master/feedly* . && rm -rf tt-rss-feedly-theme-master master.zip

# install plugins
WORKDIR /var/www/plugins
RUN wget https://github.com/voidstern/tt-rss-newsplus-plugin/archive/master.tar.gz \
  && mkdir -p api_newsplus \
  && tar xzvpf master.tar.gz --strip-components=2 -C api_newsplus tt-rss-newsplus-plugin-master/api_newsplus \
  && rm master.tar.gz \
  && wget https://github.com/fxneumann/oneclickpocket/archive/master.tar.gz \
  && mkdir -p oneclickpocket \
  && tar xzvpf master.tar.gz --strip-components=1 -C oneclickpocket oneclickpocket-master \
  && rm master.tar.gz \
  && wget https://github.com/DigitalDJ/tinytinyrss-fever-plugin/archive/master.tar.gz \
  && mkdir -p fever-plugin \
  && tar xzvpf master.tar.gz --strip-components=1 -C fever-plugin tinytinyrss-fever-plugin-master \
  && rm master.tar.gz \
  && wget https://github.com/Alekc/af_refspoof/archive/master.tar.gz \
  && mkdir -p af_refspoof \
  && tar xzvpf master.tar.gz --strip-components=1 -C af_refspoof af_refspoof-master \
  && rm master.tar.gz \
  && wget https://git.tt-rss.org/fox/ttrss-time-to-read/archive/master.tar.gz \
  && mkdir -p time-to-read \
  && tar xzvpf master.tar.gz --strip-components=1 -C time-to-read ttrss-time-to-read \
  && rm master.tar.gz 

# clean up
RUN set -xe \
  && apk del build-deps \
  && apk del --progress --purge \
  && rm -rf /var/cache/apk/* \
  && rm -rf /var/lib/apt/lists/* \
  && chown nobody:nginx -R /var/www

# expose only nginx HTTP port
EXPOSE 80

ENV \
    TTRSS_DB_HOST="database" \
    TTRSS_DB_NAME="ttrss" \
    TTRSS_DB_PASS="ttrss" \
    TTRSS_DB_PORT="5432" \
    TTRSS_DB_TYPE="pgsql" \
    TTRSS_DB_USER="ttrss" \
    TTRSS_SELF_URL_PATH="http://localhost:8000/"

# always re-configure database with current ENV when RUNning container, then monitor all services
WORKDIR /var/www
ADD configure-db.php /configure-db.php
ADD s6/ /etc/s6/
RUN chmod -R +x /etc/s6/
CMD php /configure-db.php && exec s6-svscan /etc/s6/
