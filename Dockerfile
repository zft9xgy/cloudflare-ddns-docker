FROM alpine:latest

RUN apk add --no-cache curl

COPY ./cloudflare-ddns.sh /usr/local/bin/cloudflare-ddns.sh

RUN chmod +x /usr/local/bin/cloudflare-ddns.sh

RUN sh /usr/local/bin/cloudflare-ddns.sh
RUN echo "*/5 * * * * /usr/local/bin/cloudflare-ddns.sh" > /etc/crontabs/root

RUN touch /var/log/cloudflare-ddns.log

CMD ["crond", "-f", "-l", "2"]