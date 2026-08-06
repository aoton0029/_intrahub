# Hermes Agent

ホストポートを持たない内部ワーカーです。`/library`と`/workspace`へread-writeでアクセスし、専用PostgreSQL、LiteLLM、MediaVault APIを利用します。MediaVault DBへは接続できません。イメージの実行ユーザーを共有`LIBRARY_UID:GID`へ統一しています。
