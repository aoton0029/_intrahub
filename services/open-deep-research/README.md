# Open Deep Research

Research拡張時だけ`http://127.0.0.1:8000`へ公開し、healthは`/health`です。長時間処理に合わせたproxy timeoutと、ストリーミング時のbuffering無効化を推奨します。専用PostgreSQL/Redis、LiteLLM、MediaVault APIを使い、`/library`と`/workspace`へread-writeでアクセスします。
