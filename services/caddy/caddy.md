← [caddy/README.md](./README.md)

# caddy

## イメージ

公式イメージに Cloudflare DNS プロバイダを組み込んで再ビルドする。標準の `caddy:2` には DNS-01 チャレンジ用のプロバイダが含まれないため、そのままでは証明書を取得できない。

| 項目 | 値 |
|---|---|
| ベースイメージ | `caddy:2`（ビルド段は `caddy:2-builder`） |
| build context | このディレクトリ |
| Dockerfile | `Dockerfile` |
| ビルドコマンド | `xcaddy build --with github.com/caddy-dns/cloudflare` |
| 成果物イメージ | `intrahub-caddy-cloudflare:2` |

`caddy:2` はメジャー2系の中で動くタグのため、`--pull` を付けた再ビルドでマイナーバージョンが上がる。上げたくない場合はビルド前に `Dockerfile` のタグを具体的なバージョンへ書き換える。

組み込みモジュールの確認:

```bash
docker compose exec caddy caddy list-modules | grep dns.providers.cloudflare
```

## 実行

| 項目 | 値 |
|---|---|
| `container_name` | `caddy`（他サービスの vhost が転送先として名前解決に使う） |
| `restart` | `unless-stopped` |
| ユーザー | 指定しない。コンテナ内で 80/443 を bind するため、イメージ既定のユーザーで動かす |

## ポート

| 内部ポート | 用途 |
|---|---|
| `80` | HTTP。HTTPS へのリダイレクトと ACME HTTP チャレンジ |
| `443` | HTTPS |
| `2019` | 管理API。ループバックのみで待ち受け、コンテナ外へは公開しない |

ホストへ公開するポートは[サービス設計書](./README.md#公開)が持つ。

## マウント

| コンテナ内パス | 種別 | 入力変数 | 権限 | 用途 | 失うと困るか |
|---|---|---|---|---|---|
| `/etc/caddy/Caddyfile` | bind | — | ro | ACME のグローバル設定と `sites/*.caddy` の読み込み | 困らない（リポジトリが正本） |
| `/etc/caddy/sites` | bind | — | ro | vhost 定義 | 困らない（リポジトリが正本） |
| `/data` | bind | `DATA_ROOT` | rw | ACMEアカウント鍵と取得済み証明書 | **困る**。失うと全FQDNの証明書を再取得することになり、CAの発行レート制限に当たる |
| `/config` | bind | `DATA_ROOT` | rw | Caddy が自動保存する実行時設定 | 困らない（起動時に再生成される） |
| `/var/log/caddy` | bind | `DATA_ROOT` | rw | アクセスログ（`sites/_snippets.caddy` の `access_log` が出力先に指定） | 監査目的で保持する場合は困る |

`/etc/caddy` 配下の2つはこのディレクトリからの相対パスでマウントするため、入力変数を取らない。

## ネットワーク

| ネットワーク | 定義 | 用途 |
|---|---|---|
| `proxy-net` | `external: true` | 転送先コンテナへの到達。Caddy はここにしか参加しない |

## 環境変数

| 変数名 | Composeでの値 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|---|
| `BASE_DOMAIN` | `${BASE_DOMAIN:?}` | ○ | | | 各 vhost の `{$BASE_DOMAIN}` を置換する。未設定だと vhost がドメイン名を持たず設定が壊れる |
| `CLOUDFLARE_API_TOKEN` | `${CLOUDFLARE_API_TOKEN:?}` | ○ | ○ | | `Caddyfile` の `acme_dns cloudflare {env.CLOUDFLARE_API_TOKEN}` が読む |

`{$VAR}` は Caddyfile の展開構文、`${VAR}` は Compose の補間構文で、別のものが二段で繋がっている。Compose が `environment:` へ実値を入れ、Caddy が起動時に自分の設定内で展開する。

## 設定ファイル

| ファイル | 内容 |
|---|---|
| `Caddyfile` | ACME の CA エンドポイントと DNS-01 プロバイダ、`import /etc/caddy/sites/*.caddy` |
| `sites/_snippets.caddy` | 各 vhost が `import` する共通スニペット。現在は JSON形式のアクセスログ定義（50MiB でローテート、5世代保持） |
| `sites/<name>.caddy` | vhost。1サイト1ファイル。追加規約は[サービス設計書](./README.md#vhost-の追加) |

`_snippets.caddy` は先頭が `_` のため、他の vhost より先に読み込まれることをファイル名順で保証している。
