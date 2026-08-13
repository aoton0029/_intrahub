# Samba

SMBを`${BIND_ADDRESS}:445`へ公開します。`SAMBA_USER`と`SAMBA_PASSWORD`は`.env`で設定します。HTTPリバースプロキシの対象ではありません。`Library`共有は`/storage`へmountした`${LIBRARY_SOURCE}`で、他サービスの`/library`と同じデータです。`Knowledge`共有は`/knowledge`へmountした`${KNOWLEDGE_SOURCE}`で、AIコンテナが読み書きするナレッジ領域と同じデータです。

共有が2つあるため、環境変数インターフェースではなく`config/smb.conf`を`/etc/samba/smb.conf`へmountして設定を上書きします。イメージの環境変数`NAME`と`RW`はこの構成では使用されず、共有名と書込み可否は`smb.conf`が決めます。`USER`、`PASS`、`UID`、`GID`はアカウント作成に引き続き使用されます。

Sambaは共有元のディレクトリ作成や所有権変更を行いません。bind mountを使用する実環境では、`${LIBRARY_SOURCE}`と`${KNOWLEDGE_SOURCE}`とその配下をホスト側で作成し、`${LIBRARY_UID}:${LIBRARY_GID}`が読み書きできる権限を設定してください。
