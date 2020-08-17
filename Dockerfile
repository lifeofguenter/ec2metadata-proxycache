FROM alpine:3.12

ENV NGINX_VERSION   1.18.0

EXPOSE 8080

STOPSIGNAL SIGTERM

ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]

COPY cache-put.patch /tmp

RUN set -x \
# create nginx user/group first, to be consistent throughout docker variants
    && addgroup -g 65321 -S nginx \
    && adduser -S -D -H -u 65321 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apk add --no-cache \
      bash \
      curl \
      ca-certificates \
      musl \
      pcre \
      tzdata \
      zlib \

# build
    && apk add --no-cache --virtual .build-deps \
        gcc \
        musl-dev \
        make \
        patch \
        pcre-dev \
        zlib-dev \
    && cd /tmp \
    && wget "http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" \
    && tar xf "nginx-${NGINX_VERSION}.tar.gz" \
    && cd "nginx-${NGINX_VERSION}" \
    && patch -p0 < ../cache-put.patch \
    && ./configure \
        --prefix=/usr/share/nginx \
        --sbin-path=/usr/sbin/nginx \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --lock-path=/tmp/nginx.lock \
        --pid-path=/tmp/nginx.pid \
        --http-client-body-temp-path=/var/cache/nginx/client \
        --http-proxy-temp-path=/var/cache/nginx/proxy \
        --without-select_module \
        --without-poll_module \
        --with-pcre-jit \
        --with-threads \
        --without-http_ssi_module \
        --without-http_auth_basic_module \
        --without-http_mirror_module \
        --without-http_autoindex_module \
        --without-http_geo_module \
        --without-http_referer_module \
        --without-http_grpc_module \
        --without-http_limit_conn_module \
        --without-http_limit_req_module \
        --without-http_empty_gif_module \
        --without-http_browser_module \
        --without-stream_limit_conn_module \
        --without-stream_access_module \
        --without-stream_geo_module \
        --without-stream_map_module \
        --without-stream_split_clients_module \
        --without-stream_return_module \
        --without-http_memcached_module \
        --without-http_fastcgi_module \
        --without-http_uwsgi_module \
        --without-http_geo_module \
        --without-http_scgi_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        > /dev/null \
    && make -s \
    && make install \
    && apk del .build-deps \
    && rm -rf "/tmp/nginx-${NGINX_VERSION}"* \

# Bring in gettext so we can get `envsubst`, then throw
# the rest away. To do this, we need to install `gettext`
# then move `envsubst` out of the way so `gettext` can
# be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \

# forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

# implement changes required to run NGINX as an unprivileged user
COPY nginx.conf /etc/nginx/nginx.conf

RUN set -ex \
    && mkdir -p /var/cache/nginx /cache \
    && chown -R 65321:0 /var/cache/nginx /cache \
    && chmod -R g+w /var/cache/nginx /cache \
    && chown -R 65321:0 /etc/nginx \
    && chmod -R g+w /etc/nginx

USER nginx
