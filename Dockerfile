FROM alpine
MAINTAINER Huey Lee <leejinhuey@gmail.com>
  
RUN set -xe && \
  apk update && apk upgrade && \
  apk add --no-cache \
  busybox nginx s6 ca-certificates \
  php7 php7-cli php7-fpm php7-curl php7-dom php7-gd php7-iconv php7-fileinfo php7-json \
  php7-mcrypt php7-pgsql php7-pcntl php7-pdo php7-pdo_pgsql \
  php7-mysqli php7-pdo_mysql \
  php7-mbstring php7-posix php7-session php7-intl git \
  postgresql-contrib && \
  apk add --no-cache --virtual=build-deps curl wget tar
    
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

# complete path to ttrss
ENV SELF_URL_PATH http://localhost

# expose default database credentials via ENV in order to ease overwriting
ENV DB_NAME ttrss
ENV DB_USER ttrss
ENV DB_PASS ttrss

# always re-configure database with current ENV when RUNning container, then monitor all services
WORKDIR /var/www
ADD configure-db.php /configure-db.php
ADD s6/ /etc/s6/
RUN chmod -R +x /etc/s6/
CMD php /configure-db.php && exec s6-svscan /etc/s6/
