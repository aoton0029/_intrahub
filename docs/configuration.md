# 環境変数と秘密情報

ステータス: 次期実装の設定一覧。現存するComposeファイルは、まだこの一覧に準拠していない場合がある。

## 1. 配置規則

すべてを`.env`へ入れない。値の性質に応じて配置を分ける。

| 種類 | 配置 | Git管理 |
|---|---|---|
| 非秘密のデプロイ設定 | `.env` | しない。`.env.example`だけ管理 |
| APIキー、token、password | `runtime/secrets/<service>/` | しない |
| アプリ設定 | `runtime/config/<service>/` | しない。templateだけ管理 |
| 固定の内部URL | `services/<service>/compose.yaml` | する |

## 2. `.env`の標準変数

### 共通

| 変数 | 必須 | 既定値 | 用途 |
|---|---:|---|---|
| `TZ` | いいえ | `UTC` | コンテナのタイムゾーン |
| `BIND_ADDRESS` | いいえ | `127.0.0.1` | 全HTTPサービスをbindするホストアドレス |

`BIND_ADDRESS`をLANアドレスまたは`0.0.0.0`へ変更すると、認証を持たないサービスもLANへ到達可能になる。変更時はリバースプロキシ、VPN、またはファイアウォールによる保護を前提とする。

### ホストポート

| 変数 | 必須 | 既定値 | サービス |
|---|---:|---:|---|
| `MEDIAVAULT_PORT` | いいえ | `8080` | MediaVault Web |
| `BOOKMARKS_PORT` | いいえ | `8082` | Bookmarks WebDAV |
| `CALIBRE_PORT` | いいえ | `8083` | Calibre-Web |
| `JELLYFIN_PORT` | いいえ | `8096` | Jellyfin |
| `LITELLM_PORT` | いいえ | `4000` | LiteLLM |
| `MASTRA_PORT` | いいえ | `4111` | Mastra |
| `SAMBA_PORT` | いいえ | `445` | Samba |
| `ODR_PORT` | Researchのみ | `8000` | Open Deep Research |

DB、Redis、MediaVault API、vLLM、Hermesはホストポートを持たない。

### 共有ライブラリ

| 変数 | 必須 | 既定値 | 用途 |
|---|---:|---|---|
| `LIBRARY_UID` | いいえ | `1000` | 共有ライブラリへ書き込むUID |
| `LIBRARY_GID` | いいえ | `1000` | 共有ライブラリへ書き込むGID |
| `LIBRARY_UMASK` | いいえ | `0002` | SambaとAI間のグループ書き込み許可 |

Samba、MediaVault、Mastra、Hermes、ODRで同じ値を使う。イメージに応じて`user:`、`PUID`／`PGID`、またはアプリ固有設定へ変換する。

## 3. LiteLLM

### 非秘密設定

| 変数 | 必須条件 | 例 | 用途 |
|---|---|---|---|
| `ANTHROPIC_MODEL` | Anthropic使用時 | `anthropic/<model-id>` | `anthropic`論理モデルの実体 |
| `OPENAI_MODEL` | OpenAI使用時 | `openai/<model-id>` | `openai`論理モデルの実体 |
| `MASTRA_LLM_MODEL` | Mastra使用時 | `anthropic` | Mastraの通常利用モデル |
| `HERMES_LLM_MODEL` | Hermes使用時 | `openai` | Hermesの通常利用モデル |
| `ODR_LLM_MODEL` | Research使用時 | `anthropic` | ODRの通常利用モデル |

クライアントが指定する値は、原則として`anthropic`または`openai`というLiteLLMの論理モデル名である。

### 秘密情報からLiteLLMへ注入する環境変数

