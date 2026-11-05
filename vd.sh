#!/usr/bin/env bash
# ==============================================================================
# Script cài đặt & tự động cấu hình VDKey trên Ubuntu / Debian / Linux Mint
# Tích hợp kiểm tra xung đột và gỡ bỏ bộ gõ cũ
# ==============================================================================
set -e

GITHUB_USER="longnguyen2026"
GITHUB_REPO="gotiengviet"
TAG_NAME="vdkey"
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

# Kiểm tra an toàn các file cài tay của Funput/Bamboo
MANUAL_FILES=()
shopt -s nullglob
for path in /usr/share/fcitx5/addon/*funput*.conf /usr/share/fcitx5/inputmethod/*funput*.conf /usr/lib/*/fcitx5/*funput*.so; do
    if [ -f "$path" ]; then
        MANUAL_FILES+=("$path")
    fi
done
shopt -u nullglob

if [ "${#MANUAL_FILES[@]}" -gt 0 ]; then
    INSTALLED_DESC+=(" - File cài tay addon: Funput (${#MANUAL_FILES[@]} files)")
fi

# --- XỬ LÝ LỰA CHỌN NẾU PHÁT HIỆN BỘ GÕ KHÁC ---
REMOVE_OLD=false

if [ "${#CONFLICT_PACKAGES[@]}" -gt 0 ] || [ "${#MANUAL_FILES[@]}" -gt 0 ]; then
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
    
    killall -9 ibus-daemon 2>/dev/null || true
    killall -9 fcitx 2>/dev/null || true

    if [ "${#CONFLICT_PACKAGES[@]}" -gt 0 ]; then
        echo "Đang gỡ: ${CONFLICT_PACKAGES[*]} ..."
        $SUDO apt-get purge -y "${CONFLICT_PACKAGES[@]}" 2>/dev/null || true
        $SUDO apt-get autoremove -y 2>/dev/null || true
    fi

    # Dọn dẹp file cấu hình thủ công
    $SUDO rm -f /usr/share/fcitx5/addon/*funput*.conf 2>/dev/null || true
    $SUDO rm -f /usr/share/fcitx5/inputmethod/*funput*.conf 2>/dev/null || true
    $SUDO rm -f /usr/lib/*/fcitx5/*funput*.so 2>/dev/null || true
    $SUDO rm -rf /usr/share/funput ~/.config/fcitx5/conf/*funput* 2>/dev/null || true
    
    echo ">> Đã gỡ bỏ sạch sẽ các thành phần cũ."
fi

# --- BƯỚC 3: CÀI ĐẶT FCITX5 VÀ DEPENDENCIES ---
echo ""
echo "=== [1/5] Cập nhật danh sách gói và cài đặt dependencies ==="
$SUDO apt-get update -y || true

$SUDO apt-get install -y \
    curl \
    fcitx5 \
    fcitx5-frontend-gtk2 \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    fcitx5-frontend-qt5 \
    fcitx5-module-dbus \
    fcitx5-module-emoji \
    python3-pil

# --- BƯỚC 4: TẢI & CÀI ĐẶT GÓI VDKEY ---
echo ""
echo "=== [2/5] Tải gói .deb từ GitHub Release ==="
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DEB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${TAG_NAME}/${DEB_NAME}"
echo "Đang tải $DEB_URL ..."

# Tải với cờ -fL để bắt lỗi HTTP lập tức
if ! curl -fL "$DEB_URL" -o "$TMP_DIR/$DEB_NAME"; then
    echo "❌ Lỗi: Không thể tải file .deb từ Release. Vui lòng kiểm tra lại file đính kèm trên GitHub!"
    exit 1
fi

# Kiểm tra file deb có toàn vẹn không
if ! dpkg-deb -I "$TMP_DIR/$DEB_NAME" >/dev/null 2>&1; then
    echo "❌ Lỗi: File .deb tải về không hợp lệ hoặc bị hỏng!"
    exit 1
fi

echo ""
echo "=== [3/5] Cài đặt gói VDKey ==="
$SUDO dpkg -i "$TMP_DIR/$DEB_NAME" || $SUDO apt-get install -f -y
$SUDO gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

# --- BƯỚC 5: CẤU HÌNH BIẾN MÔI TRƯỜNG TOÀN HỆ THỐNG ---
echo ""
echo "=== [4/5] Thiết lập biến môi trường gõ tiếng Việt ==="
$SUDO tee /etc/environment.d/99-fcitx5.conf > /dev/null << 'EOF'
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
EOF

$SUDO tee /etc/profile.d/fcitx5.sh > /dev/null << 'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export INPUT_METHOD=fcitx
EOF
$SUDO chmod +x /etc/profile.d/fcitx5.sh

# --- BƯỚC 6: CẤU HÌNH KHỞI ĐỘNG VÀ PROFILE MẶC ĐỊNH ---
echo ""
echo "=== [5/5] Cấu hình Autostart và Profile mặc định ==="
CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$CURRENT_USER")

# 1. Autostart
mkdir -p "$USER_HOME/.config/autostart"
cat << 'EOF' > "$USER_HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
[Desktop Entry]
Name=Fcitx 5
GenericName=Input Method
Comment=Start Input Method
Exec=fcitx5
Icon=fcitx-vdkey
Terminal=false
Type=Application
Categories=System;Utility;
StartupNotify=false
X-GNOME-Autostart-Phase=Applications
X-KDE-autostart-phase=1
EOF

# 2. Profile (gán Layout=us cho cả vdkey và keyboard-us để giữ trạng thái trên Desktop)
mkdir -p "$USER_HOME/.config/fcitx5"
cat << 'EOF' > "$USER_HOME/.config/fcitx5/profile"
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=vdkey

[Groups/0/Items/0]
Name=vdkey
Layout=us

[Groups/0/Items/1]
Name=keyboard-us
Layout=us

[GroupOrder]
0=Default
EOF

# 3. Giữ trạng thái bộ gõ toàn hệ thống
cat << 'EOF' > "$USER_HOME/.config/fcitx5/config"
[GlobalOptions]
ShareInputState=All
ResetInputMethodOnFocusIn=No
EOF

chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/autostart" "$USER_HOME/.config/fcitx5"

# 4. Làm mới tiến trình Fcitx5 (tắt triệt để để giải phóng DBus)
killall -9 fcitx5 2>/dev/null || true
pkill -9 -f fcitx5 2>/dev/null || true
sleep 2
fcitx5 -d --replace &>/dev/null &
sleep 1
fcitx5-remote -s vdkey 2>/dev/null || true
fcitx5-remote -o 2>/dev/null || true

echo ""
echo "=================================================================="
echo ">> CÀI ĐẶT HOÀN TẤT VDKEY!"
echo ">> Biểu tượng VDKey đã hiển thị trên khay hệ thống."
echo ">> Nếu ứng dụng đang mở chưa gõ được ngay, vui lòng đăng xuất hoặc khởi động lại máy."
echo "=================================================================="
