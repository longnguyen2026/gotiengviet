#!/usr/bin/env bash
# VDKey installer with optional, selective removal of other Vietnamese input methods.
# Does not remove fcitx5, ibus, or desktop components.

set -Eeuo pipefail

REPO="longnguyen2026/vdkey"
TMP_DIR=""

log()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
warn() { printf '\033[1;33m  CẢNH BÁO: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31m  LỖI: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then rm -rf -- "$TMP_DIR"; fi
}
trap cleanup EXIT

if [[ $EUID -eq 0 ]]; then SUDO=(); else
    command -v sudo >/dev/null 2>&1 || die "Không tìm thấy sudo."
    SUDO=(sudo)
fi
apt_run() { "${SUDO[@]}" apt-get "$@"; }

# Explicit package allowlist: never use wildcard removal.
CANDIDATE_PACKAGES=(
    ibus-unikey ibus-bamboo ibus-table-unikey
    fcitx-lotus fcitx-ngosen
    fcitx5-lotus fcitx5-ngosen fcitx5-vietfox
    fcitx5-unikey fcitx5-bamboo
)

is_installed() {
    dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null | grep -qx installed
}

declare -a FOUND=()
for pkg in "${CANDIDATE_PACKAGES[@]}"; do
    if is_installed "$pkg"; then FOUND+=("$pkg"); fi
done

log "VDKey – KIỂM TRA VÀ QUẢN LÝ BỘ GÕ TIẾNG VIỆT"
info "Chỉ gỡ các gói bạn chọn; không tự gỡ fcitx5, ibus hoặc thành phần desktop."

if ((${#FOUND[@]})); then
    log "Các gói đang được cài:"
    for i in "${!FOUND[@]}"; do printf '  %d) %s\n' "$((i + 1))" "${FOUND[$i]}"; done
    printf '  A) Chọn tất cả\n  0) Không gỡ gói nào\n'
    read -r -p "Nhập lựa chọn (ví dụ: 1 3): " selection
    selection="${selection//,/ }"
    declare -A SELECTED=()

    if [[ "$selection" =~ (^|[[:space:]])[Aa]($|[[:space:]]) ]]; then
        for pkg in "${FOUND[@]}"; do SELECTED["$pkg"]=1; done
    elif [[ -n "$selection" && "$selection" != "0" ]]; then
        for item in $selection; do
            [[ "$item" =~ ^[0-9]+$ ]] || die "Lựa chọn không hợp lệ: $item"
            (( item >= 1 && item <= ${#FOUND[@]} )) || die "Số lựa chọn ngoài danh sách: $item"
            SELECTED["${FOUND[$((item - 1))]}"]=1
        done
    fi

    if ((${#SELECTED[@]})); then
        log "Các gói sẽ được gỡ:"
        for pkg in "${!SELECTED[@]}"; do info "$pkg"; done
        read -r -p "Xác nhận gỡ các gói này? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # 'remove' preserves package configuration files.
            apt_run remove -y "${!SELECTED[@]}" ||
                die "Gỡ gói thất bại. Hãy xem thông báo apt phía trên."
            log "Đã gỡ các gói được chọn."
        else
            info "Đã hủy thao tác gỡ."
        fi
    else
        info "Không chọn gỡ gói nào."
    fi
else
    info "Không phát hiện gói nào trong danh sách kiểm tra."
fi

printf '\n'
read -r -p "Bạn có muốn tải và cài VDKey ngay bây giờ? [y/N]: " install_choice
if [[ ! "$install_choice" =~ ^[Yy]$ ]]; then
    log "Đã thoát. VDKey chưa được cài."
    exit 0
fi

command -v curl >/dev/null 2>&1 || {
    log "Cài công cụ tải xuống..."
    apt_run update
    apt_run install -y curl ca-certificates
}
command -v python3 >/dev/null 2>&1 || die "Cần python3 để đọc thông tin GitHub Release."

TMP_DIR="$(mktemp -d)"
DEB_PATH="$TMP_DIR/vdkey.deb"

shopt -s nullglob
LOCAL_DEBS=(./vdkey*.deb)
shopt -u nullglob
if ((${#LOCAL_DEBS[@]})); then
    printf 'Tìm thấy DEB cục bộ: %s\n' "${LOCAL_DEBS[0]}"
    read -r -p "Dùng gói cục bộ này? [Y/n]: " local_choice
    if [[ ! "$local_choice" =~ ^[Nn]$ ]]; then cp -- "${LOCAL_DEBS[0]}" "$DEB_PATH"; fi
fi

if [[ ! -s "$DEB_PATH" ]]; then
    log "Đang tìm gói DEB trong GitHub Releases..."
    RELEASE_JSON="$TMP_DIR/release.json"
    curl -fLsS --retry 2 "https://api.github.com/repos/${REPO}/releases/latest" -o "$RELEASE_JSON" ||
        die "Không truy cập được GitHub Releases của ${REPO}."

    ASSET_URL="$(python3 - "$RELEASE_JSON" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    release = json.load(f)
assets = release.get("assets", [])
urls = [a.get("browser_download_url", "") for a in assets
        if a.get("name", "").lower().endswith(".deb")]
print(urls[0] if urls else "")
PY
)"
    [[ -n "$ASSET_URL" ]] || die "Release mới nhất chưa đính kèm file .deb."
    info "Đang tải gói VDKey..."
    curl -fL --retry 2 "$ASSET_URL" -o "$DEB_PATH" || die "Tải DEB thất bại."
fi

dpkg-deb --info "$DEB_PATH" >/dev/null 2>&1 || die "Tệp tải về không phải DEB hợp lệ."

log "Đang cài VDKey và các phụ thuộc..."
apt_run install -y "$DEB_PATH" || die "Cài VDKey thất bại."

log "CÀI ĐẶT VDKEY HOÀN TẤT"
info "Nếu VDKey chưa xuất hiện trong Fcitx5, hãy đăng xuất rồi đăng nhập lại."
info "Script không tự đổi profile hoặc bộ gõ mặc định."
