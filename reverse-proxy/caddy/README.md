# Caddy examples

用途ごとに完全に独立した構成です。利用するフォルダだけをホストへコピーします。

| フォルダ | 通信 | 証明書 | Cloudflare |
|---|---|---|---|
| [`http/`](./http/README.md) | HTTP | 不要 | 不要 |
| [`tls-cloudflare/`](./tls-cloudflare/README.md) | HTTPS | 公開CA | DNS-01 tokenが必要 |

どちらもLinuxの`network_mode: host`で動作し、IntraHubの`127.0.0.1:<固定ポート>`へ転送します。同時には起動しません。
