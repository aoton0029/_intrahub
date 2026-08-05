# IntraHub

IntraHub は、メディア管理・LLM・エージェント関連のコンテナ群を、1台のLinuxホストで運用するためのDocker Composeプロジェクトです。

現在は次期構成への再設計中です。実装の基準となる[構成設計](./docs/architecture.md)と[環境変数一覧](./docs/configuration.md)を参照してください。現存するComposeファイルは、まだこの設計に準拠していない場合があります。

## 設計の要点

- 標準構成はDocker named volumeとループバック公開を使い、実環境固有のパスやリバースプロキシを要求しない
- Webサービスは安定したホストポートを持ち、直接利用も任意のリバースプロキシ経由の利用もできる
- DNS・TLS・Caddyなどのリバースプロキシは利用者が管理する
- 永続データの配置は任意のCompose上書きでホストストレージへ変更できる
- ファイルを扱うAIエージェントは共有ライブラリを読み書きし、LiteLLM／vLLMにはmountしない
- Mastra・Hermes・ODRは内部ネットワークからMediaVault APIを利用し、DBへ直接接続しない
- LiteLLMはAnthropic／OpenAIを論理モデル名で公開し、AIクライアントから切り替えられる
- 設定テンプレートは`services/<name>/config/`、実値と秘密情報はgitignoreされた`runtime/`へ分離する
- GPUや外部プロバイダに依存するサービスは追加Composeファイルへ分離する
- データベースや内部APIはホストへ公開しない

## 目標の起動方法

標準構成:

```sh
cp .env.example .env
./scripts/bootstrap.sh
./scripts/validate.sh
docker compose up -d
```

ホストストレージを使う場合:

```sh
docker compose -f compose.yaml -f compose.storage.yaml up -d
```

GPU拡張を使う場合:

```sh
docker compose -f compose.yaml -f compose.gpu.yaml up -d
```

これらは目標インターフェースであり、再実装が完了するまでは利用できない場合があります。