| 実行時環境変数 | secret file | 用途 |
|---|---|---|
| `ANTHROPIC_API_KEY` | `runtime/secrets/litellm/anthropic-api-key` | Anthropic API認証 |
| `OPENAI_API_KEY` | `runtime/secrets/litellm/openai-api-key` | OpenAI API認証 |
| `LITELLM_MASTER_KEY` | `runtime/secrets/litellm/master-key` | LiteLLM自体のクライアント認証 |

`OPENAPI_API_KEY`は使用しない。正しい名前は`OPENAI_API_KEY`である。

provider keyがない場合、そのproviderを`runtime/config/litellm/config.yaml`の`model_list`へ含めない。両方あれば両方を公開し、クライアントの`model`指定で切り替える。

## 4. ストレージ拡張

`compose.storage.yaml`を選択した場合だけ必要になる。

| 変数 | 必須 | 例 | 用途 |
|---|---:|---|---|
| `DATA_ROOT` | はい | `/srv/intrahub` | DBとアプリ状態の配置ルート |
| `LIBRARY_ROOT` | はい | `/mnt/library` | 共有ライブラリの実体 |
| `MODEL_CACHE_ROOT` | GPU storage使用時 | `/mnt/nvme/vllm` | vLLMモデルキャッシュ |

標準のnamed volume構成では、これらを設定しない。

## 5. GPU拡張

`compose.gpu.yaml`を選択した場合だけ使う。

### 非秘密設定

| 変数 | 必須 | 既定値 | 用途 |
|---|---:|---|---|
| `VLLM_MODEL` | はい | なし | Hugging Face等のモデルID |
| `VLLM_SERVED_MODEL_NAME` | いいえ | `local` | LiteLLMから参照するモデル名 |

性能調整値は多数の環境変数にせず、`services/vllm/compose.yaml`のcommandまたは専用設定ファイルで管理する。

### 秘密情報

| 実行時環境変数 | secret file | 必須条件 |
|---|---|---|
| `HF_TOKEN` | `runtime/secrets/vllm/hf-token` | gated model使用時 |
| `VLLM_API_KEY` | `runtime/secrets/vllm/api-key` | LiteLLMからvLLMを認証する場合 |

## 6. MediaVault

### DBと内部認証

| 実行時環境変数 | secret file／設定元 | 用途 |
|---|---|---|
| `POSTGRES_USER` | 実行時設定。既定`mediavault` | MediaVault DBユーザー |
| `POSTGRES_DB` | 実行時設定。既定`mediavault` | MediaVault DB名 |
| `POSTGRES_PASSWORD` | `runtime/secrets/mediavault/postgres-password` | MediaVault DB password |
| `INTERNAL_API_KEY` | `runtime/secrets/mediavault/internal-api-key` | MediaVault内部API認証 |

これらの一般名はMediaVaultのコンテナ内だけで使う。Compose interpolation用のグローバル変数にはせず、他のPostgreSQLと衝突させない。

### 外部メタデータ連携

使う連携だけをMediaVault APIへ注入する。

| 実行時環境変数 | secret file／設定元 | 必須 |
|---|---|---:|
| `TMDB_API_KEY` | `runtime/secrets/mediavault/tmdb-api-key` | いいえ |
| `STEAM_API_KEY` | `runtime/secrets/mediavault/steam-api-key` | いいえ |
| `STEAM_USER_ID` | `runtime/config/mediavault/providers.env` | いいえ |
| `IGDB_CLIENT_ID` | `runtime/config/mediavault/providers.env` | いいえ |
| `IGDB_CLIENT_SECRET` | `runtime/secrets/mediavault/igdb-client-secret` | いいえ |
| `ANNICT_ACCESS_TOKEN` | `runtime/secrets/mediavault/annict-access-token` | いいえ |
| `RAKUTEN_APPLICATION_ID` | `runtime/config/mediavault/providers.env` | いいえ |
| `RAKUTEN_ACCESS_KEY` | `runtime/secrets/mediavault/rakuten-access-key` | いいえ |

未設定providerは起動時に無効化し、MediaVault全体の起動を失敗させない。

