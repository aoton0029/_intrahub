# Knowledge Vault 初期化

`KNOWLEDGE_SOURCE`（既定は名前付きボリューム`knowledge`、実環境では`/srv/knowledge`）に Knowledge Vault の骨格と規約ファイルを配置します。IntraHub の起動時に`knowledge-init`が一度だけ走り、`mastra`はその完了を待ってから起動します。

Vault の内容そのもの（ノート）を生成するのは Mastra 側です。ここが用意するのは、Mastra と人間が従う**器と規約**だけです。

## 動作

1. `seed/dirs.txt`のディレクトリが無ければ作る。既にあるものには触らない
2. `.knowledge-seed-version`と`seed/VERSION`を比較する
   - マーカーが無い → 初回として`seed/files`を配置する
   - seed の方が新しい → `seed/files`で上書きする
   - 同じか古い → ファイルを変更しない
3. 上書きの直前に現状を Git へコミットし、その後の変更も別コミットとして残す

冪等です。同じバージョンで何度起動しても Vault は変化しません。

`seed/files`に**無い**ファイルは削除しません。人間が`00-Inbox`へ書いたノートや Mastra が生成したノートは、初期化を再実行しても失われません。

## 上書きされるもの

`seed/files`配下にあるものだけです。

| パス | 内容 |
|---|---|
| `README.md` / `AGENTS.md` / `CLAUDE.md` | Vault の規約 |
| `.gitignore` | 中間データと`tech-notes`を履歴から除外 |
| `second-brain/.obsidian/app.json` | リンク形式を絶対パスに固定する設定 |
| `second-brain/.obsidian/templates.json` | テンプレートフォルダの指定 |
| `second-brain/90-Meta/Schema/frontmatter.schema.json` | frontmatter の機械可読スキーマ |
| `second-brain/90-Meta/Schema/taxonomy.yaml` | categories / tags の正規語彙 |
| `second-brain/90-Meta/Templates/*.md` | ノート種別ごとの雛形 |

`90-Meta`は Vault の規約上「人間の領域」ですが、seed のバージョンが上がると上書きされます。`taxonomy.yaml`に人間が追加した語彙は、バージョン更新で seed の内容に戻ります。**上書きの直前に必ずコミットを取る**のはこのためで、失われた語彙は`git show`で取り出して seed 側へ反映してください。運用で育てた語彙を seed へ戻さないままバージョンを上げると、その差分は毎回消えます。

## 手動で実行する

```sh
# 通常の初期化（バージョン比較あり）
docker compose run --rm knowledge-init

# バージョンが同じでも強制的に再配置する
KNOWLEDGE_SEED_FORCE=true docker compose run --rm knowledge-init
```

`.env`の`KNOWLEDGE_SEED_FORCE=true`でも同じ動作になりますが、起動のたびに人手編集が seed の内容へ戻るため、常用しません。

## seed を更新する

1. `seed/files`または`seed/dirs.txt`を変更する
2. `seed/VERSION`を上げる（上げないと既存の Vault へ反映されない）
3. IntraHub を再起動するか、`knowledge-init`を手動実行する

`dirs.txt`から行を消してもVault側のディレクトリは消えません。削除は手で行います。

## frontmatter スキーマの位置づけ

規約の正本は Vault の`README.md`（散文）で、`90-Meta/Schema/frontmatter.schema.json`はそれを機械可読にした従属物です。両者が食い違った場合は`README.md`を正としてスキーマを直します。

Mastra 側はこのスキーマを読み、Vault Curator が書き込み前の検証に使います。`intrahub-mastra`のリポジトリ内で frontmatter を再定義しないのは、二重定義が必ず食い違うためです。

## tech-notes

`tech-notes`は独立した Git リポジトリのため、ここでは作りません。`.gitignore`で除外だけしてあります。クローンまたはマウントで配置してください。

## 所有権

`root`で実行し、最後に`LIBRARY_UID:LIBRARY_GID`へ`chown`します。Mastra と Samba が同じ UID で書き込むためです。ホストの絶対パスを`KNOWLEDGE_SOURCE`へ指定していて`chown`が失敗する場合は警告を出して続行します。
