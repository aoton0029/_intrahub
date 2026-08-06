# LiteLLM

OpenAI互換APIは`http://127.0.0.1:4000/v1`、healthは`/health/liveliness`です。`anthropic`、`openai`、`vllm`を安定した論理モデル名として公開します。

`anthropic`と`openai`は外部providerへ、`vllm`は`compose.vllm.yaml`で起動する内部の`http://vllm:8000/v1`へ転送します。Mastra、Hermes、Open Deep Researchは、それぞれの`*_LLM_MODEL`へ論理モデル名を指定して切り替えます。

```dotenv
MASTRA_LLM_MODEL=vllm
HERMES_LLM_MODEL=vllm
ODR_LLM_MODEL=vllm
```

vLLMを起動しない構成でもLiteLLM自体は起動しますが、`model=vllm`へのリクエストは利用できません。vLLMとLiteLLMには同じ`VLLM_API_KEY`が渡されます。ストリーミング利用時はリバースプロキシのbufferingを無効化し、長いtimeoutを設定します。共有ライブラリはmountしません。
