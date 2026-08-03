← [intrahub/README.md](../../README.md)

# Caddy

IntraHub の HTTP/HTTPS サービスの唯一の入口。`proxy-net` 上のコンテナへ名前で転送し、公開CAの証明書を DNS-01 チャレンジで取得・更新する。Samba などの非HTTPサービスは経由しない。

各アプリはホストへポートを公開せず、Caddy だけがホストのポートを持つ。

## コンテナ構成

| コンテナ | 設計書 | 役割 |
|---|---|---|
| `caddy` | [caddy.md](./caddy.md) | リバースプロキシ、TLS終端、ACMEクライアント |

## 公開

ホストへ公開するポートは HTTP・HTTPS の2つだけで、`CADDY_HTTP_PORT` / `CADDY_HTTPS_PORT` で受ける。実際に割り当てるポート番号は配置側が決める。

FQDN は `<サブドメイン>.${BASE_DOMAIN}` の形で組み立てる。`${BASE_DOMAIN}` に実在ドメインを与えることが前提で、Caddy はそのゾーンに対して Let's Encrypt から証明書を取得する。

| サブドメイン | vhost ファイル | 転送先 |
|---|---|---|
| `beszel` | `sites/beszel.caddy` | `beszel:8090` |
| `bookmarks` | `sites/bookmarks.caddy` | `bookmarks:80` |
| `calibre` | `sites/calibre.caddy` | `calibre-web:8083` |
| `jellyfin` | `sites/jellyfin.caddy` | `jellyfin:8096` |
| `litellm` | `sites/litellm.caddy` | `litellm:4000` |
| `mastra` | `sites/mastra.caddy` | `mastra:4111` |
| `mediavault` | `sites/mediavault.caddy` | `/api/*` は `mediavault-api:8080`、それ以外は `mediavault-web:80` |
| `mcp.mediavault` | `sites/mcp-mediavault.caddy` | `mediavault-mcp:8081` |
| `research` | `sites/research.caddy` | `open-deep-research:8000` |

転送先のコンテナ名と内部ポートは IntraHub 内の固定値で、環境によって変わらない。この表と各サービスの `compose.yaml` がずれると 502 になる。

TLS は Caddy で終端し、`proxy-net` 上の転送は平文HTTPで行う。認証は各サービスが自前で持ち、Caddy では行わない。

## ネットワーク

| ネットワーク | 役割 |
|---|---|
| `proxy-net` | Caddy と、Caddy から到達させる全HTTPサービスが参加する共有ネットワーク。`external: true` |

`proxy-net` は複数の `compose.yaml` をまたいで参照されるため、起動前に一度だけ外部で作成する（[起動](../../README.md#起動)）。

## 入力変数

| 変数名 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|
| `BASE_DOMAIN` | ○ | | | 全FQDNのベースドメイン。`Caddyfile` と各 vhost が `{$BASE_DOMAIN}` で参照する |
| `CLOUDFLARE_API_TOKEN` | ○ | ○ | | ACME DNS-01 用。対象ゾーンの `Zone:Read` と `DNS:Edit` だけを許可する |
| `DATA_ROOT` | ○ | | | 証明書・状態・アクセスログを置くホスト側ルート |
| `CADDY_HTTP_PORT` | | | `80` | ホストへ公開するHTTPポート |
| `CADDY_HTTPS_PORT` | | | `443` | ホストへ公開するHTTPSポート |

実値は `.env` に置く。ひな形は [.env.example](../../.env.example) の `# ---- caddy ----` 節。

## 前提

- `${BASE_DOMAIN}` のゾーンが Cloudflare を権威DNSとしていること。証明書は DNS-01 で取得するため、ホストが外部から到達可能である必要はない。
- LAN内のDNSが `*.${BASE_DOMAIN}` を IntraHub サーバーのアドレスへ返すこと。公開DNSにLAN内のA/AAAAレコードは置かず、ACME検証用のTXTレコードだけが一時的に作られる。
- 発行したサブドメイン名は Certificate Transparency ログで検索できる。ドメイン名は公開情報、APIトークンは秘密情報として扱う。

## vhost の追加

1. `sites/<name>.caddy` を1サイト1ファイルで作る。ドメインは `{$BASE_DOMAIN}` を使い、実ドメインを直書きしない。
2. アクセスログを取るサイトは `import access_log` を書く（定義は `sites/_snippets.caddy`）。
3. 転送先は対象サービスの `compose.yaml` のコンテナ名と内部ポートに一致させる。
4. 対象サービスが `proxy-net` に参加していることを確認する。
5. 上記「公開」の表に1行足す。
6. validate してから reload する（下記「更新」）。

## 初回構築

```bash
# 1. 共有ネットワークを作る（未作成のときだけ）
docker network create proxy-net

# 2. 永続化ディレクトリを用意する
mkdir -p "${DATA_ROOT}"/db/caddy/{data,config} "${DATA_ROOT}"/log/caddy

# 3. Cloudflare DNS モジュールを組み込んだイメージをビルドする
docker compose build --pull caddy

# 4. 設定を検証してから起動する
docker compose run --rm --no-deps caddy \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose up -d caddy
```

## 更新

vhost を変更したとき（再起動しない）:

```bash
docker compose run --rm --no-deps caddy \
  caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker compose exec caddy \
  caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Caddy 本体または Cloudflare モジュールを更新したとき:

```bash
docker compose build --pull --no-cache caddy
docker compose up -d --force-recreate caddy
docker compose exec caddy caddy list-modules | grep dns.providers.cloudflare
```

## 確認

| 確認項目 | コマンド | 合格条件 |
|---|---|---|
| 設定の構文 | `docker compose run --rm --no-deps caddy caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile` | `Valid configuration` が出る |
| DNSモジュール | `docker compose exec caddy caddy list-modules \| grep dns.providers.cloudflare` | 1行出力される |
| 証明書の取得 | `docker compose logs caddy \| grep -i "certificate obtained"` | vhost ごとに1行出る |
| 転送 | `curl -sI https://<サブドメイン>.${BASE_DOMAIN}` | `HTTP/2 200`（認証があるサービスは `401`/`302`）。`502` なら転送先が未到達 |
| ポート占有 | `ss -tlnp \| grep -E ":(${CADDY_HTTP_PORT}\|${CADDY_HTTPS_PORT}) "` | `caddy` 以外のプロセスが出ない |

## トラブルシューティング

| 症状 | 確認先 |
|---|---|
| `ERR_NAME_NOT_RESOLVED` | クライアントのDNSがLAN内DNSを向いているか、`*.${BASE_DOMAIN}` のローカルレコード |
| 接続拒否・タイムアウト | Caddyの起動状態、ホストのファイアウォール、HTTP/HTTPSポートの競合 |
| `ERR_SSL_PROTOCOL_ERROR` | Cloudflareトークンの権限、ACMEログ、DNSモジュールの組み込み |
| 特定サイトだけ502 | 転送先のコンテナ名・内部ポート・`proxy-net` への参加 |

```bash
docker compose ps caddy
docker compose logs --tail=200 caddy
docker network inspect proxy-net
docker compose exec caddy wget -S -O- http://<転送先コンテナ>:<内部ポート>/
```

転送先だけ失敗する場合は、対象コンテナが起動済みで `proxy-net` に参加していることを確認する。ホストのポートを別プロセスが使っている場合は、そのプロセスを止めてから Caddy を再起動する。
