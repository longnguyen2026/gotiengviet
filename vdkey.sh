#!/bin/bash
set -e

echo "=== [1/7] XÁC ĐỊNH NGƯỜI DÙNG VÀ MÔI TRƯỜNG HỆ THỐNG ==="
ACTUAL_USER="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$ACTUAL_USER")

if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
    ACTUAL_USER=$(logname 2>/dev/null || who | awk '{print $1}' | head -n 1)
    USER_HOME=$(eval echo "~$ACTUAL_USER")
fi

ACTUAL_UID=$(id -u "$ACTUAL_USER")
echo "-> Cài đặt cho User: $ACTUAL_USER (UID: $ACTUAL_UID)"
echo "-> Thư mục Home: $USER_HOME"

echo "=== [2/7] CÀI ĐẶT CÁC GÓI PHỤ THUỘC (DEPENDENCIES) ==="
sudo apt-get update -qq
sudo apt-get install -y -qq \
    fcitx5 \
    fcitx5-chinese-addons \
    fcitx5-frontend-qt6 \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    libfcitx5qt6dbusaddons1 \
    libfcitx5utils2 \
    libfcitx5config6 \
    libfcitx5core7 \
    librsvg2-bin \
    wget \
    curl 2>/dev/null || true

echo "=== [3/7] TẢI VÀ CÀI ĐẶT GÓI .DEB VDKEY ==="
TEMP_DEB="/tmp/vdkey-latest.deb"
rm -f "$TEMP_DEB"

RELEASE_DEB_URL="https://github.com/longnguyen2026/gotiengviet/releases/download/vdkey/vdkey-1.0.0-Linux.deb"

echo "-> Đang tải gói .deb từ Release GitHub..."
curl -fL "$RELEASE_DEB_URL" -o "$TEMP_DEB" || true

if [ ! -s "$TEMP_DEB" ]; then
    echo "-> Quét file .deb cục bộ trên hệ thống..."
    LOCAL_DEB=$(find "$USER_HOME" "$PWD" -maxdepth 3 -name "vdkey*.deb" 2>/dev/null | head -n 1)
    if [ -n "$LOCAL_DEB" ] && [ -s "$LOCAL_DEB" ]; then
        cp -f "$LOCAL_DEB" "$TEMP_DEB"
    fi
fi

if [ -s "$TEMP_DEB" ]; then
    echo "-> Tiến hành cài đặt gói .deb..."
    sudo dpkg -i --force-overwrite "$TEMP_DEB" || sudo apt-get install -f -y
else
    echo "LỖI: Không tìm thấy gói .deb hợp lệ!"
    exit 1
fi

# Tự động vá lỗi Segmentation Fault (PyQt6 / SIP) trên Python 3.14
MAIN_PY="/usr/share/fcitx5-ngosen/settings-gui/main.py"
if [ -f "$MAIN_PY" ]; then
    sudo sed -i 's/sys.exit(code)/import os; os._exit(code if code is not None else 0)/g' "$MAIN_PY"
fi

echo "=== [4/7] CẤU HÌNH INPUTMETHOD CHUẨN XÁC ==="
sudo mkdir -p /usr/share/fcitx5/inputmethod /usr/share/fcitx5/addon

# Ghi đúng Name=vdkey thường và không có Label để hệ thống gọi trực tiếp icon
sudo tee /usr/share/fcitx5/inputmethod/vdkey.conf > /dev/null << 'EOF'
[InputMethod]
Name=vdkey
Icon=fcitx-vdkey
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

# Đảm bảo symlink thư viện cho multiarch x86_64
if [ -f "/usr/lib/fcitx5/vdkey.so" ] && [ ! -f "/usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so" ]; then
    sudo mkdir -p /usr/lib/x86_64-linux-gnu/fcitx5
    sudo ln -sf /usr/lib/fcitx5/vdkey.so /usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so
fi

echo "=== [5/7] ĐỒNG BỘ TOÀN BỘ CÂY ICON VÀO THEME HỆ THỐNG ==="
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo mkdir -p /usr/share/icons/hicolor/scalable/status
sudo mkdir -p /usr/share/icons/hicolor/22x22/status
sudo mkdir -p /usr/share/icons/hicolor/24x24/status
sudo mkdir -p /usr/share/icons/breeze/status/{22,24}
sudo mkdir -p /usr/share/icons/breeze-dark/status/{22,24}
sudo mkdir -p /usr/share/icons/breeze/apps/22
sudo mkdir -p /usr/share/icons/breeze-dark/apps/22

SRC_SVG=$(find /usr/share/icons -name "*vdkey*.svg" 2>/dev/null | head -n 1)

