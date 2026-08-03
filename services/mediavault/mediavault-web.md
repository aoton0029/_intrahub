← [mediavault/README.md](./README.md)

# mediavault-web

MediaVault の管理UI。React + TypeScript の単一SPA をビルドし、nginx で配信する。一覧・検索・詳細・登録・編集を担う。

## イメージ

| 項目 | 値 |
|---|---|
| イメージ | `ghcr.io/aoton0029/intrahub-mediavault-web:0.1.0` |
| ソース | `intrahub-mediavault` リポジトリの `frontend/` |
| Dockerfile | `frontend/Dockerfile`（`node:20-slim` でビルドし `nginx:alpine` へ `dist` と `nginx.conf` をコピー） |
| 発行 | アプリリポジトリの CI が `v*` タグで GHCR へ push する |

## 実行

| 項目 | 値 |
|---|---|
| `container_name` | `mediavault-web` |
| `restart` | `unless-stopped` |

## ポート

| 内部ポート | 用途 |
|---|---|
| `80` | nginx による静的配信と `/api/` のプロキシ |

## ネットワーク

| ネットワーク | 定義 | 用途 |
|---|---|---|
| `proxy-net` | `external: true` | Caddy からの到達と、`backend`（= `mediavault-api`）への転送 |

nginx.conf は upstream を `backend` というホスト名で引く。本番のコンテナ名は `mediavault-api` なので、`mediavault-api` 側に `backend` のネットワークエイリアスを与えて `nginx.conf` を環境ごとに分けずに済ませている。

## 依存

`mediavault-api` が `service_healthy` になるまで起動しない。

## 環境変数

| 変数名 | Composeでの値 | 必須 | 秘密 | 既定値 | 用途 |
|---|---|---|---|---|---|
| `TZ` | `${TZ:?}` | ○ | | | nginx のログのタイムゾーン |

アプリが満たすこと:

- **秘密情報を渡さないこと。** ビルド時に埋め込まれる `VITE_` 付きの変数はJSバンドルへ平文で焼き込まれ、ブラウザから誰でも読める。APIキーの類は必ず `mediavault-api` 側に置く
- API のベースURLをビルド時に固定しないこと。ブラウザからは同一オリジンの `/api/` へ投げ、nginx が `backend` へ転送する

## 責務の境界

| 持つもの | 内容 |
|---|---|
| 一覧・検索 | `media_type` / タグ / カテゴリ / お気に入りによる絞り込み |
| 詳細表示 | メタデータ、関連ファイル、リンク、関連 `knowledge` |
| 編集 | 手動での登録・編集・削除 |
| 閲覧導線 | `item_links` を基に「Jellyfin で再生」「Calibre-Web で開く」を**別タブ**で開く |
| ナレッジUI | Wiki生成のトリガーと、生成結果の表示 |

| 持たないもの | 担当 |
|---|---|
| 動画・マンガのビューア | Jellyfin / Calibre-Web。iframe 埋め込みもしない |
| 要約・Wiki の生成ロジックとプロンプト | KnowledgeHub 側のエージェント |
| `mediavault-api` 以外への直接アクセス | 禁止 |
