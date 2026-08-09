# Hermes Agent

ホストポートを持たない内部ワーカーです。`/library`と`/workspace`へread-writeでアクセスし、専用PostgreSQL、LiteLLM、MediaVault APIを利用します。MediaVault DBへは接続できません。s6-overlayをrootで初期化した後、実行ユーザーを`HERMES_UID:HERMES_GID`へ切り替えます。共有ストレージへ書き込む場合は`LIBRARY_UID:GID`と同じ値を指定します。
