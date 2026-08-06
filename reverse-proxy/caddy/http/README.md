# Caddy HTTP

証明書を取得せず、80/TCPでHTTPだけを提供します。

```sh
cp .env.example .env
$EDITOR .env
docker compose config --quiet
docker compose run --rm caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d
```

LAN DNSが`*.CADDY_DOMAIN`をCaddyホストへ解決する必要があります。password、cookie、API key、本文は暗号化されないため、信頼できるLANだけで使用してください。
