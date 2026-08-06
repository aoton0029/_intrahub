# MediaVault

Webは`http://127.0.0.1:8080`、内部APIは`http://mediavault-api:8080`です。Webのhealthは`/`、APIは`/api/health`。WebSocketはアプリが使用する場合に転送し、upload上限とtimeoutは扱うメディアサイズに合わせます。DBは`media-db` internal networkだけに置き、AIコンテナはDBへ直接接続せず内部APIを参照します。
