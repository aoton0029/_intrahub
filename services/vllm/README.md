# vLLM

`compose.vllm.yaml`で起動する内部OpenAI互換バックエンドです。ホストポートは持たず`llm-api`に参加し、LiteLLMの論理モデル名`vllm`から利用します。NVIDIA driver/Container Toolkit、`VLLM_MODEL`、`VLLM_API_KEY`が必要です。`VLLM_CACHE_SOURCE`でnamed volumeまたはホストパスを選べます。共有ライブラリにはアクセスしません。
