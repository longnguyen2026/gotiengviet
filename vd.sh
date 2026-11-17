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
    fcitx5-frontend-qt5 \
    fcitx5-frontend-qt6 \
    fcitx5-module-xorg \
    fcitx5-frontend-gtk3 \
    fcitx5-frontend-gtk4 \
    libfcitx5qt6dbusaddons1 \
    libfcitx5utils2 \
    libfcitx5config6 \
    libfcitx5core7 \
    librsvg2-bin \
    imagemagick \
    wget \
    curl 2>/dev/null || true

echo "=== [3/7] TẢI VÀ CÀI ĐẶT GÓI .DEB VDKEY ==="
TEMP_DEB="/tmp/vdkey-latest.deb"
rm -f "$TEMP_DEB"

RELEASE_DEB_URL="https://github.com/longnguyen2026/gotiengviet/releases/download/vdkey/vdkey-2.0.0-Linux.deb"

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
    sudo python3 -c '
p = "/usr/share/fcitx5-ngosen/settings-gui/main.py"
with open(p, "r", encoding="utf-8") as f: c = f.read()
if "import os" not in c: c = "import os\n" + c
c = c.replace("sys.exit(app.exec())", "code = app.exec()\nos._exit(code if code is not None else 0)")
c = c.replace("sys.exit(code)", "os._exit(code if code is not None else 0)")
c = c.replace("sys.exit(0)", "os._exit(0)")
with open(p, "w", encoding="utf-8") as f: f.write(c)
'
fi

echo "=== [4/7] CẤU HÌNH INPUTMETHOD CHUẨN XÁC ==="
sudo mkdir -p /usr/share/fcitx5/inputmethod /usr/share/fcitx5/addon

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
Version=2.0.0
Enabled=True
Library=vdkey
Type=SharedLibrary
OnDemand=False
Configurable=True
[Addon/OptionalDependencies]
0=dbus
1=notifications
EOF

# Xóa addon migration cũ nếu còn
sudo rm -f /usr/share/fcitx5/addon/ngosenmigrate.conf

# Đảm bảo symlink thư viện cho multiarch x86_64
if [ -f "/usr/lib/fcitx5/vdkey.so" ] && [ ! -f "/usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so" ]; then
    sudo mkdir -p /usr/lib/x86_64-linux-gnu/fcitx5
    sudo ln -sf /usr/lib/fcitx5/vdkey.so /usr/lib/x86_64-linux-gnu/fcitx5/vdkey.so
fi

echo "=== [5/7] ĐỒNG BỘ ICON VD MÀU XANH DƯƠNG VÀO TOÀN BỘ HỆ THỐNG ==="
sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
sudo mkdir -p /usr/share/icons/hicolor/scalable/status
sudo mkdir -p /usr/share/icons/hicolor/16x16/status
sudo mkdir -p /usr/share/icons/hicolor/22x22/status
sudo mkdir -p /usr/share/icons/hicolor/24x24/status
sudo mkdir -p /usr/share/icons/hicolor/32x32/status
sudo mkdir -p /usr/share/icons/hicolor/48x48/status
sudo mkdir -p /usr/share/icons/breeze/status/{22,24}
sudo mkdir -p /usr/share/icons/breeze-dark/status/{22,24}
sudo mkdir -p /usr/share/icons/breeze/apps/22
sudo mkdir -p /usr/share/icons/breeze-dark/apps/22

SRC_SVG="/usr/share/icons/hicolor/scalable/apps/fcitx-vdkey.svg"

# Tạo trực tiếp file SVG icon VD màu xanh dương chuẩn (không bị KDE ép đơn sắc)
sudo tee "$SRC_SVG" > /dev/null << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="vdBlue" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1E88E5"/>
      <stop offset="100%" stop-color="#0D47A1"/>
    </linearGradient>
  </defs>
  <rect x="4" y="4" width="56" height="56" rx="14" fill="url(#vdBlue)"/>
  <text x="32" y="42" font-family="sans-serif" font-weight="bold" font-size="26" fill="#FFFFFF" text-anchor="middle" letter-spacing="1">VD</text>
</svg>
EOF

