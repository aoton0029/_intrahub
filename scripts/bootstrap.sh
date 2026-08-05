#!/bin/sh
# IntraHub の初期構築。.env と services/bookmarks/config.yml を用意する。
#
# ネットワークとボリュームは Compose が作るので、このスクリプトは触らない。例外は
# BULK_ROOT を使う場合で、bind の device は起動時に存在している必要があるため
# ディレクトリだけ先に掘る。
#
#   ./scripts/bootstrap.sh            対話で聞きながら .env を作る（既にあれば触らない）
#   ./scripts/bootstrap.sh --force    .env を作り直す
#
# 対話できない環境（CI など）では、聞く項目を環境変数で渡せば非対話で通る。
#
#   BASE_DOMAIN=example.com CLOUDFLARE_API_TOKEN=xxx ./scripts/bootstrap.sh
set -eu

REPO_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
ENV_FILE="$REPO_DIR/.env"
ENV_EXAMPLE="$REPO_DIR/.env.example"
WEBDAV_CONFIG="$REPO_DIR/services/bookmarks/config.yml"
WEBDAV_EXAMPLE="$REPO_DIR/services/bookmarks/config.yml.example"

FORCE=0
for arg in "$@"; do
	case "$arg" in
	--force) FORCE=1 ;;
	-h | --help)
		# shebang の次から続く先頭のコメントブロックをそのまま出す
		awk 'NR>1 && /^#/ {sub(/^# ?/, ""); print; next} NR>1 {exit}' "$0"
		exit 0
		;;
	*)
		echo "bootstrap: 不明な引数: $arg" >&2
		exit 2
		;;
	esac
done

die() {
	echo "bootstrap: $*" >&2
	exit 1
}

# 秘密情報を生成する。sed の置換値に使うので / と | を含まない文字だけにする。
gen_secret() {
	if command -v openssl >/dev/null 2>&1; then
		openssl rand -base64 32 | tr -d '/+=\n'
	else
		od -An -tx1 -N24 /dev/urandom | tr -d ' \n'
	fi
}

# 対話なら聞き、非対話なら同名の環境変数か既定値を採る。
# ask <変数名> <プロンプト> <既定値>
ask() {
	_name=$1
	_prompt=$2
	_default=$3
	eval "_preset=\${$_name:-}"

	if [ -n "$_preset" ]; then
		echo "$_preset"
		return
	fi
	if [ ! -t 0 ]; then
		echo "$_default"
		return
	fi

	if [ -n "$_default" ]; then
		printf '%s [%s]: ' "$_prompt" "$_default" >&2
	else
		printf '%s: ' "$_prompt" >&2
	fi
	read -r _answer || _answer=''
	[ -n "$_answer" ] || _answer=$_default
	echo "$_answer"
}

# set_var <キー> <値> — .env の該当行を置換する。値に | を含めないこと。
set_var() {
	grep -q "^$1=" "$ENV_FILE" || die "$1 が .env.example に無い"
	sed -i.bak "s|^$1=.*|$1=$2|" "$ENV_FILE"
	rm -f "$ENV_FILE.bak"
}

# ---- .env ----

if [ -f "$ENV_FILE" ] && [ "$FORCE" -eq 0 ]; then
	echo ".env は既にある。作り直すなら --force を付ける。"
