#!/bin/sh

cd /etc/stunnel

cat > stunnel.conf << _EOF_
cert = /etc/stunnel/stunnel.pem
delay = yes
fips = no
foreground = yes
setuid = stunnel
setgid = stunnel

[redis]
  client = ${STUNNEL_CLIENT:-yes}
  accept = ${STUNNEL_ACCEPT:-127.0.0.1:6379}
  connect = ${STUNNEL_CONNECT}
_EOF_

if ! [ -f stunnel.pem ]
then
  openssl req -x509 -nodes -newkey rsa:2048 -days 3650 -subj '/CN=stunnel' -keyout stunnel.pem -out stunnel.pem
  chmod 600 stunnel.pem
fi

exec stunnel "$@"
