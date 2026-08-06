# Samba

SMBを`${BIND_ADDRESS}:445`へ公開します。`SAMBA_USER`と`SAMBA_PASSWORD`は`.env`で設定します。HTTPリバースプロキシの対象ではありません。共有volumeはイメージ契約に合わせて`/storage`へmountし、他サービスの`/library`と同じデータを公開します。

Sambaは共有元のディレクトリ作成や所有権変更を行いません。bind mountを使用する実環境では、`${LIBRARY_SOURCE}`とその配下をホスト側で作成し、`${LIBRARY_UID}:${LIBRARY_GID}`が読み書きできる権限を設定してください。