else
	[ -f "$ENV_EXAMPLE" ] || die "$ENV_EXAMPLE が無い"

	BASE_DOMAIN=$(ask BASE_DOMAIN 'ベースドメイン（例 intrahub.example.com）' '')
	[ -n "$BASE_DOMAIN" ] || die 'BASE_DOMAIN は必須'
	CLOUDFLARE_API_TOKEN=$(ask CLOUDFLARE_API_TOKEN 'Cloudflare APIトークン（Zone:Read + DNS:Edit）' '')
	[ -n "$CLOUDFLARE_API_TOKEN" ] || die 'CLOUDFLARE_API_TOKEN は必須'

	_tz_default=UTC
	[ -r /etc/timezone ] && _tz_default=$(cat /etc/timezone)
	TZ=$(ask TZ 'タイムゾーン（IANA名）' "$_tz_default")

	SAMBA_USER=$(ask SAMBA_USER 'Samba のユーザー名' 'intrahub')
	BOOKMARKS_USER=$(ask BOOKMARKS_USER 'Bookmarks(WebDAV) のユーザー名' 'intrahub')

	_use_gpu=$(ask USE_GPU 'vLLM を使う（NVIDIA GPU が要る）? [y/N]' 'n')
	_use_research=$(ask USE_RESEARCH 'Open Deep Research を使う（langgraph build 済みのイメージが要る）? [y/N]' 'n')

	COMPOSE_PROFILES=''
	case "$_use_gpu" in [yY]*) COMPOSE_PROFILES='gpu' ;; esac
	case "$_use_research" in
	[yY]*) COMPOSE_PROFILES="${COMPOSE_PROFILES:+$COMPOSE_PROFILES,}research" ;;
	esac

	BULK_ROOT=$(ask BULK_ROOT 'メディア原本とモデルキャッシュを置く実パス（空なら named volume のまま）' '')
	case "$BULK_ROOT" in
	'' | /*) ;;
	*) die 'BULK_ROOT は絶対パスで指定する' ;;
	esac

	umask 077
	cp "$ENV_EXAMPLE" "$ENV_FILE"

	set_var TZ "$TZ"
	set_var COMPOSE_PROFILES "$COMPOSE_PROFILES"
	set_var BULK_ROOT "$BULK_ROOT"
	set_var BASE_DOMAIN "$BASE_DOMAIN"
	set_var CLOUDFLARE_API_TOKEN "$CLOUDFLARE_API_TOKEN"
	set_var SAMBA_USER "$SAMBA_USER"
	set_var BOOKMARKS_USER "$BOOKMARKS_USER"

	# 環境で変える必要のない識別子
	set_var POSTGRES_USER mediavault
	set_var POSTGRES_DB mediavault

	# 秘密情報。値はこのリポジトリのどこにも書かず、.env にだけ置く。
	for _key in POSTGRES_PASSWORD INTERNAL_API_KEY VLLM_API_KEY LITELLM_MASTER_KEY \
		HERMES_PG_PASSWORD ODR_PG_PASSWORD SAMBA_PASSWORD BOOKMARKS_PASSWORD; do
		set_var "$_key" "$(gen_secret)"
	done

	if [ -n "$BULK_ROOT" ]; then
		# COMPOSE_PATH_SEPARATOR の既定はプラットフォーム依存（Windows は ;）なので明示する。
		{
			printf '\n# bootstrap.sh が追記。BULK_ROOT を使うため compose.bind.yaml を重ねる。\n'
			printf 'COMPOSE_PATH_SEPARATOR=:\n'
			printf 'COMPOSE_FILE=compose.yaml:compose.bind.yaml\n'
		} >>"$ENV_FILE"
	fi

	chmod 600 "$ENV_FILE"
	echo ".env を作った（秘密情報は自動生成した）。"
	echo "外部メタデータAPIのキー（TMDB / IGDB など）を使うなら .env に足す。"
fi

# 以降は .env の実値を使う
set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

# ---- services/bookmarks/config.yml ----

if [ -f "$WEBDAV_CONFIG" ] && [ "$FORCE" -eq 0 ]; then
	echo "services/bookmarks/config.yml は既にある。"
else
	[ -f "$WEBDAV_EXAMPLE" ] || die "$WEBDAV_EXAMPLE が無い"
	[ -n "${BOOKMARKS_USER:-}" ] || die 'BOOKMARKS_USER が .env に無い'
	[ -n "${BOOKMARKS_PASSWORD:-}" ] || die 'BOOKMARKS_PASSWORD が .env に無い'

	umask 077
	sed -e "s|username: REPLACE_ME|username: $BOOKMARKS_USER|" \
		-e "s|password: REPLACE_ME|password: $BOOKMARKS_PASSWORD|" \
		"$WEBDAV_EXAMPLE" >"$WEBDAV_CONFIG"
	echo "services/bookmarks/config.yml を .env の値から作った。"
fi

# ---- BULK_ROOT のディレクトリ ----
# compose.bind.yaml の o: bind は device が存在しないと起動時にマウント失敗する。

if [ -n "${BULK_ROOT:-}" ]; then
	# shares/ の中のカテゴリ（video, vault など）は shares-init が掘るのでここでは触らない。
	for _dir in shares mediavault cache/vllm; do
		mkdir -p "$BULK_ROOT/$_dir"
	done
	# shares は samba と hermes-agent（ともに 1000:1000）が、モデルキャッシュは
	# vllm(2000:0) が書く。named volume なら init コンテナが揃えるが、bind の場合は
	# ホスト側の所有権がそのまま見えるのでここで合わせる。
	if [ "$(id -u)" -eq 0 ]; then
		chown -R 1000:1000 "$BULK_ROOT/shares"
		chown -R 2000:0 "$BULK_ROOT/cache/vllm"
	else
		echo "注意: root で実行していないので $BULK_ROOT 配下の所有権は変えていない。" >&2
		echo "      sudo chown -R 1000:1000 $BULK_ROOT/shares" >&2
		echo "      sudo chown -R 2000:0 $BULK_ROOT/cache/vllm" >&2
	fi
	echo "BULK_ROOT=$BULK_ROOT 配下のディレクトリを用意した。"
fi

# ---- 確認 ----

command -v docker >/dev/null 2>&1 || die 'docker が無い'

if ! grep -q 'ghcr.io' "${DOCKER_CONFIG:-$HOME/.docker}/config.json" 2>/dev/null; then
	echo
	echo "注意: ghcr.io へログインしていない。mediavault と mastra は private パッケージなので"
	echo "      read:packages 権限のトークンで一度 docker login ghcr.io が必要。"
fi

echo
echo "docker compose config で解決を確認する..."
(cd "$REPO_DIR" && docker compose config >/dev/null)
echo "OK。次は docker compose up -d"
