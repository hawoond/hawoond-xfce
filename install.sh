#!/data/data/com.termux/files/usr/bin/bash
# Galaxy Tab S9 Ultra  |  Ubuntu 24.04  |  GPU 가속 (VirGL)  |  XFCE 자동 부팅
set -e

echo "[1/6] Termux 기본 패키지 업데이트"
pkg update -y && pkg upgrade -y

echo "[2/6] 리포지토리 & GPU 관련 패키지 설치"
pkg install -y x11-repo tur-repo        # X11 + 사용자 리포
pkg install -y termux-x11-nightly       # Termux:X11 CLI 패키지
pkg install -y virglrenderer-android    # VirGL 서버 (OpenGL→GPU)  [oai_citation:1‡ivonblog.com](https://ivonblog.com/en-us/posts/termux-virglrenderer/?utm_source=chatgpt.com)
pkg install -y mesa vulkan-loader-android \
               libandroid-shmem pulseaudio wget proot-distro

export PROOT_NO_SECCOMP=1               # Android 12+ seccomp 우회

echo "[3/6] Ubuntu 24.04(Proot) 확인"
if proot-distro list | awk '{print $1}' | grep -Eq '^ubuntu(-[0-9.]+)?$'; then
  echo " - ubuntu 배포판 이미 존재 ▶ 설치 단계 건너뜀"
else
  echo " - ubuntu 배포판 없음 ▶ 설치 진행"
  proot-distro install ubuntu || true       # 이미 깔려 있으면 무시
fi

echo "[4/6] Ubuntu 내부 패키지 구성(한글·XFCE·VSCode)"
proot-distro login ubuntu --shared-tmp --user root -- bash -e <<'INCH'
  export DEBIAN_FRONTEND=noninteractive
  apt update -y
  # snapd 제거(시스템d 미동작)
  printf 'Package: snapd\nPin: release a=*\nPin-Priority: -10\n' > /etc/apt/preferences.d/nosnap.pref
  # XFCE + Korean + VS Code + GPU 테스트 유틸
  apt install -y xfce4 xfce4-terminal dbus-x11 x11-xserver-utils \
                 ibus ibus-hangul fonts-noto-cjk fonts-nanum \
                 language-pack-ko locales sudo wget mesa-utils
  sed -i 's/^# *ko_KR.UTF-8 UTF-8/ko_KR.UTF-8 UTF-8/' /etc/locale.gen
  locale-gen && update-locale LANG=ko_KR.UTF-8
  # VS Code(arm64)
  wget -qO /tmp/code.deb https://aka.ms/linux-arm64-deb && apt install -y /tmp/code.deb || true
  dbus-uuidgen > /etc/machine-id || true
INCH

echo "[5/6] .bashrc 자동 부팅 라인 추가"
BRC=$HOME/.bashrc
cp "$BRC" "$BRC.bak.$(date +%s)" 2>/dev/null || true
cat >>"$BRC" <<'EOBRC'

### ---- Ubuntu 24.04 + XFCE + GPU 가속 자동 부팅 ----
# ① Termux:X11 앱 자동 호출
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || true
# ② X11 서버 시작(:0, access control off)
pgrep -f "termux-x11 :0" >/dev/null || termux-x11 :0 -ac &
sleep 2
# ③ VirGL 서버 구동(GPU → Proot)
pgrep -f virgl_test_server_android >/dev/null || virgl_test_server_android --use-egl-surfaceless &
# ④ PulseAudio (사운드)
pulseaudio --start --exit-idle-time=-1
# ⑤ Ubuntu XFCE 실행(한글·GPU 변수 세팅)
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=virpipe          # VirGL 클라이언트 드라이버  [oai_citation:2‡ivonblog.com](https://ivonblog.com/en-us/posts/termux-virglrenderer/?utm_source=chatgpt.com)
proot-distro login ubuntu --shared-tmp --bind /dev/shm -- bash -c '
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
### ---------------------------------------------------
EOBRC

echo "[6/6] 설치 완료! Termux 재실행하면 Ubuntu 24.04 XFCE + GPU가 자동 부팅됩니다."
echo "   * 첫 실행 전, 반드시 **Termux:X11 앱을 한 번 열어 두기**."
echo "   * GL렌더러 확인: Ubuntu 터미널 > glxinfo | grep 'renderer'"