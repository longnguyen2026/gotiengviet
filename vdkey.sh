#!/usr/bin/env bash
# ==============================================================================
# Script cài đặt & tự động cấu hình VDKey trên Ubuntu / Debian / Linux Mint
# Tích hợp kiểm tra xung đột và gỡ bỏ bộ gõ cũ
# ==============================================================================
set -e

GITHUB_USER="longnguyen2026"
GITHUB_REPO="vdkey"
DEB_NAME="vdkey-1.0.0-Linux.deb"

# Kiểm tra quyền sudo
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

echo "=================================================================="
echo "          TRÌNH CÀI ĐẶT BỘ GÕ TIẾNG VIỆT VDKEY CHO LINUX          "
echo "=================================================================="

# --- BƯỚC 1: KIỂM TRA BỘ GÕ & FRAMEWORK KHÁC TRÊN HỆ THỐNG ---
echo ">> Đang kiểm tra các bộ gõ tiếng Việt khác trên máy..."

CONFLICT_PACKAGES=()
INSTALLED_DESC=()

# Danh sách các gói bộ gõ thường gặp cần quét
CANDIDATES=(
    "ibus"
    "ibus-bamboo"
    "ibus-unikey"
    "ibus-table-vi"
    "fcitx"
    "fcitx-unikey"
    "fcitx-bamboo"
    "fcitx-table-vi"
    "fcitx5-unikey"
    "fcitx5-bamboo"
    "fcitx5-funput"
    "funput"
    "fcitx5-bogo"
    "openkey"
)

for pkg in "${CANDIDATES[@]}"; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
        CONFLICT_PACKAGES+=("$pkg")
        INSTALLED_DESC+=(" - Gói hệ thống: $pkg")
    fi
done

# Kiểm tra thêm các file rác của Funput/Bamboo cài tay không qua dpkg
MANUAL_FILES=()
for path in /usr/share/fcitx5/addon/*funput*.conf /usr/share/fcitx5/inputmethod/*funput*.conf /usr/lib/*/fcitx5/*funput*.so; do
    if [ -f "$path" ]; then
        MANUAL_FILES+=("$path")
    fi
done

if [ ${#MANUAL_FILES[@]} -gt 0 ]; then
    INSTALLED_DESC+=(" - File cài tay addon: Funput (${#MANUAL_FILES[@]} files)")
fi

# --- XỬ LÝ LỰA CHỌN NẾU PHÁT HIỆN BỘ GÕ KHÁC ---
REMOVE_OLD=false

if [ ${#CONFLICT_PACKAGES[@]} -gt 0 ] \vert{}\vert{} [ ${#MANUAL_FILES[@]} -gt 0 ]; then
    echo ""
    echo "⚠️  PHÁT HIỆN CÁC BỘ GÕ TIẾNG VIỆT KHÁC ĐANG CÓ TRÊN MÁY:"
    for item in "${INSTALLED_DESC[@]}"; do
        echo "$item"
    done
    echo ""
    echo "Việc để nhiều bộ gõ chạy song song dễ gây lỗi nhảy chữ, đơ phím hoặc xung đột khay hệ thống."
    echo "------------------------------------------------------------------"
    echo "  [1] GỠ BỎ các bộ gõ cũ/xung đột và CÀI ĐẶT VDKey (Khuyên dùng)"
    echo "  [2] GIỮ NGUYÊN bộ gõ cũ và tiếp tục CÀI ĐẶT VDKey"
    echo "  [0] HỦY BỎ cài đặt"
    echo "------------------------------------------------------------------"
    
    CHOICE=""
    while true; do
        if [ -c /dev/tty ]; then
            read -r -p "Nhập lựa chọn của bạn [1/2/0]: " CHOICE < /dev/tty
        else
            read -r -p "Nhập lựa chọn của bạn [1/2/0]: " CHOICE
        fi

        case "$CHOICE" in
            1)
                REMOVE_OLD=true
                echo ">> Đã chọn: Gỡ bộ gõ cũ và cài đặt VDKey."
                break
                ;;
            2)
                REMOVE_OLD=false
                echo ">> Đã chọn: Giữ nguyên bộ gõ cũ và cài đặt VDKey."
                break
                ;;
            0)
                echo ">> Đã hủy tiến trình cài đặt."
                exit 0
                ;;
            *)
                echo "Lựa chọn không hợp lệ, vui lòng bấm 1, 2 hoặc 0."
                ;;
        esac
    done
else
    echo ">> Không phát hiện bộ gõ nào khác xung đột. Tiếp tục cài đặt."
fi

# --- BƯỚC 2: THỰC HIỆN GỠ NẾU CHỌN 1 ---
if [ "$REMOVE_OLD" = true ]; then
    echo ""
    echo "=== Đang gỡ bỏ các bộ gõ xung đột ==="
    
    # Dừng tạm thời Ibus và Fcitx cũ
    killall -9 ibus-daemon 2>/dev/null || true
    killall -9 fcitx 2>/dev/null || true

    if [ ${#CONFLICT_PACKAGES[@]} -gt 0 ]; then
        echo "Đang gỡ: ${CONFLICT_PACKAGES[*]} ..."
        $SUDO apt-get purge -y "${CONFLICT_PACKAGES[@]}" 2>/dev/null || true
        $SUDO apt-get autoremove -y 2>/dev/null || true
    fi

    # Dọn dẹp file cấu hình sót lại của funput/bamboo thủ công
    $SUDO rm -f /usr/share/fcitx5/addon/*funput*.conf 2>/dev/null || true
    $SUDO rm -f /usr/share/fcitx5/inputmethod/*funput*.conf 2>/dev/null \vert{}\vert{} true$SUDO rm -f /usr/lib/*/fcitx5/*funput*.so 2>/dev/null || true
