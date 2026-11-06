#!/usr/bin/env bash
# ==============================================================================
# Script cài đặt & tự động cấu hình bộ gõ VDKey cho Ubuntu / Debian / Linux Mint
# Tự động gỡ bộ gõ cũ, nạp profile, kích hoạt logo VD và chống crash sudo-rs
# ==============================================================================
set -e

GITHUB_USER="longnguyen2026"
GITHUB_REPO="gotiengviet"
TAG_NAME="vdkey"
DEB_NAME="vdkey-1.0.0-Linux.deb"

# Kiểm tra quyền thực thi
if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

# Xác định chính xác User đồ họa thực tế (tránh nhầm lẫn thư mục root)
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_UID=$(id -u "$REAL_USER")

echo "=================================================================="
echo "          TRÌNH CÀI ĐẶT BỘ GÕ TIẾNG VIỆT VDKEY CHO LINUX          "
echo "=================================================================="
echo ">> Người dùng đích: $REAL_USER ($REAL_HOME)"

# --- BƯỚC 1: KIỂM TRA BỘ GÕ XUNG ĐỘT TRÊN MÁY ---
echo ">> Đang kiểm tra các bộ gõ tiếng Việt khác trên hệ thống..."

CONFLICT_PACKAGES=()
INSTALLED_DESC=()

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

REMOVE_OLD=false

if [ "${#CONFLICT_PACKAGES[@]}" -gt 0 ] || [ "${#MANUAL_FILES[@]}" -gt 0 ]; then
    echo ""
    echo "⚠️  PHÁT HIỆN CÁC BỘ GÕ TIẾNG VIỆT KHÁC ĐANG CÓ TRÊN MÁY:"
    for item in "${INSTALLED_DESC[@]}"; do
        echo "$item"
    done
    echo ""
    echo "Việc để nhiều bộ gõ chạy song song dễ gây xung đột phím và khay hệ thống."
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
                echo "Lựa chọn không hợp lệ, vui lòng chọn 1, 2 hoặc 0."
                ;;
        esac
    done
else
    echo ">> Không phát hiện bộ gõ nào khác xung đột. Tiếp tục cài đặt."
fi