NAMES=(
    "vdkey"
    "org.fcitx.Fcitx5.vdkey"
    "fcitx-vdkey"
    "fcitx-vdkey-off"
    "fcitx-vdkey-default"
    "fcitx-vdkey-default-black"
    "fcitx-vdkey-default-white"
    "fcitx-vdkey-off-default"
    "fcitx-vdkey-off-default-black"
    "fcitx-vdkey-off-default-white"
    "fcitx-vdkey-vi"
    "fcitx-vdkey-active"
    "fcitx-vdkey-telex"
    "fcitx-vdkey-vni"
    "org.fcitx.Fcitx5.fcitx-vdkey"
    "org.fcitx.Fcitx5.fcitx-vdkey-off"
    "input-method-vdkey"
    "io.github.vdkey.NgoSen.Settings"
    "io.github.ngosen.NgoSen.Settings"
)

for NAME in "${NAMES[@]}"; do
    [ "$NAME" != "fcitx-vdkey" ] && sudo cp -f "$SRC_SVG" "/usr/share/icons/hicolor/scalable/apps/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/apps/22/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/apps/22/${NAME}.svg" 2>/dev/null || true

    sudo cp -f "$SRC_SVG" "/usr/share/icons/hicolor/scalable/status/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/status/22/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze/status/24/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/status/22/${NAME}.svg" 2>/dev/null || true
    sudo cp -f "$SRC_SVG" "/usr/share/icons/breeze-dark/status/24/${NAME}.svg" 2>/dev/null || true

    if command -v rsvg-convert >/dev/null 2>&1; then
        for SZ in 16 22 24 32 48; do
            sudo rsvg-convert -w "$SZ" -h "$SZ" "$SRC_SVG" -o "/usr/share/icons/hicolor/${SZ}x${SZ}/status/${NAME}.png" 2>/dev/null || true
        done
    fi
done

# Ghi đè toàn bộ các file icon SVG/PNG còn sót trong /usr/share (bao gồm /usr/share/fcitx5-ngosen)
sudo find /usr/share -type f \( -iname "*vdkey*.svg" -o -iname "*ngosen*.svg" \) ! -samefile "$SRC_SVG" -exec cp -f "$SRC_SVG" {} \; 2>/dev/null || true
if command -v rsvg-convert >/dev/null 2>&1; then
    sudo find /usr/share -type f \( -iname "*vdkey*.png" -o -iname "*ngosen*.png" \) -exec sh -c '
        SIZE=$(identify -format "%w" "$1" 2>/dev/null || echo 24)
        rsvg-convert -w "$SIZE" -h "$SIZE" "'"$SRC_SVG"'" -o "$1"
    ' _ {} \; 2>/dev/null || true
fi

sudo gtk-update-icon-cache -f -q /usr/share/icons/hicolor 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze 2>/dev/null || true
sudo gtk-update-icon-cache -f -q /usr/share/icons/breeze-dark 2>/dev/null || true

rm -rf "$USER_HOME/.cache/icon-cache.kcache" "$USER_HOME/.cache/plasma*" 2>/dev/null || true

if command -v kbuildsycoca6 >/dev/null 2>&1; then
    sudo -u "$ACTUAL_USER" kbuildsycoca6 --noincremental 2>/dev/null || true
elif command -v kbuildsycoca5 >/dev/null 2>&1; then
    sudo -u "$ACTUAL_USER" kbuildsycoca5 --noincremental 2>/dev/null || true
fi

echo "=== [6/7] THIẾT LẬP PROFILE FCITX5 & KHÓA TRẠNG THÁI TOÀN HỆ THỐNG ==="
USER_FCITX_DIR="$USER_HOME/.config/fcitx5"
mkdir -p "$USER_FCITX_DIR/addon" "$USER_FCITX_DIR/conf"

# 1. Giữ nguyên trạng thái bộ gõ toàn cục (không tự nhảy về tiếng Anh khi chuyển app/Desktop)
touch "$USER_FCITX_DIR/config"
if grep -q "^ShareInputState=" "$USER_FCITX_DIR/config"; then
    sed -i 's/^ShareInputState=.*/ShareInputState=All/' "$USER_FCITX_DIR/config"
else
    echo "ShareInputState=All" >> "$USER_FCITX_DIR/config"
fi

