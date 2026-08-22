# AGENTS.md

Knowledge Vault を編集するエージェント向けの規則。詳細は `README.md`。

## 絶対に守る

- **`confidence: verified` を付けない。** 新規カードは `hearsay` か `reasoned` のみ。昇格は人間が手で行う。
- **`owner: human` のノートを書き換えない。** 変更が必要なら差分を `second-brain/00-Inbox/` へ出す。
- **`second-brain/90-Meta/`、`tech-notes/MOC/`、`tech-notes/templates/` を編集しない。** 読むだけ。変更は提案に留める。
- **既存ノートを改名・移動しない。** リンクが壊れる。必要なら確認を取る。
- **出典のない記述を書かない。** 根拠が示せないならノートを作らない。

## 書く場所

| 内容 | 場所 |
|---|---|
| 資料（作品・論文・専門書）由来 | `second-brain/10-Sources/` |
| 概念・テーマ・人物など再利用する知識 | `second-brain/20-Knowledge/` |
| 比較・年表・論考 | `second-brain/30-Syntheses/` |
| 開発で得た技術知識 | `tech-notes/knowledge/<カテゴリ>/` |
| 設計判断の記録 | `tech-notes/decisions/` |
| 確信度が低い・競合する結果 | `second-brain/00-Inbox/` |
| 中間データ、下書き | `ai-workspace/` |

Web ページ単位のノートは作らない。内容は Concept / Theme に書き、URL と `retrieved` を `sources` に残す。

プロジェクト固有の設定値・実装手順・API の使い方は Vault に置かない。各リポジトリの `docs/` に残す。

## 命名

- ディレクトリ: `second-brain` は `10-Sources` 形式（ハイフン区切り、空白なし）。`tech-notes` は kebab-case。
- ファイル名: 日本語の見出し名をそのまま。ローマ字化・英訳しない。別名は `aliases` へ。
- 章・節・話数: `{番号}-{見出し}`。番号はゼロパディング。
- 使わない文字: `/ \ : * ? " < > | # ^ [ ]`、先頭末尾の空白とピリオド。

## リンク

- `second-brain`: Vault ルートからの**絶対パス**。`[[20-Knowledge/Concepts/唯識]]`
- `tech-notes`: basename の `[[wikilink]]`。ファイル名は Vault 全体で一意。

## 作成前に確認する

1. 同名ノートが既にないか（`20-Knowledge` 以下は Vault 全体で一意）
2. 同じ内容のノートが既にないか（重複より更新を優先）
3. `second-brain/90-Meta/` の taxonomy に無いタグを使っていないか（未登録語は提案として残す）
