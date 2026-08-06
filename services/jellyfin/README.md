# Jellyfin

`http://127.0.0.1:8096`、healthは`/health`です。リバースプロキシではWebSocketを転送し、ストリーミングを切断しない長いtimeoutを設定します。初回起動後にJellyfin自身の管理者認証を構成します。共有ライブラリは`/library`へread-onlyでmountします。
