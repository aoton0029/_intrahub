# Caddy TLS/Cloudflare

Cloudflare DNS-01で公開CA証明書を取得し、80/TCP・443/TCP/UDPでHTTPSを提供します。

`.env`の`ACME_EMAIL`と`CLOUDFLARE_API_TOKEN`を設定します。tokenは対象zoneだけの`Zone / DNS / Edit`と`Zone / Zone / Read`へ限定してください。

```sh
cp .env.example .env
$EDITOR .env
docker compose config --quiet
docker compose build --pull
docker compose run --rm caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d
```

Cloudflare公開DNSへLAN用A/AAAAを作る必要はありません。LANの名前解決はPi-hole等で行います。公開CA証明書を使うため、一般的なPC・タブレットへの独自CA設定は不要です。
