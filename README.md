# IntraHub

メディア管理とAIサービスを1台のLinuxホストで動かすDocker Compose構成です。設定はルートの`.env`へ集約し、DNS・TLS・Caddy等のリバースプロキシは利用者側で管理します。

## 起動

```sh
cp .env.example .env
$EDITOR .env
docker compose config --quiet
docker compose up -d
```

`.env`の空欄になっているpassword、token、API key、`<model-id>`を実値へ変更してください。秘密値は必要に応じて`openssl rand -hex 32`などで生成します。`.env`はGit管理外とし、Linuxでは`chmod 600 .env`を設定します。

## 拡張

```sh
# vLLM
docker compose -f compose.yaml -f compose.vllm.yaml up -d

# Research
docker compose -f compose.yaml -f compose.research.yaml up -d

# vLLM＋Research
docker compose -f compose.yaml -f compose.vllm.yaml -f compose.research.yaml up -d
```

すべての永続データは`.env`の`*_SOURCE`で保存先を選択します。テンプレートの既定値はnamed volume、`/mnt/library`のような絶対パスはbind mountです。bind mountを使う場合は、起動前にホスト側ディレクトリと書込み権限を用意します。

公開ポートはMediaVault `8080`、Bookmarks `8082`、Calibre-Web `8083`、Jellyfin `8096`、LiteLLM `4000`、Mastra `4111`、Netdata `19999`、Samba `445`です。Research有効時だけODR `8000`を追加します。DB、Redis、MediaVault API、Hermes、vLLMはホストへ公開しません。

サービス別の補足は`services/<name>/README.md`を参照してください。実環境固有のパス、DNS、リバースプロキシ、バックアップ手順はデプロイ先のリポジトリで管理します。

Caddyを前段へ置く場合は、HTTP基本構成とTLS/Cloudflare拡張を分けた[reverse-proxy/caddy](./reverse-proxy/caddy/README.md)を利用できます。CaddyはIntraHub本体のComposeには含まれません。
