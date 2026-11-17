#!/usr/bin/env bash
# ==============================================================================
# Script: fviewer.sh (install-fviewer.sh)
# Mô tả: Tự động tải và cài đặt FViewer (.deb) cho Linux Mint và Kubuntu
#        Hạn chế cài đặt trên Linux Mint đối với tài khoản 'nhanvien'
# Tác giả: longnguyen2026
# ==============================================================================

set -euo pipefail

# URL tải file .deb (Mặc định lấy từ GitHub Releases, có thể ghi đè bằng biến môi trường)
FVIEWER_URL="${FVIEWER_URL:-https://github.com/longnguyen2026/fviewer/releases/latest/download/fviewer_0.1.1_amd64.deb}"
TEMP_DEB="/tmp/fviewer_latest_amd64.deb"

# Màu hiển thị terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# ==============================================================================
# 0. Kiểm tra điều kiện Hệ điều hành & Truy vết User gốc (Chặn cả su / sudo)
# ==============================================================================
DISTRO_ID=""
if [ -f /etc/os-release ]; then
    DISTRO_ID=$(grep -E '^ID=' /etc/os-release | cut -d'=' -f2 | tr -d '"' | tr '[:upper:]' '[:lower:]')
fi

if [ "$DISTRO_ID" = "linuxmint" ]; then
    # 1. Lấy user từ phiên đăng nhập gốc của terminal (không bị thay đổi bởi su/sudo)
    LOGIN_USER="$(logname 2>/dev/null || true)"

    # 2. Lấy user đang giữ quyền sudo trước đó (nếu có)
    PREV_SUDO_USER="${SUDO_USER:-}"

    # 3. Lấy danh sách user đang có phiên đăng nhập hoạt động (kể cả phiên desktop nền)
    ACTIVE_SESSIONS="$(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $3}' | tr '\n' ' ')"

    # Chặn nếu phát hiện bất kỳ dấu vết nào của 'nhanvien' trên Linux Mint
    if [ "$LOGIN_USER" = "nhanvien" ] \
       || [ "$PREV_SUDO_USER" = "nhanvien" ] \
       || [ "$(whoami)" = "nhanvien" ] \
       || [[ " $ACTIVE_SESSIONS " == *" nhanvien "* ]]; then
        log_error "Từ chối cài đặt: Tài khoản 'nhanvien' không được phép cài đặt FViewer trên Linux Mint."
        log_info "Hệ thống phát hiện phiên làm việc gốc thuộc 'nhanvien' (kể cả khi chuyển qua 'su it' hoặc 'sudo')."
        log_info "Vui lòng đăng xuất (Log Out) hoàn toàn khỏi 'nhanvien' và đăng nhập trực tiếp bằng tài khoản 'it'."
        exit 1
    fi
fi

# ==============================================================================
# 1. Kiểm tra quyền thực thi (root hoặc sudo)
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
else
    SUDO=""
fi

log_info "Bắt đầu quá trình triển khai FViewer cho hệ thống..."

# ==============================================================================
# 2. Đảm bảo có curl hoặc wget
# ==============================================================================
if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
    log_info "Đang cài đặt curl..."
    $SUDO apt-get update -y
    $SUDO apt-get install -y curl
fi

# ==============================================================================
# 3. Tải gói fviewer .deb
# ==============================================================================
log_info "Đang tải FViewer từ: ${FVIEWER_URL}"
if command -v curl &>/dev/null; then
    curl -fL --progress-bar "${FVIEWER_URL}" -o "${TEMP_DEB}"
else
    wget --show-progress -qO "${TEMP_DEB}" "${FVIEWER_URL}"
fi

if [ ! -s "${TEMP_DEB}" ]; then
    log_error "File tải về rỗng hoặc liên kết không khả dụng!"
    exit 1
fi

# ==============================================================================
# 4. Xử lý PPA không tương thích và cập nhật danh sách gói APT
# ==============================================================================
# Chỉ vô hiệu hóa PPA rodsmith/refind nếu nó đang được cấu hình.
# Không gỡ rEFInd đã cài và không đụng đến các repository khác.
REFIND_PPA="ppa:rodsmith/refind"
REFIND_PATTERN="ppa.launchpadcontent.net/rodsmith/refind"

