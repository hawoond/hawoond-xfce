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
echo "[3/6] 사용자 홈으로 proot-distro 저장소 이동 + Ubuntu 24.04 rootfs 설치"

# ── A. 사용자 홈에 전용 경로 확보 ───────────────────────────────
CUSTOM_PD="$HOME/.proot-distro"                # ★ 완전 사용자 소유 경로
INST_DIR="$CUSTOM_PD/installed-rootfs"
mkdir -p "$INST_DIR"

# ── B. 기존 (읽기전용) 경로를 안전하게 대체 ────────────────────
# 만약 $PREFIX/var/lib/proot-distro 가 이미 있다면 심볼릭 링크로 교체
SYS_PD="$PREFIX/var/lib/proot-distro"
if [ ! -L "$SYS_PD" ]; then
    if [ -d "$SYS_PD" ]; then
        echo " - 기존 기본 디렉터리 백업 → $SYS_PD.bak"
        mv "$SYS_PD" "$SYS_PD.bak.$(date +%s)"
    fi
    ln -s "$CUSTOM_PD" "$SYS_PD"
fi

# ── C. rootfs 다운로드·전개(404 대비 이중 URL) ─────────────────
DIST=ubuntu-24.04
ROOT="$INST_DIR/$DIST"

if [ -f "$ROOT/etc/os-release" ]; then
  echo " - $DIST 이미 설치됨"
else
  echo " - rootfs 다운로드"
  mkdir -p "$ROOT" "$HOME/.cache/rootfs" && cd "$HOME/.cache/rootfs"

  PRI_URL="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64-root.tar.xz"
  SEC_URL="$(curl -s https://images.linuxcontainers.org/images/ubuntu/noble/arm64/default/ \
            | grep -oE '[0-9]{8}_[0-9]{2}:[0-9]{2}' | sort -r | head -n1 | \
            xargs -I{} echo 'https://images.linuxcontainers.org/images/ubuntu/noble/arm64/default/{}/rootfs.tar.xz')"

  wget -c "$PRI_URL" -O ubuntu24-rootfs.tar.xz || wget -c "$SEC_URL" -O ubuntu24-rootfs.tar.xz

  echo " - rootfs 전개 (권한 안전 모드)"
  proot --link2symlink tar \
    --numeric-owner --no-same-owner --no-same-permissions \
    --exclude='dev/*' --exclude='./dev/*' \
    -xJf ubuntu24-rootfs.tar.xz -C "$ROOT"

  # 빈 /dev 디렉터리 및 최소 심볼릭 링크 구성
  mkdir -p "$ROOT/dev"
  for f in null zero random urandom tty; do
    ln -s "/dev/$f" "$ROOT/dev/$f"
  done

  # 메타파일 작성
  echo "Ubuntu 24.04 (manual)" > "$ROOT/.dist-info"
  printf 'id=%s\nversion=24.04\narch=arm64\n' "$DIST" > "$ROOT/.proot-distro"
fi

alias_name=$DIST

#######################################################################
# 2) Ubuntu 내부 패키지 설치 (XFCE·한글·VS Code 등)
#######################################################################
echo "[4/6] Ubuntu 패키지 구성"
proot-distro login "ubuntu" --shared-tmp --user root -- bash -e <<'EOF'
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