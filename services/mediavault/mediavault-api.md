← [mediavault/README.md](./README.md)

# mediavault-api

Rust / Axum 製の中核API。PostgreSQL を正本とし、Web UI・mcp・Jellyfin を含む**すべてのデータ変更をここが受け付ける**。他のコンテナから DB へ直接接続させない。

## イメージ

| 項目 | 値 |
|---|---|
| イメージ | `ghcr.io/aoton0029/intrahub-mediavault-api:0.1.0` |
| ソース | `intrahub-mediavault` リポジトリの `backend/` |
| Dockerfile | `backend/Dockerfile`（`rust:1-slim` でビルドし `debian:bookworm-slim` へ成果物のみコピー） |
| 発行 | アプリリポジトリの CI が `v*` タグで GHCR へ push する |

タグは SemVer をリテラルで固定する。本リポジトリでは `build:` を持たない。

## 実行

| 項目 | 値 |
|---|---|
| `container_name` | `mediavault-api`（`mediavault-web` の nginx と Caddy が名前で引く） |
| `restart` | `unless-stopped` |

アプリが満たすこと:

- **非rootで動くこと。** Dockerfile の `USER` で降格する
- SIGTERM を受けたら処理中のリクエストを完了させてから終了すること
- ログは標準出力へ出し、コンテナ内のファイルへ書かないこと
- 設定は環境変数だけから読み、コンテナ内へ設定を書き戻さないこと

## ポート

| 内部ポート | 用途 |
|---|---|
| `8080` | HTTP API |

`0.0.0.0:8080` で待ち受けること。ループバックにだけバインドすると `proxy-net` 上の Caddy から到達できない。ホストへの公開有無は[サービス設計書](./README.md#公開)が持つ。

## マウント

| コンテナ内パス | 種別 | 入力変数 | 権限 | 用途 | 失うと困るか |
|---|---|---|---|---|---|
| `/srv/mediavault` | bind | `MEDIAVAULT_ROOT` | rw | アップロードファイルの保存先。配下の構成はアプリが作る | **困る**。DBの `item_files` が実体を失う |

メディア領域（動画・マンガの原本）は**マウントしない**。既存ファイルは絶対パスを `item_files` へ登録してリンクするだけで、コピーも移動もしない。

## ネットワーク

| ネットワーク | 定義 | 用途 |
|---|---|---|
| `db-net` | サービス内部 | `mediavault-postgres` への接続 |
| `proxy-net` | `external: true` | Caddy からの到達。`backend` エイリアスを持つ |

## 依存

`mediavault-postgres` が `service_healthy` になるまで起動しない。起動時にマイグレーションを適用するため、DB が接続を受け付けている必要がある。

## healthcheck

`GET /api/health` を liveness として使う。DB を含む依存の状態は見ず、プロセスが応答することだけを判定する。

エンドポイントを `/api/` 配下に置くのは、Caddy が `mediavault.<ドメイン>` の `/api/*` だけを api へ振り分けているため。ルート直下に置くと `mediavault-web` へ流れてしまう。readiness を liveness と分けるかは決めていない（[既知の未整備](../../README.md#既知の未整備)）。

## 環境変数

| 変数名 | Composeでの値 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|---|
| `DATABASE_URL` | `postgresql://${POSTGRES_USER:?}:${POSTGRES_PASSWORD:?}@mediavault-postgres:5432/${POSTGRES_DB:?}` | ○ | ○ | | DB接続文字列。ホスト部は固定値 |
| `STORAGE_ROOT` | `/srv/mediavault` | ○ | | | アップロードの保存ルート（コンテナ内パス） |
| `INTERNAL_API_KEY` | `${INTERNAL_API_KEY:?}` | ○ | ○ | | `/internal/*` の Bearer 認証キー |
| `CORS_ALLOWED_ORIGIN` | `${CORS_ALLOWED_ORIGIN:?}` | ○ | | | 許可オリジン |
| `TMDB_API_KEY` | `${TMDB_API_KEY:-}` | | ○ | 空 | 外部メタデータ取得 |
| `STEAM_API_KEY` / `STEAM_USER_ID` | `${...:-}` | | 鍵のみ○ | 空 | 同上 |
| `IGDB_CLIENT_ID` / `IGDB_CLIENT_SECRET` | `${...:-}` | | 秘密のみ○ | 空 | 同上 |
| `ANNICT_ACCESS_TOKEN` | `${ANNICT_ACCESS_TOKEN:-}` | | ○ | 空 | 同上 |
| `RAKUTEN_APPLICATION_ID` / `RAKUTEN_ACCESS_KEY` | `${...:-}` | | 鍵のみ○ | 空 | 同上 |

アプリが満たすこと:

- `INTERNAL_API_KEY` が**空または未設定なら起動を中止すること。** 空文字を許すと `/internal/*` が無認証で開く。compose 側でも `${VAR:?}` で二重に止めている
- `CORS_ALLOWED_ORIGIN` は単一オリジンのみ受け付け、不正な値なら起動時に落ちること
- 外部メタデータAPIの資格情報は任意。未設定のプロバイダは起動時の seed をスキップし、起動そのものは成功すること

## 境界

| 対象 | 境界 |
|---|---|
| DB接続 | web・mcp・Jellyfin から DB へ直接接続させない。すべて api を経由する |
| メディア領域 | マウントしない。パス参照のみで扱う |
| 検索範囲 | 自身のアイテムのみ。サービス横断の生成・検索は KnowledgeHub 側の責務 |
| ホストポート | 公開しない |
