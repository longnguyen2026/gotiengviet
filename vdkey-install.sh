#!/usr/bin/env bash
# VDKey installer: scan, optionally remove selected Vietnamese input methods,
# then optionally download and install the latest DEB from GitHub Releases.
# Does NOT remove the IBus/Fcitx framework or desktop components.

set -Eeuo pipefail

REPO="longnguyen2026/gotiengviet"
TMP_DIR=""

log()  { printf '\n\033[1;36m%s\033[0m\n' "$*"; }
info() { printf '  %s\n' "$*"; }
die()  { printf '\033[1;31mLỖI: %s\033[0m\n' "$*" >&2; exit 1; }

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf -- "$TMP_DIR"
    fi
}
trap cleanup EXIT

# Use sudo only when the script is not already running as root.
if [[ "$EUID" -eq 0 ]]; then
    SUDO=()
else
    command -v sudo >/dev/null 2>&1 || die "Không tìm thấy sudo."
    SUDO=(sudo)
fi

apt_run() {
    "${SUDO[@]}" apt-get "$@"
}

# Explicit package allowlist. Never use wildcards for package removal.
# Package names can vary between distributions/releases; only installed
# packages from this list will be offered.
CANDIDATE_PACKAGES=(
    ibus-unikey
    ibus-bamboo
    ibus-table-unikey
    fcitx-unikey
    fcitx-bamboo
    fcitx-lotus
    fcitx-ngosen
    fcitx5-unikey
    fcitx5-bamboo
    fcitx5-lotus
    fcitx5-ngosen
    fcitx5-vietfox
)

is_installed() {
    local status
    status="$(dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null || true)"
    [[ "$status" == "installed" ]]
}

declare -a FOUND=()
for pkg in "${CANDIDATE_PACKAGES[@]}"; do
    if is_installed "$pkg"; then
        FOUND+=("$pkg")
    fi
done

log "VDKey – KIỂM TRA BỘ GÕ TIẾNG VIỆT"
info "Chỉ gỡ các gói bạn chọn. Script không tự gỡ ibus, fcitx5 hoặc thành phần desktop."

if ((${#FOUND[@]} > 0)); then
    log "Phát hiện các gói sau:"
    for i in "${!FOUND[@]}"; do
        printf '  %d) %s\n' "$((i + 1))" "${FOUND[$i]}"
    done
    printf '  A) Chọn tất cả gói được liệt kê\n'
    printf '  0) Không gỡ gói nào\n\n'

    read -r -p "Nhập số cần gỡ (ví dụ: 1 3), A hoặc 0: " selection
    selection="${selection//,/ }"

    declare -A SELECTED=()
    if [[ "$selection" =~ (^|[[:space:]])[Aa]($|[[:space:]]) ]]; then
        for pkg in "${FOUND[@]}"; do
            SELECTED["$pkg"]=1
        done
    elif [[ -n "$selection" && "$selection" != "0" ]]; then
        for item in $selection; do
            [[ "$item" =~ ^[0-9]+$ ]] || die "Lựa chọn không hợp lệ: $item"
            (( item >= 1 && item <= ${#FOUND[@]} )) ||
                die "Số lựa chọn nằm ngoài danh sách: $item"
            SELECTED["${FOUND[$((item - 1))]}"]=1
        done
    fi

    if ((${#SELECTED[@]} > 0)); then
        log "Các gói được chọn để gỡ:"
        for pkg in "${!SELECTED[@]}"; do
            info "$pkg"
        done

        read -r -p "Xác nhận gỡ các gói trên? [y/N]: " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            # remove (not purge) keeps package configuration files.
            apt_run remove -y "${!SELECTED[@]}" ||
                die "Gỡ gói thất bại. Hãy đọc thông báo apt phía trên."
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

# Ensure download and package-inspection tools are present.
NEED_PACKAGES=()
command -v curl >/dev/null 2>&1 || NEED_PACKAGES+=(curl)
command -v python3 >/dev/null 2>&1 || NEED_PACKAGES+=(python3)
command -v dpkg-deb >/dev/null 2>&1 || NEED_PACKAGES+=(dpkg)

if ((${#NEED_PACKAGES[@]} > 0)); then
    log "Cài công cụ cần thiết: ${NEED_PACKAGES[*]}"
    apt_run update
    apt_run install -y ca-certificates "${NEED_PACKAGES[@]}"
fi

TMP_DIR="$(mktemp -d)"
DEB_PATH="$TMP_DIR/vdkey.deb"

# Prefer a local VDKey DEB in the current directory if the user confirms.
shopt -s nullglob
LOCAL_DEBS=(./vdkey*.deb)
shopt -u nullglob

if ((${#LOCAL_DEBS[@]} > 0)); then
    printf '\nTìm thấy DEB cục bộ: %s\n' "${LOCAL_DEBS[0]}"
    read -r -p "Bạn muốn dùng file DEB cục bộ này? [Y/n]: " local_choice
    if [[ ! "$local_choice" =~ ^[Nn]$ ]]; then
        cp -- "${LOCAL_DEBS[0]}" "$DEB_PATH"
    fi
fi

# If no local DEB was selected, query the latest release of gotiengviet.
if [[ ! -s "$DEB_PATH" ]]; then
    log "Đang tìm DEB trong GitHub Releases: $REPO"
    RELEASE_JSON="$TMP_DIR/release.json"

    curl -fLsS --retry 2 \
        "https://api.github.com/repos/${REPO}/releases/latest" \
        -o "$RELEASE_JSON" ||
        die "Không tải được thông tin GitHub Release. Kiểm tra mạng hoặc quyền truy cập repository."

    ASSET_URL="$(python3 - "$RELEASE_JSON" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as f:
    release = json.load(f)

assets = release.get("assets", [])
matches = [
    asset.get("browser_download_url", "")
    for asset in assets
    if asset.get("name", "").lower().endswith(".deb")
]
print(matches[0] if matches else "")
PY
)"

    [[ -n "$ASSET_URL" ]] ||
        die "Release mới nhất không có tệp .deb. Hãy đính kèm vdkey-1.0.0-Linux.deb vào GitHub Release."

    info "Đang tải gói DEB từ Release mới nhất..."
    curl -fL --retry 2 "$ASSET_URL" -o "$DEB_PATH" ||
        die "Tải gói DEB thất bại."
fi

# Validate the downloaded/local package before installing.
dpkg-deb --info "$DEB_PATH" >/dev/null 2>&1 ||
    die "Tệp được chọn không phải gói DEB hợp lệ."

log "Đang cài VDKey và các phụ thuộc..."
apt_run install -y "$DEB_PATH" ||
    die "Cài VDKey thất bại. Hãy xem thông báo apt phía trên."

log "CÀI ĐẶT VDKEY HOÀN TẤT"
info "Nếu VDKey chưa xuất hiện trong danh sách Fcitx5, hãy đăng xuất rồi đăng nhập lại."
info "Script không tự đổi profile, không tự chọn bộ gõ mặc định và không xóa cấu hình người dùng."
