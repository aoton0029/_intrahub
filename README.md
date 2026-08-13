# IntraHub

メディア管理とAIサービスを1台のLinuxホストで動かすDocker Compose構成です。設定はルートの`.env`へ集約し、DNS・TLS・Caddy等のリバースプロキシは利用者側で管理します。

## 構成図

```mermaid
flowchart LR
  client([利用者 / LAN クライアント])
  proxy[/"Caddy（任意・別Compose）"/]

  subgraph host["Linux ホスト（Docker Compose: intrahub）"]
    subgraph pub["公開ポート"]
      web["mediavault-web :8080"]
      book["bookmarks (WebDAV) :8082"]
      orbit["bookorbit-app :3000"]
      jelly["jellyfin :8096"]
      lite["litellm :4000"]
      mastra["mastra :4111"]
      net["netdata :19999"]
      smb["samba :445"]
      mcp["mediavault-mcp :8081"]
      odr["open-deep-research :8000<br/>(compose.research.yaml)"]
    end

    subgraph internal["非公開サービス"]
      api["mediavault-api"]
      hermes["hermes-agent"]
      vllm["vllm<br/>(compose.vllm.yaml / GPU)"]
      mvdb[("mediavault-postgres")]
      obdb[("bookorbit-postgres")]
      hedb[("hermes-postgres")]
      odrdb[("odr-postgres")]
      odrredis[("odr-redis")]
    end

    lib[("LIBRARY_SOURCE<br/>共有ライブラリ")]
    ws[("AI_WORKSPACE_SOURCE")]
    kn[("KNOWLEDGE_SOURCE")]
  end

  ext([外部 LLM API / メタデータ API])

  client --> proxy --> pub
  client --> pub

  web --> api
  api --> mvdb
  mcp --> api
  orbit --> obdb
  hermes --> hedb
  odr --> odrdb
  odr --> odrredis

  mastra --> lite
  hermes --> lite
  odr --> lite
  mastra --> api
  hermes --> api
  odr --> api
  lite --> vllm
  lite --> ext
  api --> ext

  jelly -. ro .-> lib
  smb --> lib
  orbit -. ro .-> lib
  api --> lib
  mastra --> lib
  hermes --> lib
  odr --> lib
  mastra --> kn
  hermes --> ws
  odr --> ws
  smb --> kn
```

DB・Redisは`internal: true`のネットワークに閉じ、`litellm`／`mediavault-api`へは`llm-api`／`mediavault-api`ネットワーク経由でのみ到達します。公開ポートの待受アドレスは`.env`の`BIND_ADDRESS`（既定`127.0.0.1`）で決まり、`mediavault-mcp`のみ`MCP_BIND_ADDRESS`（既定`0.0.0.0`）です。

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

公開ポートはMediaVault `8080`、MediaVault MCP `8081`、Bookmarks `8082`、BookOrbit `3000`、Jellyfin `8096`、LiteLLM `4000`、Mastra `4111`、Netdata `19999`、Samba `445`です。Research有効時だけODR `8000`を追加します。DB、Redis、MediaVault API、Hermes、vLLMはホストへ公開しません。

サービス別の補足は`services/<name>/README.md`を参照してください。実環境固有のパス、DNS、リバースプロキシ、バックアップ手順はデプロイ先のリポジトリで管理します。

Caddyを前段へ置く場合は、HTTP基本構成とTLS/Cloudflare拡張を分けた[reverse-proxy/caddy](./reverse-proxy/caddy/README.md)を利用できます。CaddyはIntraHub本体のComposeには含まれません。
