#!/bin/sh
docker build -t cloudflare-ddns .
docker run -d --name cron-cloudflare-ddns cloudflare-ddns
#docker logs -f cron-cloudflare-ddns