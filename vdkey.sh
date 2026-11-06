#!/bin/bash
set -e

echo "=== [1/7] XÁC ĐỊNH NGƯỜI DÙNG VÀ MÔI TRƯỜNG HỆ THỐNG ==="
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$ACTUAL_USER")

if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
    ACTUAL_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)
    USER_HOME=$(eval echo "~$ACTUAL_USER")
fi

echo "-> Cài đặt cho User: $ACTUAL_USER"
echo "-> Thư mục Home: $USER_HOME"

echo "=== [2/7] CÀI ĐẶT CÁC GÓI PHỤ THUỘC (DEPENDENCIES) ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
    fcitx5 \
    fcitx5-chinese-addons \
    libfcitx5utils2 \
    libfcitx5config6 \
    libfcitx5core7 \
    librsvg2-bin \
    wget \
    curl 2>/dev/null || true

echo "=== [3/7] TẢI VÀ CÀI ĐẶT GÓI .DEB VDKEY ==="
TEMP_DEB="/tmp/vdkey-latest.deb"
rm -f "$TEMP_DEB"

# 1. Ưu tiên kiểm tra file .deb cục bộ nếu có sẵn
if [ -f "./vdkey-1.0.0-Linux.deb" ]; then
    echo "-> Sử dụng file .deb có sẵn tại thư mục hiện tại..."
    sudo dpkg -i "./vdkey-1.0.0-Linux.deb" || sudo apt-get install -f -y
elif ls vdkey*.deb 1> /dev/null 2>&1; then
    LOCAL_DEB=$(ls vdkey*.deb | head -n 1)
    echo "-> Sử dụng file local: $LOCAL_DEB"
    sudo dpkg -i "$LOCAL_DEB" || sudo apt-get install -f -y
else
    echo "-> Đang tải file .deb từ GitHub..."
    # Lấy link tải từ Release mới nhất qua API
    RELEASE_URL=$(curl -s https://api.github.com/repos/longnguyen2026/vdkey/releases/latest | grep "browser_download_url.*\.deb" | cut -d '"' -f 4 | head -n 1)
    
    if [ -n "$RELEASE_URL" ]; then
        curl -fL "$RELEASE_URL" -o "$TEMP_DEB" || true
    fi

    # Nếu API không có, thử tải link release trực tiếp
    if [ ! -s "$TEMP_DEB" ]; then
        curl -fL "https://github.com/longnguyen2026/vdkey/releases/latest/download/vdkey-1.0.0-Linux.deb" -o "$TEMP_DEB" || true
    fi

    # Nếu vẫn chưa có, thử tải trực tiếp từ repo gotiengviet
    if [ ! -s "$TEMP_DEB" ]; then
        curl -fL "https://raw.githubusercontent.com/longnguyen2026/gotiengviet/main/vdkey-1.0.0-Linux.deb" -o "$TEMP_DEB" || true
    fi

    # Kiểm tra tính toàn vẹn của file tải về trước khi chạy dpkg
    if [ -s "$TEMP_DEB" ]; then
        sudo dpkg -i "$TEMP_DEB" || sudo apt-get install -f -y
    else
        echo "LỖI: Không tìm thấy gói .deb hợp lệ để cài đặt!"
        exit 1
    fi
fi

echo "=== [4/7] CẤU HÌNH INPUTMETHOD VÀ ADDON CHUẨN XÁC ==="
sudo mkdir -p /usr/share/fcitx5/inputmethod /usr/share/fcitx5/addon

sudo tee /usr/share/fcitx5/inputmethod/vdkey.conf > /dev/null << 'EOF'
[InputMethod]
Name=VDKey
Icon=fcitx-vdkey
Label=VD
LangCode=vi
Addon=vdkey
Configurable=True
EOF

sudo tee /usr/share/fcitx5/addon/vdkey.conf > /dev/null << 'EOF'
[Addon]
Name=vdkey
Comment=VDKey Vietnamese Input Method
Category=InputMethod
ConfigGUI=fcitx5-ngosen-settings
Version=1.0.0
Enabled=True
Library=vdkey
Type=SharedLibrary
OnDemand=False
Configurable=True
[Addon/OptionalDependencies]
0=dbus
1=notifications
EOF

# Đảm bảo symlink thư viện cho x86_64
if [ -f "/usr/lib/fcitx5/vdkey.so" ] && [ ! -f "/usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so" ]; then
    sudo mkdir -p /usr/lib/x86_64-linux-gnu/fcitx5
    sudo ln -sf /usr/lib/fcitx5/vdkey.so /usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so
fi

echo "=== [5/7] ĐỒNG BỘ BỘ ICON TRAY (HICOLOR & BREEZE) ==="
sudo mkdir -p /usr/share/icons/hicolor/scalable/status
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo mkdir -p /usr/share/icons/hicolor/22x22/status
sudo mkdir -p /usr/share/icons/hicolor/24x24/status
sudo mkdir -p /usr/share/icons/breeze/status/22
sudo mkdir -p /usr/share/icons/breeze/status/24
sudo mkdir -p /usr/share/icons/breeze-dark/status/22
sudo mkdir -p /usr/share/icons/breeze-dark/status/24

for icon in /usr/share/icons/*/*/apps/*vdkey*.svg /usr/share/icons/*/*/status/*vdkey*.svg; do
    if [ -f "$icon" ]; then
        sudo cp -f "$icon" /usr/share/icons/hicolor/scalable/status/fcitx-vdkey.svg 2>/dev/null || true
        sudo cp -f "$icon" /usr/share/icons/hicolor/scalable/status/vdkey.svg 2>/dev/null || true
        sudo cp -f "$icon" /usr/share/icons/breeze/status/22/fcitx-vdkey.svg 2>/dev/null || true
        sudo cp -f "$icon" /usr/share/icons/breeze/status/24/fcitx-vdkey.svg 2>/dev/null || true
        sudo cp -f "$icon" /usr/share/icons/breeze-dark/status/22/fcitx-vdkey.svg 2>/dev/null || true
        sudo cp -f "$icon" /usr/share/icons/breeze-dark/status/24/fcitx-vdkey.svg 2>/dev/null || true
    fi
done

sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze-dark 2>/dev/null || true

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    kbuildsycoca6 --noincremental 2>/dev/null || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    kbuildsycoca5 --noincremental 2>/dev/null || true
fi

echo "=== [6/7] THIẾT LẬP PROFILE FCITX5 & SỬA QUYỀN SỞ HỮU ==="
USER_FCITX_DIR="$USER_HOME/.config/fcitx5"
mkdir -p "$USER_FCITX_DIR"

cat << 'EOF' > "$USER_FCITX_DIR/profile"
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

chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_FCITX_DIR"

echo "=== [7/7] KHỞI ĐỘNG LẠI TIẾN TRÌNH FCITX5 ==="
killall -9 fcitx5 2>/dev/null || true
sleep 1

if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    sudo -u "$ACTUAL_USER" fcitx5 -d >/dev/null 2>&1 &
else
    fcitx5 -d >/dev/null 2>&1 &
fi

echo "=== HOÀN TẤT CÀI ĐẶT! BIỂU TƯỢNG VD ĐÃ SẴN SÀNG TRÊN KHAY HỆ THỐNG ==="
