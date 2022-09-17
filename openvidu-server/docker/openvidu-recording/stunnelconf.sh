#!/bin/sh
cd /etc/stunnel

cat > stunnel.conf <<_EOF_

cert = /stunnel/private.pem
pid = /var/run/stunnel.pid
foreground = yes

[fb-live]
client = yes
accept = 127.0.0.1:19350
connect = live-api-s.facebook.com:443
verifychain = no

_EOF_

exec stunnel "$@"
