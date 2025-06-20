#!/data/data/com.termux/files/usr/bin/bash
# Galaxy Tab S9 Ultra | Termux:X11 + VirGL GPU | Ubuntu 24.04 XFCE 자동 설치
set -e

############################ 0. Termux 패키지 ############################
echo "[1/6] Termux 패키지 업데이트"
pkg update -y && pkg upgrade -y

echo "[2/6] 리포 + GPU 패키지 설치"
pkg install -y  x11-repo tur-repo termux-x11-nightly \
                virglrenderer-android mesa vulkan-loader-android \
                libandroid-shmem pulseaudio wget proot-distro curl

export PROOT_NO_SECCOMP=1   # Android 12+ seccomp 우회

###################### 1. rootfs 수동 설치(권한 안전) ####################
echo "[3/6] 사용자 홈으로 proot-distro 저장소 이동 + Ubuntu 24.04 rootfs 설치"

CUSTOM_PD="$HOME/.proot-distro"                 # 사용자 완전 소유
INST_DIR="$CUSTOM_PD/installed-rootfs"
mkdir -p "$INST_DIR"

SYS_PD="$PREFIX/var/lib/proot-distro"           # 시스템 기본 경로 → 심링크 대체
if [ ! -L "$SYS_PD" ]; then
    [ -d "$SYS_PD" ] && mv "$SYS_PD" "$SYS_PD.bak.$(date +%s)"
    ln -s "$CUSTOM_PD" "$SYS_PD"
fi

DIST="ubuntu"
ROOT="$INST_DIR/$DIST"

if [ -f "$ROOT/etc/os-release" ]; then
  echo " - $DIST 이미 설치됨"
else
  echo " - rootfs 다운로드"
  mkdir -p "$ROOT" "$HOME/.cache/rootfs" && cd "$HOME/.cache/rootfs"

  PRI_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64-root.tar.xz"
  # LXC 미러 최신 타임스탬프(Fallback)
  SEC_URL="$(curl -s https://images.linuxcontainers.org/images/ubuntu/noble/arm64/default/ |
            grep -oE '[0-9]{8}_[0-9]{2}:[0-9]{2}' | sort -r | head -n1 |
            sed 's|$|/rootfs.tar.xz|' |
            sed 's|^|https://images.linuxcontainers.org/images/ubuntu/noble/arm64/default/|')"

  wget -c "$PRI_URL" -O ubuntu24-rootfs.tar.xz  ||  wget -c "$SEC_URL" -O ubuntu24-rootfs.tar.xz

  echo " - rootfs 전개 (디바이스 노드 제외)"
  proot --link2symlink tar \
        --numeric-owner --no-same-owner --no-same-permissions \
        --exclude='dev/*' --exclude='./dev/*' \
        -xJf ubuntu24-rootfs.tar.xz -C "$ROOT"

  # 최소 /dev 심볼릭 링크
  mkdir -p "$ROOT/dev"
  for f in null zero random urandom tty; do ln -s "/dev/$f" "$ROOT/dev/$f"; done

  # proot-distro 메타
  echo "Ubuntu 24.04 (manual)" > "$ROOT/.dist-info"
  printf 'id=%s\nversion=24.04\narch=arm64\n' "$DIST" > "$ROOT/.proot-distro"
fi
alias_name=$DIST       # 이후 단계에서 사용

##################### 2. Ubuntu 패키지 구성(샌드박스 OFF) ################
echo "[4/6] Ubuntu 패키지 구성(샌드박스 해제 + /proc 바인드)"

# 깨진 APT 목록 폴더가 있으면 삭제
[ -d "$ROOT/var/lib/apt/lists" ] && rm -rf "$ROOT/var/lib/apt/lists"/*

cd "$HOME"   # getcwd 경고 방지
proot-distro login "$alias_name" \
  --shared-tmp --bind /proc --bind /dev/shm \
  --user root -- bash -e <<'EOF'
set -e
cd /root

# APT 샌드박스 완전 해제
cat > /etc/apt/apt.conf.d/00nosandbox.conf <<'APT'
APT::Sandbox::User "root";
APT::Sandbox::Seccomp "false";
APT

apt clean
rm -rf /var/lib/apt/lists/*
export DEBIAN_FRONTEND=noninteractive
apt update -y

# snapd 비활성
printf 'Package: snapd\nPin: release a=*\nPin-Priority: -10\n' > /etc/apt/preferences.d/nosnap.pref

# XFCE + 한글 + GPU 유틸
apt install -y xfce4 xfce4-terminal dbus-x11 x11-xserver-utils \
               ibus ibus-hangul fonts-noto-cjk fonts-nanum \
               locales sudo wget mesa-utils

# locale
sed -i 's/^# *ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen
locale-gen && update-locale LANG=ko_KR.UTF-8

# VS Code (ARM64)
wget -qO /tmp/code.deb https://aka.ms/linux-arm64-deb && apt install -y /tmp/code.deb || true

dbus-uuidgen > /etc/machine-id || true
EOF

##################### 3. .bashrc 자동 부팅 등록 #########################
echo "[5/6] .bashrc 자동 부팅 등록"
RC="$HOME/.bashrc"
cp "$RC" "$RC.bak.$(date +%s)" 2>/dev/null || true

cat >>"$RC" <<'BASHRC'

### === Ubuntu 24.04 XFCE + VirGL GPU 자동 부팅 ===
# X11 서버 & VirGL & PulseAudio
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
pgrep -f "termux-x11 :0"  >/dev/null || termux-x11 :0 -ac &
sleep 2
pgrep -f virgl_test_server_android >/dev/null || virgl_test_server_android --use-egl-surfaceless &
pulseaudio --start --exit-idle-time=-1

# 공통 환경변수
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export GTK_IM_MODULE=ibus
export QT_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=virpipe

# Ubuntu 컨테이너 로그인 → XFCE 실행
proot-distro login ubuntu-24.04 --shared-tmp --bind /proc --bind /dev/shm \
  --user root -- bash -c '
    export DISPLAY=:0
    export PULSE_SERVER=127.0.0.1
    export GTK_IM_MODULE=ibus
    export QT_IM_MODULE=ibus
    export XMODIFIERS=@im=ibus
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=virpipe
    dbus-launch --exit-with-session bash -c "ibus-daemon -drx & exec startxfce4"
'
exit
### ====================================================================
BASHRC

######################## 4. 완료 메시지 #################################
echo
echo "[✔] 모든 단계 완료!"
echo "1) Termux:X11 앱을 먼저 실행 → 검은 화면 유지"
echo "2) Termux 재실행 → Ubuntu 24.04 XFCE 부팅"
echo "3) Ubuntu 터미널에서  glxinfo | grep renderer  → virpipe/virgl 확인"
echo
########################################################################