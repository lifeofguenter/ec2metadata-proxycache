FROM nginxinc/nginx-unprivileged:1.18-alpine

USER root

RUN set -ex && \
    apk add --no-progress --no-cache \
      bash \
      shadow && \
    usermod -u 65321 nginx

USER nginx

COPY nginx.conf /etc/nginx/nginx.conf
