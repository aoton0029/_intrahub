← [mastra/README.md](./README.md)

# mastra

ワークフローの実行と Mastra Studio の配信を担う。推論は LiteLLM 経由で呼ぶ。

## イメージ

| 項目 | 値 |
|---|---|
| イメージ | `ghcr.io/aoton0029/intrahub-mastra:0.1.0` |
| ソース | `intrahub-mastra` リポジトリのルート |
| ベースイメージ | `node:22-slim`（`package.json` の `engines` が Node 22.13 以上を要求する） |
| 発行 | アプリリポジトリの CI が `v*` タグで GHCR へ push する |

ビルドが満たすこと:

- `mastra build` が `.mastra/output/` に自己完結したサーバーバンドル（`index.mjs` + `package.json` + `node_modules`）を出す。**`.mastra` は `.gitignore` 対象なのでイメージ内でビルドする**
- multi-stage にし、runtime 段へは `.mastra/output` だけを渡す。ソースと devDependencies をイメージに残さない
- `.dockerignore` で `node_modules` / `.mastra` / `.env*` / `.git` を除外する。ホスト側の `node_modules` を持ち込むと、ネイティブモジュール（DuckDB）がプラットフォーム不一致で壊れる

## 実行

| 項目 | 値 |
|---|---|
| `container_name` | `mastra`（Caddy が vhost の転送先として名前で引く） |
| `restart` | `unless-stopped` |
| ユーザー | Dockerfile の `USER node` で非rootへ降格する |

アプリが満たすこと:

- SIGTERM を受けたら実行中のワークフローを打ち切ってから終了すること
- ログは標準出力へ出すこと（`PinoLogger` の既定どおり）

## ポート

| 内部ポート | 用途 |
|---|---|
| `4111` | Mastra Studio と API |

`0.0.0.0:4111` で待ち受けること。ホストへは公開せず、Caddy 経由でのみ到達させる（[サービス設計書](./README.md#公開)）。

## マウント

| コンテナ内パス | 種別 | 入力変数 | 権限 | 用途 | 失うと困るか |
|---|---|---|---|---|---|
| `/app/data` | bind | `DATA_ROOT` | rw | LibSQL のデータベースファイルとオブザーバビリティの記録 | **困る**。ワークフローの実行履歴とエージェントのメモリが失われる |

`/app` は成果物の展開先で、イメージに含まれるため永続化しない。Dockerfile で `/app/data` を作り実行ユーザーの所有にしておくこと。

## ネットワーク

| ネットワーク | 定義 | 用途 |
|---|---|---|
| `llm-net` | `external: true` | LiteLLM の呼び出し |
| `proxy-net` | `external: true` | Caddy からの到達 |

## 環境変数

| 変数名 | Composeでの値 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|---|
| `LITELLM_BASE_URL` | `http://litellm:4000/v1` | ○ | | `http://litellm:4000/v1` | LiteLLM の OpenAI互換エンドポイント。アプリ側にも同じ既定値がある |
| `LITELLM_MASTER_KEY` | `${LITELLM_MASTER_KEY:?}` | ○ | ○ | | LiteLLM の認証キー |
| `TURSO_DATABASE_URL` | `file:/app/data/mastra.db` | ○ | | `file:./mastra.db` | LibSQL の保存先。既定は作業ディレクトリ直下でイメージ内に閉じてしまうため、永続ボリューム配下を明示する |

アプリが満たすこと:

- `LITELLM_MASTER_KEY` が未設定なら、実行時に認証エラーを出すのではなく**起動時に落ちること**。現在の実装は未設定時に `missing-litellm-master-key` という文字列を送っており、失敗が LLM 呼び出しまで遅延する
- モデルは論理名で参照すること。現在は `wiki-model` を使う。実体のモデルとフォールバックは LiteLLM の `config.yaml` が持つので、アプリ側に具体的なモデル名を書かない

`TURSO_` という接頭辞は Mastra のテンプレート由来で、ホスト型 Turso を使う場合の変数名がそのまま残っている。IntraHub ではローカルのファイルを指すのに使う。
