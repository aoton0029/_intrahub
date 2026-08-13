# Mastra

`http://127.0.0.1:4111`、healthは`/`です。WebSocketを転送してください。`/library`と`/workspace`へread-writeでアクセスし、MediaVaultの内部APIとLiteLLMを参照できる構成です。`/workspace`はナレッジ領域全体（`KNOWLEDGE_SOURCE`）で、配下の`ai-workspace`に中間ファイル、`second-brain`に最終ファイルを置きます。他のAIコンテナの`/workspace`は`AI_WORKSPACE_SOURCE`だけを指すため、範囲が異なります。どちらの領域へ書けるかはMastraアプリ側のツールがパスで制限します。利用できるエージェントやワークフローはMastraアプリ側に実装されたものに限ります。

## MediaVault MCP

`mediavault-api`ネットワーク経由で`http://mediavault-mcp:8081`へ接続します。認証は`MCP_AUTH_TOKEN`によるBearerトークンで、`mediavault-mcp`と同じ値を共有します。Mastraアプリ側は`search_library`、`get_item_context`、`get_item_text`のRead Onlyツールだけを使用し、書き込み系のMCPツールをエージェントへ渡しません。

## ナレッジ領域のパス

`KNOWLEDGE_ROOT`、`AI_WORKSPACE_DIR`、`SECOND_BRAIN_DIR`はコンテナ内の絶対パスをMastraアプリへ渡します。Mastraアプリのツールはこの3つを境界として、中間ファイルの自由書き込みを`AI_WORKSPACE_DIR`配下に限定し、`SECOND_BRAIN_DIR`配下へはノート操作ツールからのみ到達させます。