if grep -Rqs "$REFIND_PATTERN" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    log_info "Phát hiện PPA rodsmith/refind. Đang vô hiệu hóa nguồn PPA không tương thích..."

    REFIND_REMOVED=false

    if command -v add-apt-repository >/dev/null 2>&1; then
        if $SUDO add-apt-repository -y --remove "$REFIND_PPA"; then
            REFIND_REMOVED=true
        fi
    fi

    # Dự phòng: vô hiệu hóa đúng nguồn PPA nếu add-apt-repository không xử lý được.
    # Dùng python3 -c với dấu nháy đơn bên ngoài để tránh lỗi quote của Bash.
    if [ "$REFIND_REMOVED" != true ]; then
        for SOURCE_FILE in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
            [ -f "$SOURCE_FILE" ] || continue
            $SUDO python3 -c '
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
pattern = sys.argv[2]
content = path.read_text()

if path.suffix == ".list":
    output = []
    for line in content.splitlines():
        if pattern in line and not line.lstrip().startswith("#"):
            line = "# disabled by FViewer installer: " + line
        output.append(line)
    result = "\n".join(output)
    if content.endswith("\n"):
        result += "\n"
else:
    blocks = re.split(r"(?m)(?=^\S)", content)
    for index, block in enumerate(blocks):
        if pattern in block and not re.search(r"(?mi)^Enabled:\s*no\s*$", block):
            block = block.rstrip() + "\nEnabled: no\n"
        blocks[index] = block
    result = "".join(blocks)

path.write_text(result)
' "$SOURCE_FILE" "$REFIND_PATTERN"
        done
    fi

    if grep -Rqs "$REFIND_PATTERN" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
        log_error "Không thể tự động vô hiệu hóa PPA rodsmith/refind. Tiếp tục cập nhật APT và sẽ báo nếu còn lỗi."
    else
        log_success "Đã vô hiệu hóa PPA rodsmith/refind không tương thích."
    fi
fi

log_info "Đang cập nhật danh sách gói APT..."
if ! $SUDO apt-get update -y; then
    log_error "apt-get update còn lỗi ở repository khác. Tiếp tục thử cài FViewer..."
fi

log_info "Đang cài đặt FViewer vào hệ thống..."

# Cài trực tiếp file .deb bằng APT để APT tự xử lý dependencies.
if ! $SUDO apt-get install -y "${TEMP_DEB}"; then
    log_error "Cài bằng APT chưa thành công. Thử cài package và sửa dependencies..."

    # dpkg có thể báo thiếu dependencies; đây là bước trung gian có chủ đích.
    $SUDO dpkg -i "${TEMP_DEB}" || true

    if ! $SUDO apt-get install -f -y; then
        log_error "Không thể tự động khắc phục dependencies."
        log_error "Giữ lại file cài đặt tại: ${TEMP_DEB}"
        exit 1
    fi
fi

# Xác nhận package đã được cài ở trạng thái đã giải nén và cấu hình.
if ! dpkg-query -W -f='${Status}' fviewer 2>/dev/null | grep -q "install ok installed"; then
    log_error "Không tìm thấy package fviewer ở trạng thái đã cài đặt."
    log_error "Giữ lại file cài đặt tại: ${TEMP_DEB}"
    exit 1
fi

# ==============================================================================
# 5. Cập nhật cache ứng dụng desktop cho Mint (Cinnamon/MATE/XFCE) và Kubuntu (KDE)
# ==============================================================================
log_info "Làm mới cơ sở dữ liệu desktop entry và mime..."
if command -v update-desktop-database &>/dev/null; then
    $SUDO update-desktop-database -q || true
fi

# ==============================================================================
# 6. Dọn dẹp file tạm
# ==============================================================================
rm -f "${TEMP_DEB}"

log_success "FViewer đã được cài đặt thành công trên hệ thống!"
