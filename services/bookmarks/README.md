# Bookmarks WebDAV

`http://127.0.0.1:8082`でWebDAVを提供します。healthは`/`（未認証時の401も正常）です。通常はWebSocket不要。認証情報は`.env`の`BOOKMARKS_USER`と`BOOKMARKS_PASSWORD`から固定設定へ渡します。大きな添付を扱う場合はプロキシのbody sizeを調整します。
