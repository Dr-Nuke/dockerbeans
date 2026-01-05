#!/bin/sh
set -e

if [ "$ENABLE_FAVA_AUTH" = "true" ]; then
  export AUTH_REALM="Restricted"
else
  export AUTH_REALM="off"
fi

envsubst '${AUTH_REALM}' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/nginx.conf

exec nginx -g 'daemon off;'
