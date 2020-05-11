FROM alpine:3.9.6
LABEL maintainer="zan.loy@gmail.com"

RUN apk add --no-cache stunnel libressl

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