if [ -z "$SRC_SVG" ] || [ ! -f "$SRC_SVG" ]; then
    SRC_SVG="/usr/share/icons/hicolor/scalable/apps/fcitx-vdkey.svg"
    sudo curl -sSL "https://raw.githubusercontent.com/longnguyen2026/gotiengviet/main/data/icons/fcitx-vdkey.svg" -o "$SRC_SVG" 2>/dev/null || true
fi

if [ -f "$SRC_SVG" ]; then
    NAMES=(
        "vdkey"
        "org.fcitx.Fcitx5.vdkey"
        "fcitx-vdkey"
        "fcitx-vdkey-off"
        "fcitx-vdkey-default"
        "fcitx-vdkey-default-black"
        "fcitx-vdkey-off-default"
        "fcitx-vdkey-off-default-black"
        "fcitx-vdkey-vi"
        "fcitx-vdkey-active"
        "fcitx-vdkey-telex"
        "fcitx-vdkey-vni"
        "org.fcitx.Fcitx5.fcitx-vdkey"
        "org.fcitx.Fcitx5.fcitx-vdkey-off"
        "input-method-vdkey"
        "io.github.vdkey.NgoSen.Settings"
    )

    for NAME in "${NAMES[@]}"; do
        # 1. Thư mục apps (phục vụ menu popup KDE Plasma & Fcitx config)
        sudo cp -f "$SRC_SVG" "/usr/share/icons/hicolor/scalable/apps/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/apps/22/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/apps/22/${NAME}.svg" 2>/dev/null || true

        # 2. Thư mục status (phục vụ khay hệ thống StatusNotifierItem)
        sudo cp -f "$SRC_SVG" "/usr/share/icons/hicolor/scalable/status/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/status/22/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/status/24/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/status/22/${NAME}.svg" 2>/dev/null || true
        sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/status/24/${NAME}.svg" 2>/dev/null || true

        # 3. Render PNG cho status fallback
        if command -v rsvg-convert >/dev/null 2>&1; then
            sudo rsvg-convert -w 22 -h 22 "$SRC_SVG" -o "/usr/share/icons/hicolor/22x22/status/${NAME}.png" 2>/dev/null || true
            sudo rsvg-convert -w 24 -h 24 "$SRC_SVG" -o "/usr/share/icons/hicolor/24x24/status/${NAME}.png" 2>/dev/null || true
        fi
    done
fi

# Cập nhật cache theme hệ thống
sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze-dark 2>/dev/null || true

# Xóa cache icon Plasma cũ của người dùng
rm -rf "$USER_HOME/.cache/icon-cache.kcache" "$USER_HOME/.cache/plasma*" 2>/dev/null || true

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    sudo -u "$ACTUAL_USER" kbuildsycoca6 --noincremental 2>/dev/null || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    sudo -u "$ACTUAL_USER" kbuildsycoca5 --noincremental 2>/dev/null || true
fi

echo "=== [6/7] THIẾT LẬP PROFILE FCITX5 USER ==="
USER_FCITX_DIR="$USER_HOME/.config/fcitx5"
mkdir -p "$USER_FCITX_DIR/addon" "$USER_FCITX_DIR/conf"

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

# Bật addon StatusNotifierItem cho khay hệ thống
cat << 'EOF' > "$USER_FCITX_DIR/addon/notificationitem.conf"
[Addon]
Name=notificationitem
Enabled=True
EOF

# Kích hoạt bộ icon trạng thái gốc của engine
cat << 'EOF' > "$USER_FCITX_DIR/conf/vdkey.conf"
UseLotusIcons=True
IconTheme=Auto
EOF

chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_FCITX_DIR"

echo "=== [7/7] KHỞI ĐỘNG LẠI TIẾN TRÌNH FCITX5 VÀ RELOAD GIAO DIỆN ==="
pkill -9 -f fcitx5 2>/dev/null || true
sleep 1
rm -rf "/run/user/$ACTUAL_UID/fcitx5"* "/tmp/fcitx5"* 2>/dev/null || true

if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" fcitx5 -d >/dev/null 2>&1 &
    
    # Reload plasmashell nếu đang ở phiên Plasma để nhận icon menu ngay
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" kquitapp6 plasmashell 2>/dev/null || true
        sleep 1
        sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" kstart plasmashell >/dev/null 2>&1 &
    fi
else
    fcitx5 -d >/dev/null 2>&1 &
fi

echo "=== HOÀN TẤT CÀI ĐẶT! BIỂU TƯỢNG VD ĐÃ SẴN SÀNG TRÊN KHAY HỆ THỐNG & MENU ==="