## 7. AIクライアント共通

Mastra、Hermes、ODRへ注入する内部接続値。

| 環境変数 | 値／secret | 用途 |
|---|---|---|
| `LITELLM_BASE_URL` | `http://litellm:4000/v1` | 内部LiteLLM URL |
| `LITELLM_API_KEY` | LiteLLM client key | LiteLLM認証 |
| `MEDIAVAULT_API_BASE_URL` | `http://mediavault-api:8080` | 内部MediaVault API URL |
| `MEDIAVAULT_API_TOKEN` | クライアント別token | MediaVault API認証 |

URLは実環境値ではなくCompose内の固定値であり、利用者の`.env`には置かない。`LITELLM_API_KEY`と`MEDIAVAULT_API_TOKEN`はクライアントごとに別のsecret fileを割り当てる。

## 8. Hermes

| 実行時環境変数 | secret file | 必須 |
|---|---|---:|
| `HERMES_PG_PASSWORD` | `runtime/secrets/hermes/postgres-password` | はい |
| `TELEGRAM_BOT_TOKEN` | `runtime/secrets/hermes/telegram-bot-token` | いいえ |

HermesのDB URLはCompose内で組み立て、利用者の`.env`には置かない。

## 9. Research拡張

`compose.research.yaml`を選択した場合だけ使う。

| 実行時環境変数 | secret file／設定元 | 必須 |
|---|---|---:|
| `ODR_PG_PASSWORD` | `runtime/secrets/research/postgres-password` | はい |
| `TAVILY_API_KEY` | `runtime/secrets/research/tavily-api-key` | 使用時のみ |
| `LANGSMITH_API_KEY` | `runtime/secrets/research/langsmith-api-key` | いいえ |
| `ODR_LLM_MODEL` | `.env` | はい |

ODRイメージのタグは環境変数にせず、`compose.research.yaml`へ固定する。

## 10. SambaとBookmarks

| 実行時環境変数 | secret file | 用途 |
|---|---|---|
| `SAMBA_USER` | `runtime/secrets/samba/user` | SMBユーザー名 |
| `SAMBA_PASSWORD` | `runtime/secrets/samba/password` | SMB password |
| `BOOKMARKS_USER` | `runtime/secrets/bookmarks/user` | WebDAVユーザー名 |
| `BOOKMARKS_PASSWORD` | `runtime/secrets/bookmarks/password` | WebDAV password |

イメージが設定ファイルを要求する場合、bootstrapがsecretを基に`runtime/config/<service>/`の設定を生成する。同じ資格情報を`.env`と設定ファイルの両方へ手入力させない。

## 11. 設定してはならない変数

次は本設計では使用しない。

| 変数 | 理由 |
|---|---|
| `BASE_DOMAIN` | DNSとリバースプロキシはIntraHubの責務外 |
| `CADDY_*` | Caddyを実行構成へ含めない |
| `CLOUDFLARE_API_TOKEN` | TLS/DNS管理を含めない |
| `OPENAPI_API_KEY` | 誤記。`OPENAI_API_KEY`を使う |
| `LITELLM_IMAGE_TAG` | image tagはComposeへ固定する |
| `ODR_IMAGE_TAG` | image tagはComposeへ固定する |
| `COMPOSE_FILE` | 利用者の任意設定であり動作要件にしない |

## 12. 検証規則

`scripts/validate.sh`は選択されたComposeファイルに応じて次を確認する。

1. 標準構成だけならstorage、GPU、Research固有変数を要求しない。
2. secret fileが必要な場合、存在、非空、所有者、permissionを確認する。
3. 選択したLiteLLM論理モデルとprovider keyが対応していることを確認する。
4. 使っていないproviderのキーを要求しない。
5. 内部URLを利用者が上書きしていないことを確認する。
6. `.env`にAPI key、password、tokenらしい値が含まれていたら警告する。
