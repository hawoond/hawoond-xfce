#!/data/data/com.termux/files/usr/bin/bash
# Galaxy Tab S9 Ultra | Termux:X11 + VirGL GPU | Ubuntu 24.04 XFCE 자동 설치
set -e


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
proot-distro login ubuntu --shared-tmp --bind /proc --bind /dev/shm \
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