#!/bin/sh
set -eu

if [ "$ENABLE_FAVA_AUTH" = "true" ]; then
  export AUTH_REALM="Restricted"
else
  export AUTH_REALM="off"
fi

envsubst '${AUTH_REALM}' \
  < /etc/nginx/nginx.conf.template \
  > /tmp/nginx.conf

# Start nginx with the rendered config
exec nginx -g 'daemon off;' -c /tmp/nginx.conf