# 2. Giữ cả VDKey và bàn phím US, ưu tiên VDKey mặc định
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

cat << 'EOF' > "$USER_FCITX_DIR/addon/notificationitem.conf"
[Addon]
Name=notificationitem
Enabled=True
EOF

# 3. Ép hiển thị icon màu mặc định
cat << 'EOF' > "$USER_FCITX_DIR/conf/vdkey.conf"
UseLotusIcons=False
AutoNonVnRestore=False
IconTheme=Default
EOF

cat << 'EOF' > "$USER_FCITX_DIR/conf/classicui.conf"
Vertical Candidate List=False
WheelForPaging=True
Font="Sans 10"
MenuFont="Sans 10"
TrayFont="Sans Bold 10"
TrayOutlineColor=#000000
TrayTextColor=#ffffff
PreferTextIcon=False
ShowLayoutNameInIcon=True
UseInputMethodLanguageToDisplayText=True
Theme=default
DarkTheme=default#!/bin/bash
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
    imagemagick \
    wget \
    curl 2>/dev/null || true

echo "=== [3/7] TẢI VÀ CÀI ĐẶT GÓI .DEB VDKEY ==="
TEMP_DEB="/tmp/vdkey-latest.deb"
rm -f "$TEMP_DEB"

RELEASE_DEB_URL="https://github.com/longnguyen2026/gotiengviet/releases/download/vdkey/vdkey-2.0.0-Linux.deb"

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

UseDarkTheme=False
UseAccentColor=True
PerScreenDPI=True
ForceWaylandDPI=0
EnableFractionalScale=True
EOF

chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_FCITX_DIR"

# 4. Đồng bộ chính sách chuyển layout toàn cục cho KWin (KDE Plasma 6 / 5)
if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    sudo -u "$ACTUAL_USER" kwriteconfig6 --file kwinrc --group Layout --key SwitchingPolicy Global 2>/dev/null || \
    sudo -u "$ACTUAL_USER" kwriteconfig5 --file kwinrc --group Layout --key SwitchingPolicy Global 2>/dev/null || true
fi

# 5. Khai báo biến môi trường bộ gõ toàn cục cho người dùng (Qt5, Qt6, GTK, X11)
mkdir -p "$USER_HOME/.config/environment.d"
cat << 'EOF' > "$USER_HOME/.config/environment.d/fcitx5.conf"
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
EOF
chown -R "$ACTUAL_USER:$ACTUAL_USER" "$USER_HOME/.config/environment.d"

# 6. Nhúng biến môi trường trực tiếp vào file khởi chạy WPS Office (nếu đã cài WPS)
for f in /usr/bin/wps /usr/bin/et /usr/bin/wpp; do
    if [ -f "$f" ] && ! grep -q "QT_IM_MODULE=fcitx" "$f"; then
        sudo sed -i '2i export GTK_IM_MODULE=fcitx\nexport QT_IM_MODULE=fcitx\nexport XMODIFIERS=@im=fcitx' "$f"
    fi
done

echo "=== [7/7] KHỞI ĐỘNG LẠI TIẾN TRÌNH FCITX5 VÀ RELOAD GIAO DIỆN ==="
pkill -9 -f fcitx5 2>/dev/null || true
sleep 1
rm -rf "/run/user/$ACTUAL_UID/fcitx5"* "/tmp/fcitx5"* 2>/dev/null || true

if [ -n "$ACTUAL_USER" ] && [ "$ACTUAL_USER" != "root" ]; then
    sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" fcitx5 -d >/dev/null 2>&1 &
    
    if pgrep -x "plasmashell" >/dev/null 2>&1; then
        sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" kquitapp6 plasmashell 2>/dev/null || true
        sleep 1
        sudo -u "$ACTUAL_USER" env XDG_RUNTIME_DIR="/run/user/$ACTUAL_UID" DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_UID/bus" kstart plasmashell >/dev/null 2>&1 &
    fi
else
    fcitx5 -d >/dev/null 2>&1 &
fi

echo "=== HOÀN TẤT CÀI ĐẶT! BIỂU TƯỢNG VD XANH ĐÃ SẴN SÀNG TRÊN KHAY HỆ THỐNG & WPS ==="
