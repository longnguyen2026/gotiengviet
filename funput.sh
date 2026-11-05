#!/usr/bin/env bash
# Funput installer for Kubuntu / KDE Plasma (Wayland and X11)
# Official instructions: https://docs.funput.app/docs/install/linux/
set -Eeuo pipefail

readonly REPO_KEY_URL="https://repo.funput.app/funput.asc"
readonly REPO_FILE="/etc/apt/sources.list.d/funput.sources"
readonly KEY_FILE="/usr/share/keyrings/funput.asc"
readonly ENV_DIR="${HOME}/.config/environment.d"
readonly ENV_FILE="${ENV_DIR}/fcitx5.conf"

log()  { printf '\033[1;32m[Funput]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[Canh bao]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[LOI]\033[0m %s\n' "$*" >&2; exit 1; }

backup_file() {
    local file="$1"
    if [[ -e "$file" ]]; then
        local stamp
        stamp="$(date +%Y%m%d-%H%M%S)"
        sudo cp -a "$file" "${file}.bak-${stamp}"
        log "Đã sao lưu: ${file}.bak-${stamp}"
    fi
}

[[ "${EUID}" -ne 0 ]] || die "Không chạy script bằng sudo. Hãy chạy bằng tài khoản người dùng thường."
command -v apt-get >/dev/null 2>&1 || die "Script này dành cho Kubuntu/Ubuntu dùng APT."
command -v sudo >/dev/null 2>&1 || die "Không tìm thấy sudo."
sudo -v

desktop="${XDG_CURRENT_DESKTOP:-}"
session="${XDG_SESSION_TYPE:-}"

[[ "${desktop,,}" == *kde* || "${desktop,,}" == *plasma* ]] || \
    die "Không nhận diện được KDE Plasma (XDG_CURRENT_DESKTOP=${desktop:-trống})."

case "$session" in
    wayland|x11) ;;
    *) die "Không xác định được loại phiên đăng nhập: ${session:-trống}. Hãy đăng nhập vào KDE Wayland hoặc X11 rồi chạy lại." ;;
esac

log "Môi trường: KDE Plasma / ${session}"
log "Cài các công cụ cần thiết..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl im-config fcitx5 fcitx5-config-qt

# Thêm kho APT chính thức có xác thực chữ ký GPG.
log "Thiết lập kho Funput chính thức..."
tmp_key="$(mktemp)"
trap 'rm -f "$tmp_key"' EXIT
curl -fL --retry 3 --connect-timeout 15 "$REPO_KEY_URL" -o "$tmp_key"
[[ -s "$tmp_key" ]] || die "Không tải được khóa GPG Funput."

sudo install -d -m 0755 /usr/share/keyrings
backup_file "$KEY_FILE"
sudo install -m 0644 "$tmp_key" "$KEY_FILE"

tmp_repo="$(mktemp)"
cat > "$tmp_repo" <<'REPO'
Types: deb
URIs: https://repo.funput.app/deb
Suites: ./
Signed-By: /usr/share/keyrings/funput.asc
REPO
backup_file "$REPO_FILE"
sudo install -m 0644 "$tmp_repo" "$REPO_FILE"
rm -f "$tmp_repo"

log "Cập nhật danh sách gói và cài Funput..."
sudo apt-get update
sudo apt-get install -y funput

# Cấu hình theo khuyến nghị riêng cho KDE.
if [[ "$session" == "wayland" ]]; then
    log "Cấu hình KDE Wayland: chỉ đặt XMODIFIERS (không đặt GTK_IM_MODULE/QT_IM_MODULE)."
    mkdir -p "$ENV_DIR"
    if [[ -e "$ENV_FILE" ]]; then
        cp -a "$ENV_FILE" "${ENV_FILE}.bak-$(date +%Y%m%d-%H%M%S)"
        # Preserve unrelated environment entries; replace only XMODIFIERS.
        sed -i '/^[[:space:]]*XMODIFIERS=/d' "$ENV_FILE"
    else
        : > "$ENV_FILE"
    fi
    {
        printf '%s\\n' '# Funput / Fcitx5 environment for KDE Plasma Wayland'
        printf '%s\\n' '# KDE Wayland: intentionally do not set GTK_IM_MODULE or QT_IM_MODULE.'
        printf '%s\\n' 'XMODIFIERS=@im=fcitx'
    } >> "$ENV_FILE"
else
    log "Cấu hình KDE X11 thông qua im-config..."
    im-config -n fcitx5
fi

printf '\n'
log "CÀI ĐẶT HOÀN TẤT."
printf '\n'
printf '%s\n' \
  "Việc cần làm tiếp theo:" \
  "1. Đăng xuất KDE rồi đăng nhập lại (hoặc khởi động lại máy)." \
  "2. KDE Wayland: mở System Settings → Keyboard → Virtual Keyboard" \
  "   (một số phiên bản Plasma hiển thị System Settings → Virtual keyboard)," \
  "   chọn Fcitx 5 làm bàn phím ảo." \
  "3. Mở Fcitx 5 Configuration (fcitx5-configtool)." \
  "4. Nhấn dấu +, bỏ chọn Only Show Current Language, tìm Funput trong nhóm Vietnamese và thêm vào." \
  "5. Mở ứng dụng Funput Settings để chọn Telex hoặc VNI." \
  "" \
  "Kiểm tra sau khi đăng nhập lại:" \
  "  fcitx5-diagnose" \
  "" \
  "Lưu ý: script không gỡ IBus, Bamboo, Unikey hoặc bất kỳ bộ gõ nào đang có."
