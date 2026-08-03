← [intrahub/README.md](../../README.md)

# Mastra

TypeScript でエージェントとワークフローを書くための実行基盤。IntraHub では、収集したメタデータとノートから Wiki ページを生成するワークフローを載せる。

推論は自前で持たず、**すべて LiteLLM 経由で呼ぶ**。モデルの差し替えとフォールバックは LiteLLM 側の責務なので、Mastra は論理モデル名（`wiki-model`）だけを知っていればよい。

## コンテナ構成

| コンテナ | 設計書 | 役割 |
|---|---|---|
| `mastra` | [mastra.md](./mastra.md) | ワークフロー実行と Mastra Studio の配信 |

## 公開

| サブドメイン | 転送先 |
|---|---|
| `mastra` | `mastra:4111` |

vhost の実体は [Caddy](../caddy/README.md#公開)。公開するのは Mastra Studio（ワークフローの実行・トレース閲覧のUI）で、LAN内からの操作を想定している。

**Mastra Studio 自身は認証を持たない。** LAN内限定であることが前提の公開であり、外部へ露出させない。

## ネットワーク

| ネットワーク | 用途 |
|---|---|
| `llm-net` | LiteLLM の OpenAI互換API を呼ぶ |
| `proxy-net` | Caddy からの到達 |

`ai-net` には参加しない。vLLM へ直接つながず、必ず LiteLLM を通す。モデルの実体とフォールバックを LiteLLM の `config.yaml` だけで差し替えられる状態を保つため。

## データアクセス

**MediaVault の DB と Vault のファイルへ直接アクセスしない。** ボリュームも bind mount しない。読み書きは MCP サーバー（`mediavault-mcp` / `vault-mcp`）を経由させる設計とし、書き込み先の制約や frontmatter の規約は MCP サーバー側で強制する。Mastra のプロンプトに依存させない。

MCP サーバーはいずれも未実装のため、現在の `compose.yaml` は LiteLLM への接続だけを持つ。

## 入力変数

| 変数名 | 必須 | 秘密 | 用途 |
|---|---|---|---|
| `LITELLM_MASTER_KEY` | ○ | ○ | LiteLLM の認証キー。LiteLLM 側と同じ値 |
| `DATA_ROOT` | ○ | | 永続データを置くホスト側ルート |

LiteLLM のエンドポイント（`http://litellm:4000/v1`）とストレージのコンテナ内パスは IntraHub 内の固定値なので変数にしない。

## ホスト配置

```
<DATA_ROOT>/db/mastra/     # LibSQL のデータベースファイルとオブザーバビリティの記録
```

ディレクトリはコンテナの実行UIDで書き込めるようにしておく。所有者が合っていないと起動直後に LibSQL の初期化で落ちる。

## イメージの発行

ソースは `intrahub-mastra` リポジトリにある。イメージはそのリポジトリの CI が GHCR へ publish し、本リポジトリは `image:` でバージョンを固定して pull するだけとする（[自作サービスの実装](../../README.md#自作サービスの実装)）。

## 運用

| 項目 | 内容 |
|---|---|
| バックアップ対象 | `<DATA_ROOT>/db/mastra`（ワークフローの実行履歴、メモリ、トレース） |
| バックアップ対象外 | 生成した Wiki ページ。出力先は Vault であり Samba 側でバックアップする |

## 確認

| 確認項目 | コマンド | 合格条件 |
|---|---|---|
| 起動 | `docker compose ps mastra` | `Up` になり、再起動ループに入らない |
| ストレージ | `docker compose logs mastra` | LibSQL の初期化エラーが出ない |
| Studio | `curl -sI https://mastra.<ドメイン>` | `200`。`502` ならコンテナが未起動 |
| LiteLLM 疎通 | `docker compose exec mastra wget -qO- http://litellm:4000/health/liveliness` | 正常応答 |
