#!/usr/bin/env bash
# ==============================================================================
# Script cài đặt & tự động cấu hình VDKey trên Ubuntu / Debian / Linux Mint
# ==============================================================================
set -e

# Cấu hình thông tin repo GitHub (chỉnh sửa user/repo của bạn tại đây)
GITHUB_USER="longnguyen2026"
GITHUB_REPO="vdkey"
DEB_NAME="vdkey-1.0.0-Linux.deb"

echo "=== [1/6] Kiểm tra quyền hạn và cập nhật hệ thống ==="
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

$SUDO apt-get update -y

echo "=== [2/6] Cài đặt Fcitx5 và các module Frontend cần thiết ==="
# Cài đặt Fcitx5 core và frontend cho GTK/Qt để Chrome/LibreOffice nhận diện
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

echo "=== [3/6] Tải gói .deb từ GitHub Release ==="
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DEB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/latest/download/${DEB_NAME}"

echo "Đang tải $DEB_URL ..."
curl -sL "$DEB_URL" -o "$TMP_DIR/$DEB_NAME"

echo "=== [4/6] Cài đặt gói VDKey ==="
$SUDO dpkg -i "$TMP_DIR/$DEB_NAME" || $SUDO apt-get install -f -y

# Cập nhật cache biểu tượng hệ thống
$SUDO gtk-update-icon-cache -f -t /usr/share/icons/hicolor 2>/dev/null || true

echo "=== [5/6] Thiết lập biến môi trường gõ tiếng Việt ==="
# Cấu hình biến môi trường toàn hệ thống cho X11, Wayland, Chrome, Office
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

echo "=== [6/6] Cấu hình khởi động cùng hệ thống và Profile mặc định ==="
CURRENT_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$CURRENT_USER")

# 1. Thêm Fcitx5 vào Startup (Autostart)
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

# 2. Cấu hình Profile mặc định: Tiếng Anh (keyboard-us) + VDKey
mkdir -p "$USER_HOME/.config/fcitx5"
cat << 'EOF' > "$USER_HOME/.config/fcitx5/profile"
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=vdkey

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=vdkey
Layout=

[GroupOrder]
0=Default
EOF

# Đảm bảo quyền sở hữu file cho user
chown -R "$CURRENT_USER:$CURRENT_USER" "$USER_HOME/.config/autostart" "$USER_HOME/.config/fcitx5"

# 3. Áp dụng ngay cho session hiện tại
killall -9 fcitx5 2>/dev/null || true
pkill -9 -f fcitx5 2>/dev/null || true
sleep 1
fcitx5 -d &
sleep 1
fcitx5-remote -s vdkey 2>/dev/null || true
fcitx5-remote -o 2>/dev/null || true

echo ""
echo "=================================================================="
echo ">> CÀI ĐẶT THÀNH CÔNG VDKEY VÀ THIẾT LẬP AUTOSTART!"
echo ">> Bộ gõ VDKey đã được kích hoạt."
echo ">> Nếu app đang mở chưa nhận dấu ngay, vui lòng đăng xuất hoặc khởi động lại máy."
echo "=================================================================="
