FROM alpine:latest

RUN apk add --no-cache bash curl jq openssl xxd

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]