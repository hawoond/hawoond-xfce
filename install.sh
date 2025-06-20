#!/data/data/com.termux/files/usr/bin/bash
# Galaxy Tab S9 Ultra | Termux:X11 + VirGL GPU | Ubuntu 24.04 XFCE 자동 설치
set -e

#######################################################################
# 0) Termux 쪽 패키지 / 리포 / GPU 연관 도구 설치
#######################################################################
echo "[1/6] Termux 패키지 업데이트"
pkg update -y && pkg upgrade -y

echo "[2/6] 리포 + GPU 패키지 설치"
pkg install -y x11-repo tur-repo termux-x11-nightly \
               virglrenderer-android mesa vulkan-loader-android \
               libandroid-shmem pulseaudio wget proot-distro

export PROOT_NO_SECCOMP=1   # Android 12+ seccomp 우회

#######################################################################
# 1) 공식 rootfs 직접 다운로드 → proot-distro 수동 등록
#######################################################################
echo "[3/6] Ubuntu 24.04 rootfs 수동 설치 (dpkg-reconfigure 완전 회피)"

DIST=ubuntu-24.04
PD_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs"
ROOT="$PD_DIR/$DIST"

# 1-1) 이미 깔려 있으면 건너뜀
if [ -f "$ROOT/etc/os-release" ]; then
  echo " - $DIST 이미 설치되어 있어 건너뜁니다."
else
  echo " - rootfs 다운로드 및 전개"

  mkdir -p "$ROOT" "$HOME/.cache/rootfs"
  cd "$HOME/.cache/rootfs"

  # Canonical cloudimg arm64 rootfs (약 190 MB)  [oai_citation:0‡images.linuxcontainers.org](https://images.linuxcontainers.org/images/ubuntu/noble/arm64/cloud/20250615_08%3A08/?utm_source=chatgpt.com)
  ROOTFS_URL="https://images.linuxcontainers.org/images/ubuntu/noble/arm64/cloud/current/rootfs.tar.xz"
  wget -c "$ROOTFS_URL" -O ubuntu-noble-arm64-rootfs.tar.xz

  # 1-2) rootfs 전개 (proot 필요 – 하드링크→심링크)
  proot --link2symlink tar -xJf ubuntu-noble-arm64-rootfs.tar.xz -C "$ROOT"

  # 1-3) proot-distro 메타파일 수동 작성
  echo "Ubuntu 24.04 (manual)" > "$ROOT/.dist-info"
  cat > "$ROOT/.proot-distro" <<EOF
id=$DIST
version=24.04
arch=arm64
EOF
fi

alias_name=$DIST   # 이후 단계에서 사용할 alias

#######################################################################
# 2) Ubuntu 내부 패키지 설치 (XFCE·한글·VS Code 등)
#######################################################################
echo "[4/6] Ubuntu 패키지 구성"
proot-distro login "$alias_name" --shared-tmp --user root -- bash -e <<'EOF'
  export DEBIAN_FRONTEND=noninteractive
  apt update -y

  # snapd 비활성( systemd 부재 )
  printf 'Package: snapd\nPin: release a=*\nPin-Priority: -10\n' >/etc/apt/preferences.d/nosnap.pref

  # XFCE + 한글 입력 + GPU 테스트 툴 + VS Code
  apt install -y xfce4 xfce4-terminal dbus-x11 x11-xserver-utils \
                 ibus ibus-hangul fonts-noto-cjk fonts-nanum \
                 locales sudo wget mesa-utils

  # locale: ko_KR.UTF-8 생성
  sed -i 's/^# *ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen && update-locale LANG=ko_KR.UTF-8

  # VS Code arm64 .deb 설치
  wget -qO /tmp/code.deb https://aka.ms/linux-arm64-deb && apt install -y /tmp/code.deb || true

  # D-Bus machine-id 생성(경고 예방)
  dbus-uuidgen > /etc/machine-id || true
EOF

#######################################################################
# 3) Termux 자동 부팅(.bashrc) 등록 – X11 + VirGL + XFCE
#######################################################################
echo "[5/6] .bashrc 자동 부팅 설정"
RC=$HOME/.bashrc
cp "$RC" "$RC.bak.$(date +%s)" 2>/dev/null || true

cat >>"$RC" <<'BASHRC'

### === Ubuntu 24.04 XFCE + VirGL GPU 자동 부팅 ===
# X11 서버 & VirGL & 사운드
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
pgrep -f "termux-x11 :0" >/dev/null || termux-x11 :0 -ac &
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

# Ubuntu 24.04 로그인 후 XFCE 실행
proot-distro login ubuntu-24.04 --shared-tmp --bind /dev/shm -- bash -c '
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
### =================================================
BASHRC

#######################################################################
echo "[✔] 모든 단계 완료!"
echo "1) Termux:X11 앱을 먼저 실행 → 검은 화면 유지"
echo "2) Termux 재실행 → Ubuntu 24.04 XFCE 부팅"
echo "3) Ubuntu 터미널에서  glxinfo | grep renderer  → virpipe/virgl 확인"
#######################################################################