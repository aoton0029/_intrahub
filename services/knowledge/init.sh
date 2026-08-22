#!/bin/sh
# Knowledge Vault の初期化。intrahub の起動時に knowledge-init から実行される。
#
#   1. ディレクトリ骨格が無ければ作る
#   2. seed のバージョンと導入済みバージョンを比較し、seed が新しいときだけ管理対象を上書きする
#   3. 上書きの前後を Git のコミットとして残す
#
# 冪等。同じバージョンで何度実行しても Vault は変化しない。
set -eu

SEED_DIR="${SEED_DIR:-/seed}"
VAULT_DIR="${VAULT_DIR:-/vault}"
MARKER="${VAULT_DIR}/.knowledge-seed-version"
FORCE="${KNOWLEDGE_SEED_FORCE:-false}"
OWNER_UID="${LIBRARY_UID:-1000}"
OWNER_GID="${LIBRARY_GID:-1000}"

log() { echo "[knowledge-init] $*"; }
die() { echo "[knowledge-init] ERROR: $*" >&2; exit 1; }

[ -d "$SEED_DIR" ] || die "seed ディレクトリが見つからない: $SEED_DIR"
[ -f "$SEED_DIR/VERSION" ] || die "seed に VERSION が無い"
[ -d "$VAULT_DIR" ] || die "Vault のマウント先が見つからない: $VAULT_DIR"

SEED_VERSION="$(tr -d ' \t\r\n' < "$SEED_DIR/VERSION")"
[ -n "$SEED_VERSION" ] || die "seed の VERSION が空"

# --- バージョン比較 -----------------------------------------------------------
# busybox の sort -V に依存せず、x.y.z を数値として自前で比較する。
# 戻り値 0 = $1 が $2 より古い。
version_lt() {
    _a="$1"
    _b="$2"
    _i=1
    while [ "$_i" -le 3 ]; do
        _av="$(echo "$_a" | cut -d. -f"$_i")"
        _bv="$(echo "$_b" | cut -d. -f"$_i")"
        [ -n "$_av" ] || _av=0
        [ -n "$_bv" ] || _bv=0
        case "$_av$_bv" in
            *[!0-9]*) return 1 ;;  # 数値でない要素があれば「古くない」扱いにして上書きを避ける
        esac
        [ "$_av" -lt "$_bv" ] && return 0
        [ "$_av" -gt "$_bv" ] && return 1
        _i=$((_i + 1))
    done
    return 1
}

# --- ディレクトリ骨格 ---------------------------------------------------------
# 常に実行する。既にあるディレクトリには触れない。
ensure_dirs() {
    _created=0
    while IFS= read -r _line; do
        case "$_line" in ''|'#'*) continue ;; esac
        _path="${VAULT_DIR}/${_line}"
        if [ ! -d "$_path" ]; then
            mkdir -p "$_path"
            log "created ${_line}/"
            _created=$((_created + 1))
        fi
        # 空ディレクトリを Git が保持できるようにする。中身が入れば .gitkeep は残ってよい。
        [ -e "${_path}/.gitkeep" ] || : > "${_path}/.gitkeep"
    done < "${SEED_DIR}/dirs.txt"
    log "directories ensured (${_created} created)"
}

# --- 管理対象ファイルの配置 ---------------------------------------------------
# seed/files 配下をそのまま Vault へ重ねる。seed に無いファイルは削除しない。
install_files() {
    tar -C "${SEED_DIR}/files" -cf - . | tar -C "$VAULT_DIR" -xf -
    log "seed files installed from ${SEED_DIR}/files"
}

# --- Git ---------------------------------------------------------------------
git_available() { command -v git >/dev/null 2>&1; }

git_run() { git -C "$VAULT_DIR" "$@"; }

ensure_git() {
    git_available || { log "git が無いため履歴を残さない"; return 1; }
    git config --global --add safe.directory "$VAULT_DIR" 2>/dev/null || true
    if [ ! -d "${VAULT_DIR}/.git" ]; then
        git_run init -q -b main
        git_run config user.name "knowledge-init"
        git_run config user.email "knowledge-init@intrahub.local"
        log "git リポジトリを初期化した"
    fi
    return 0
}

git_commit() {
    _msg="$1"
    git_available || return 0
    [ -d "${VAULT_DIR}/.git" ] || return 0
    git_run add -A
    if git_run diff --cached --quiet; then
        return 0
    fi
    git_run -c user.name="knowledge-init" -c user.email="knowledge-init@intrahub.local" \
        commit -q -m "$_msg"
    log "commit: ${_msg}"
}

# --- 所有権 -------------------------------------------------------------------
fix_ownership() {
    # root で走るため、Mastra と Samba が書けるように戻す。
    chown -R "${OWNER_UID}:${OWNER_GID}" "$VAULT_DIR" 2>/dev/null \
        || log "chown に失敗した（マウント元の都合であれば無視してよい）"
}

# --- 本体 ---------------------------------------------------------------------
INSTALLED_VERSION=""
[ -f "$MARKER" ] && INSTALLED_VERSION="$(tr -d ' \t\r\n' < "$MARKER")"

ensure_git || true

if [ -z "$INSTALLED_VERSION" ]; then
    log "初回初期化 (seed ${SEED_VERSION})"
    ensure_dirs
    install_files
    echo "$SEED_VERSION" > "$MARKER"
    git_commit "knowledge: seed ${SEED_VERSION} を導入"
    fix_ownership
    log "done"
    exit 0
fi

ensure_dirs

if [ "$FORCE" = "true" ]; then
    log "KNOWLEDGE_SEED_FORCE=true のため強制的に再配置する (${INSTALLED_VERSION} -> ${SEED_VERSION})"
elif version_lt "$INSTALLED_VERSION" "$SEED_VERSION"; then
    log "seed が新しい (${INSTALLED_VERSION} -> ${SEED_VERSION})"
else
    log "導入済み ${INSTALLED_VERSION} は seed ${SEED_VERSION} 以上。ファイルは変更しない"
    git_commit "knowledge: ディレクトリ骨格を補完"
    fix_ownership
    log "done"
    exit 0
fi

# 上書きの直前に、人手編集を含む現状をコミットして戻せるようにしておく。
git_commit "knowledge: seed ${SEED_VERSION} 適用前の状態を保存"
install_files
echo "$SEED_VERSION" > "$MARKER"
git_commit "knowledge: seed を ${INSTALLED_VERSION} から ${SEED_VERSION} へ更新"
fix_ownership
log "done"
