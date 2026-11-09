#!/usr/bin/env bash
# Fix IBus-Bamboo input in Google Chrome on Linux Mint
# Repository suggestion: longnguyen2026/fix-ibus-chrome-mint
set -Eeuo pipefail

SCRIPT_NAME="Fix IBus-Bamboo cho Google Chrome"
LOG_FILE="${HOME}/fix-ibus-chrome-$(date +%Y%m%d-%H%M%S).log"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

pause() {
    read -r -p "Nhấn Enter để tiếp tục..."
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

echo "============================================================"
echo "  ${SCRIPT_NAME}"
echo "  Kiểm tra và khắc phục tích hợp IBus GTK trên Linux Mint"
echo "============================================================"
echo

if [[ "${EUID}" -eq 0 ]]; then
    echo "Không chạy toàn bộ script bằng root."
    echo "Hãy chạy bằng tài khoản người dùng thông thường; script sẽ gọi sudo khi cần."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Không xác định được hệ điều hành (/etc/os-release không đọc được)."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "linuxmint" ]]; then
    echo "CẢNH BÁO: Script được thiết kế cho Linux Mint."
    echo "Hệ điều hành hiện tại: ${PRETTY_NAME:-không xác định}"
    read -r -p "Bạn vẫn muốn tiếp tục kiểm tra/cài các gói IBus GTK? [y/N] " answer
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]] || exit 0
fi

log "Hệ điều hành: ${PRETTY_NAME:-unknown}"
log "Phiên làm việc: ${XDG_SESSION_TYPE:-không xác định}"
log "Người dùng: ${SUDO_USER:-${USER:-unknown}}"

if has_command google-chrome; then
    log "Google Chrome: $(google-chrome --version 2>/dev/null || true)"
elif has_command google-chrome-stable; then
    log "Google Chrome: $(google-chrome-stable --version 2>/dev/null || true)"
else
    log "Không tìm thấy lệnh Google Chrome phổ biến; vẫn tiếp tục kiểm tra IBus GTK."
fi

if has_command ibus; then
    log "IBus: $(ibus version 2>/dev/null || echo 'không lấy được phiên bản')"
    engine="$(ibus engine 2>&1 || true)"
    log "IBus engine hiện tại: ${engine//$'\n'/ ; }"
else
    log "Không tìm thấy lệnh ibus."
fi

packages=(ibus-gtk3 ibus-gtk4)
missing=()

echo
echo "Kiểm tra các gói cần thiết:"
for package in "${packages[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
        log "$package: ĐÃ CÀI (${version})"
    else
#!/usr/bin/env bash
# Fix IBus-Bamboo input in Google Chrome on Linux Mint
# Repository suggestion: longnguyen2026/fix-ibus-chrome-mint
set -Eeuo pipefail

SCRIPT_NAME="Fix IBus-Bamboo cho Google Chrome"
LOG_FILE="${HOME}/fix-ibus-chrome-$(date +%Y%m%d-%H%M%S).log"

log() {
    printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*" | tee -a "$LOG_FILE"
}

pause() {
    read -r -p "Nhấn Enter để tiếp tục..."
}

has_command() {
    command -v "$1" >/dev/null 2>&1
}

echo "============================================================"
echo "  ${SCRIPT_NAME}"
echo "  Kiểm tra và khắc phục tích hợp IBus GTK trên Linux Mint"
echo "============================================================"
echo

if [[ "${EUID}" -eq 0 ]]; then
    echo "Không chạy toàn bộ script bằng root."
    echo "Hãy chạy bằng tài khoản người dùng thông thường; script sẽ gọi sudo khi cần."
    exit 1
fi

if [[ ! -r /etc/os-release ]]; then
    echo "Không xác định được hệ điều hành (/etc/os-release không đọc được)."
    exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != "linuxmint" ]]; then
    echo "CẢNH BÁO: Script được thiết kế cho Linux Mint."
    echo "Hệ điều hành hiện tại: ${PRETTY_NAME:-không xác định}"
    read -r -p "Bạn vẫn muốn tiếp tục kiểm tra/cài các gói IBus GTK? [y/N] " answer
    [[ "${answer,,}" == "y" || "${answer,,}" == "yes" ]] || exit 0
fi

log "Hệ điều hành: ${PRETTY_NAME:-unknown}"
log "Phiên làm việc: ${XDG_SESSION_TYPE:-không xác định}"
log "Người dùng: ${SUDO_USER:-${USER:-unknown}}"

if has_command google-chrome; then
    log "Google Chrome: $(google-chrome --version 2>/dev/null || true)"
elif has_command google-chrome-stable; then
    log "Google Chrome: $(google-chrome-stable --version 2>/dev/null || true)"
else
    log "Không tìm thấy lệnh Google Chrome phổ biến; vẫn tiếp tục kiểm tra IBus GTK."
