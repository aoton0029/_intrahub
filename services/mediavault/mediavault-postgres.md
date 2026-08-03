← [mediavault/README.md](./README.md)

# mediavault-postgres

MediaVault 専用の PostgreSQL。他サービス（Hermes-Agent、Open Deep Research）も PostgreSQL を使うが、DB を共有せずコンテナごと分ける。スキーマの所有者を1つに保ち、片方の障害や復元が他方に波及しないようにするため。

## イメージ

| 項目 | 値 |
|---|---|
| イメージ | `postgres:16` |

## 実行

| 項目 | 値 |
|---|---|
| `container_name` | `mediavault-postgres` |
| `restart` | `unless-stopped` |
| ユーザー | 指定しない。イメージが `postgres` ユーザーへ自分で降格する |

## ポート

| 内部ポート | 用途 |
|---|---|
| `5432` | PostgreSQL |

ホストへは公開しない。`db-net` 上の `mediavault-api` だけが到達する。

## マウント

| コンテナ内パス | 種別 | 入力変数 | 権限 | 用途 | 失うと困るか |
|---|---|---|---|---|---|
| `/var/lib/postgresql/data` | bind | `MEDIAVAULT_ROOT` | rw | データベースの実体 | **困る**。MediaVault のメタデータがすべて失われる |

ホスト側の配置は[サービス設計書](./README.md#ホスト配置)が持つ。

## ネットワーク

| ネットワーク | 定義 | 用途 |
|---|---|---|
| `db-net` | サービス内部 | `mediavault-api` からの接続のみ |

## healthcheck

`pg_isready -U <POSTGRES_USER> -d <POSTGRES_DB>` を readiness として使う。`mediavault-api` の `depends_on: service_healthy` はこれを判定元にしており、DB が接続を受け付ける前に api が起動してマイグレーションに失敗することを防いでいる。

## 環境変数

| 変数名 | Composeでの値 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|---|
| `POSTGRES_USER` | `${POSTGRES_USER:?}` | ○ | | | 初期化時に作るロール名 |
| `POSTGRES_PASSWORD` | `${POSTGRES_PASSWORD:?}` | ○ | ○ | | 同パスワード |
| `POSTGRES_DB` | `${POSTGRES_DB:?}` | ○ | | | 初期化時に作るデータベース名 |
| `TZ` | `${TZ:?}` | ○ | | | ログとタイムスタンプのタイムゾーン |

`POSTGRES_*` はデータディレクトリが空のときの**初期化にだけ**使われる。既に初期化済みのボリュームに対して値を変えても反映されず、`mediavault-api` の接続だけが失敗する。