# --- BƯỚC 2: GỠ BỎ BỘ GÕ KHÁC NẾU CHỌN TÙY CHỌN 1 ---
if [ "$REMOVE_OLD" = true ]; then
    echo ""
    echo "=== Đang dọn dẹp các bộ gõ cũ ==="
    killall -9 ibus-daemon 2>/dev/null || true
    killall -9 fcitx 2>/dev/null || true

    if [ "${#CONFLICT_PACKAGES[@]}" -gt 0 ]; then
        echo "Đang gỡ các gói: ${CONFLICT_PACKAGES[*]} ..."
        $SUDO apt-get purge -y "${CONFLICT_PACKAGES[@]}" 2>/dev/null || true
        $SUDO apt-get autoremove -y 2>/dev/null || true
    fi

    $SUDO rm -f /usr/share/fcitx5/addon/*funput*.conf 2>/dev/null || true
    $SUDO rm -f /usr/share/fcitx5/inputmethod/*funput*.conf 2>/dev/null || true
    $SUDO rm -f /usr/lib/*/fcitx5/*funput*.so 2>/dev/null || true
    $SUDO rm -rf /usr/share/funput ~/.config/fcitx5/conf/*funput* 2>/dev/null || true
    echo ">> Đã gỡ bỏ sạch sẽ bộ gõ cũ."
fi

# --- BƯỚC 3: DỪNG TIẾN TRÌNH FCITX5 HIỆN TẠI ---
echo ""
echo "=== Dừng tiến trình Fcitx5 để chuẩn bị cài đặt ==="
killall -9 fcitx5 2>/dev/null || true
sleep 1

# --- BƯỚC 4: CÀI ĐẶT FCITX5 VÀ DEPENDENCIES ĐỦ ---
echo ""
echo "=== [1/4] Cập nhật danh sách gói và cài đặt dependencies ==="
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
    python3-pil \
    python3-pyqt5 \
    python3-pyqt5.qtquick \
    python3-pyqt5.qtsvg 2>/dev/null || true

$SUDO apt-get install -y fcitx5-frontend-qt6 2>/dev/null || true

# --- BƯỚC 5: TẢI & CÀI ĐẶT GÓI VDKEY MỚI NHẤT ---
echo ""
echo "=== [2/4] Tải gói .deb từ GitHub Release ==="
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

DEB_URL="https://github.com/${GITHUB_USER}/${GITHUB_REPO}/releases/download/${TAG_NAME}/${DEB_NAME}"
echo "Đang tải $DEB_URL ..."

if ! curl -fL "$DEB_URL" -o "$TMP_DIR/$DEB_NAME"; then
    echo "❌ Lỗi: Không thể tải file .deb từ Release. Vui lòng kiểm tra lại link!"
    exit 1
fi

if ! dpkg-deb -I "$TMP_DIR/$DEB_NAME" >/dev/null 2>&1; then
    echo "❌ Lỗi: File .deb tải về không hợp lệ hoặc bị hỏng!"
    exit 1
fi

echo ""
echo "=== [3/4] Cài đặt gói VDKey ==="
$SUDO dpkg -i --force-overwrite --force-confmiss "$TMP_DIR/$DEB_NAME" || $SUDO apt-get install -f -y

# Đảm bảo symlink GUI cài đặt
if [ -f "/usr/bin/fcitx5-ngosen-settings" ] && [ ! -f "/usr/bin/vdkey-settings" ]; then
    $SUDO ln -sf /usr/bin/fcitx5-ngosen-settings /usr/bin/vdkey-settings
fi

# Đảm bảo tương thích thư viện kiến trúc (tránh lỗi Cannot find file vdkey)
for libpath in /usr/lib/x86_64-linux-gnu/fcitx5 /usr/lib/fcitx5; do
    if [ -f "$libpath/libvdkey.so" ]; then
        $SUDO ln -sf "$libpath/libvdkey.so" "$libpath/vdkey.so"
    fi
done
$SUDO ldconfig 2>/dev/null || true

# Đảm bảo file cấu hình addon và inputmethod luôn tồn tại
$SUDO mkdir -p /usr/share/fcitx5/addon /usr/share/fcitx5/inputmethod

if [ ! -f /usr/share/fcitx5/addon/vdkey.conf ]; then
$SUDO tee /usr/share/fcitx5/addon/vdkey.conf > /dev/null << 'EOF'
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
fi

if [ ! -f /usr/share/fcitx5/inputmethod/vdkey.conf ]; then
$SUDO tee /usr/share/fcitx5/inputmethod/vdkey.conf > /dev/null << 'EOF'
[InputMethod]
Name=VDKey
Icon=fcitx-vdkey
Label=VD
LangCode=vi
Addon=vdkey
Configurable=True
EOF
fi

# Đồng bộ icon sang tất cả theme để hiện chuẩn logo VD
for tdir in /usr/share/icons/*; do
    if [ -d "$tdir" ] && [ -f "$tdir/index.theme" ]; then
        if [ ! -f "$tdir/status/22/fcitx-vdkey.svg" ] && [ -d "$tdir/status" ]; then
            $SUDO mkdir -p "$tdir/status/22" "$tdir/status/24"
            $SUDO cp -f /usr/share/icons/breeze/status/22/*vdkey* "$tdir/status/22/" 2>/dev/null || true
            $SUDO cp -f /usr/share/icons/breeze/status/24/*vdkey* "$tdir/status/24/" 2>/dev/null || true
        fi
        $SUDO gtk-update-icon-cache -f -q "$tdir" 2>/dev/null || true
    fi
done

# --- BƯỚC 6: BIẾN MÔI TRƯỜNG TOÀN HỆ THỐNG ---
echo ""
echo "=== [4/4] Thiết lập biến môi trường và nạp profile ==="
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

# --- BƯỚC 7: AUTOSTART VÀ PROFILE NGƯỜI DÙNG ---
# 1. Autostart
mkdir -p "$REAL_HOME/.config/autostart"
cat << 'EOF' > "$REAL_HOME/.config/autostart/org.fcitx.Fcitx5.desktop"
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

# 2. Profile nạp trực tiếp vdkey
mkdir -p "$REAL_HOME/.config/fcitx5"
cat << 'EOF' > "$REAL_HOME/.config/fcitx5/profile"
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

# 3. Cấu hình nhập liệu
cat << 'EOF' > "$REAL_HOME/.config/fcitx5/config"
[GlobalOptions]
ShareInputState=All
ResetInputMethodOnFocusIn=No
EOF

# 4. Tắt kiểm tra chính tả gây nhảy ký tự
mkdir -p "$REAL_HOME/.config/fcitx5/conf"
cat << 'EOF' > "$REAL_HOME/.config/fcitx5/conf/spell.config"
[Spell]
Enabled=False
EOF

cat << 'EOF' > "$REAL_HOME/.config/fcitx5/conf/vdkey.config"
[Spell]
CheckSpelling=False
AutoCorrect=False
RestoreIfInvalidWord=False
EOF

cat << 'EOF' > "$REAL_HOME/.config/fcitx5/conf/waylandim.config"
[Diagnose]
ShowAgain=False
EOF

# Phân quyền đúng cho User thực tế
chown -R "$REAL_USER:$REAL_USER" "$REAL_HOME/.config/autostart" "$REAL_HOME/.config/fcitx5"

# Đồng bộ profile sang /etc/skel cho các user mới
$SUDO mkdir -p /etc/skel/.config/fcitx5
$SUDO cp -f "$REAL_HOME/.config/fcitx5/profile" /etc/skel/.config/fcitx5/profile

# Xóa cache icon cũ của user
rm -rf "$REAL_HOME/.cache/icon-cache.kcache" "$REAL_HOME/.cache/plasma*" 2>/dev/null || true

# --- BƯỚC 8: KHỞI ĐỘNG LẠI FCITX5 CHUẨN SESSION GRAPHICAL DBUS ---
# Chuỗi lệnh khởi động lại Fcitx5 và kích hoạt ngay VDKey
RELOAD_SCRIPT="
killall -9 fcitx5 2>/dev/null || true
sleep 1
fcitx5 -d >/dev/null 2>&1 &
sleep 1
fcitx5-remote -r >/dev/null 2>&1 || true
fcitx5-remote -s vdkey >/dev/null 2>&1 || true
fcitx5-remote -o >/dev/null 2>&1 || true
"

# Thực thi lệnh dưới đúng session người dùng để tránh crash sudo-rs
if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    su - "$REAL_USER" -c "
        export DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/${REAL_UID}/bus\"
        export DISPLAY=\"${DISPLAY:-:0}\"
        export XDG_RUNTIME_DIR=\"/run/user/${REAL_UID}\"
        $RELOAD_SCRIPT
    " 2>/dev/null || true
else
    eval "$RELOAD_SCRIPT"
fi

echo ""
echo "=================================================================="
echo ">> CÀI ĐẶT HOÀN TẤT VDKEY!"
echo ">> VDKey đã được kích hoạt thành công trên khay hệ thống."
echo ">> Kiểm tra trạng thái hiện tại bằng lệnh: fcitx5-remote -n"
echo "=================================================================="