fi

if has_command ibus; then
    log "IBus: $(ibus version 2>/dev/null || echo 'không lấy được phiên bản')"
    engine="$(ibus engine 2>&1 || true)"
    log "IBus engine hiện tại: ${engine//$'\n'/ ; }"
else
    log "Không tìm thấy lệnh ibus."
fi

packages=(ibus-gtk3 ibus-gtk4)
missing=()

echo
echo "Kiểm tra các gói cần thiết:"
for package in "${packages[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        version="$(dpkg-query -W -f='${Version}' "$package" 2>/dev/null || true)"
        log "$package: ĐÃ CÀI (${version})"
    else
        log "$package: CHƯA CÀI hoặc cài đặt chưa hoàn tất"
        missing+=("$package")
    fi
done

echo
if ((${#missing[@]} == 0)); then
    log "Hai gói GTK đã được cài. Vẫn có thể chạy apt update và apt install để đồng bộ/cấu hình gói."
else
    log "Các gói còn thiếu: ${missing[*]}"
fi

echo "Script sẽ chạy apt update và apt install ibus-gtk3 ibus-gtk4."
echo "APT chỉ cài/cập nhật các gói cần thiết; không gỡ gói, không đổi engine,"
echo "không sửa cấu hình người dùng và không chạy autoremove."
echo
read -r -p "Bạn đồng ý chạy apt update và cài các gói còn thiếu? [y/N] " answer
if [[ "${answer,,}" != "y" && "${answer,,}" != "yes" ]]; then
    log "Người dùng đã hủy thao tác."
    exit 0
fi

if ! has_command sudo; then
    echo "Không tìm thấy sudo. Không thể cài gói."
    exit 1
fi

log "Chạy apt-get update..."
sudo apt-get update 2>&1 | tee -a "$LOG_FILE"

log "Cài/đồng bộ các gói IBus GTK..."
sudo apt-get install -y ibus-gtk3 ibus-gtk4 2>&1 | tee -a "$LOG_FILE"

echo
log "Kiểm tra sau cài đặt:"
for package in "${packages[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        log "$package: OK"
    else
        log "$package: CHƯA SẴN SÀNG"
    fi
done

echo
echo "============================================================"
echo "ĐÃ HOÀN TẤT."
echo "1. Đóng hoàn toàn Google Chrome."
echo "2. Khởi động lại máy (khuyến nghị) hoặc đăng xuất/đăng nhập."
echo "3. Mở Chrome và thử gõ tiếng Việt bằng IBus-Bamboo."
echo
echo "Script không tự khởi động lại máy và không thay đổi engine IBus."
echo "Nhật ký: $LOG_FILE"
echo "============================================================"
        log "$package: CHƯA CÀI hoặc cài đặt chưa hoàn tất"
        missing+=("$package")
    fi
done

echo
if ((${#missing[@]} == 0)); then
    log "Hai gói GTK đã được cài. Vẫn có thể chạy apt update và apt install để đồng bộ/cấu hình gói."
else
    log "Các gói còn thiếu: ${missing[*]}"
fi

echo "Script sẽ chạy apt update và apt install ibus-gtk3 ibus-gtk4."
echo "APT chỉ cài/cập nhật các gói cần thiết; không gỡ gói, không đổi engine,"
echo "không sửa cấu hình người dùng và không chạy autoremove."
echo
read -r -p "Bạn đồng ý chạy apt update và cài các gói còn thiếu? [y/N] " answer
if [[ "${answer,,}" != "y" && "${answer,,}" != "yes" ]]; then
    log "Người dùng đã hủy thao tác."
    exit 0
fi

if ! has_command sudo; then
    echo "Không tìm thấy sudo. Không thể cài gói."
    exit 1
fi

log "Chạy apt-get update..."
sudo apt-get update 2>&1 | tee -a "$LOG_FILE"

log "Cài/đồng bộ các gói IBus GTK..."
sudo apt-get install -y ibus-gtk3 ibus-gtk4 2>&1 | tee -a "$LOG_FILE"

echo
log "Kiểm tra sau cài đặt:"
for package in "${packages[@]}"; do
    if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q 'install ok installed'; then
        log "$package: OK"
    else
        log "$package: CHƯA SẴN SÀNG"
    fi
done

echo
echo "============================================================"
echo "ĐÃ HOÀN TẤT."
echo "1. Đóng hoàn toàn Google Chrome."
echo "2. Khởi động lại máy (khuyến nghị) hoặc đăng xuất/đăng nhập."
echo "3. Mở Chrome và thử gõ tiếng Việt bằng IBus-Bamboo."
echo
echo "Script không tự khởi động lại máy và không thay đổi engine IBus."
echo "Nhật ký: $LOG_FILE"
echo "============================================================"
