# BookOrbit

`http://127.0.0.1:3000`、healthは`/api/v1/health`です。初回アクセス時は`SETUP_BOOTSTRAP_TOKEN`を使ったセットアップウィザードで管理者アカウントを作成します。共有ライブラリは`/books`へread-onlyでmountします。cbz/cbr/cb7のコミックは組み込みリーダーでそのまま閲覧できます。DBは`bookorbit-db` internal networkだけに置きます。
