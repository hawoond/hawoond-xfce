#!/data/data/com.termux/files/usr/bin/bash
# Termux XFCE Ubuntu 설치 스크립트 (개선 버전)

# 출력에 사용할 색상 코드 정의
export GREEN='\033[0;32m' 
export TURQ='\033[0;36m' 
export URED='\033[4;31m' 
export UYELLOW='\033[4;33m' 
export WHITE='\033[0;37m'

# 오류 발생 시 처리 함수
finish() {
  local ret=$?
  if [ ${ret} -ne 0 ] && [ ${ret} -ne 130 ]; then
    echo -e "${URED}ERROR:${WHITE} XFCE on Termux 설치를 실패하였습니다."
    echo "위 오류 메시지를 참고하여 문제를 해결해주세요."
  fi
}
trap finish EXIT

clear
echo ""
echo -e "${TURQ}이 스크립트는 Termux XFCE Desktop 및 Ubuntu 프로ot 환경을 설치합니다.${WHITE}"
echo ""

# 1. 사용자로부터 리눅스 사용자 이름(ID) 입력 받기
read -r -p "Ubuntu 사용자 이름(username)을 입력하세요: " username

# 2. Ubuntu 버전 선택 (24.04 기본, 옵션으로 22.04)
echo ""
echo "설치할 Ubuntu 버전을 선택하세요."
echo "  1) Ubuntu 24.04 LTS (기본 권장)"
echo "  2) Ubuntu 22.04 LTS (호환 모드)"
read -r -p "선택 [1/2]: " ub_choice
if [ "$ub_choice" != "2" ]; then
    ub_choice="1"
fi

# 3. Termux 기본 패키지 설치 및 저장소 설정
echo -e "${GREEN}[*] Termux 패키지 및 저장소 설정 중...${WHITE}"
# 필요한 패키지 설치
pkg update -y
pkg upgrade -y
pkg install -y x11-repo tur-repo proot-distro wget curl git nano \
               termux-tools ncurses-utils dbus
# X11 리포 활성화로 termux-x11-nightly 등 이용, tur 리포로 fcitx5-hangul 등 이용

# Termux-X11 (안드로이드 앱) 설치 안내/자동 설치
echo -e "${GREEN}[*] Termux-X11 애플리케이션 설치 확인...${WHITE}"
# Termux-X11 앱 APK 다운로드
TERMUX_X11_URL="https://github.com/termux/termux-x11/releases/latest/download/termux-x11.apk"
wget -q -O termux-x11.apk $TERMUX_X11_URL
if [ -f "termux-x11.apk" ]; then
    echo "Termux-X11 APK 다운로드 완료. 설치를 진행합니다."
    # 사용자가 Termux에서 앱 설치를 허용했는지 확인 안내
    echo "Termux에서 앱 설치 허용을 해야 APK를 설치할 수 있습니다."
    sleep 2
    # 안드로이드의 패키지 설치 인텐트를 호출 (사용자 승인 필요)
    am start --user 0 -a android.intent.action.VIEW -d file://$(pwd)/termux-x11.apk -t application/vnd.android.package-archive
    echo "Termux-X11 앱을 설치한 후, 계속 진행하세요."
    read -p "(계속하려면 Enter 키)" dummy
else
    echo "${URED}[경고] Termux-X11 APK 다운로드 실패.${WHITE} GitHub 네트워크에 문제가 있습니다."
    echo "나중에 수동으로 Termux:X11 앱을 설치해야 할 수 있습니다."
fi

# Termux-X11 호환 패키지 설치 (nightly build)
pkg install -y termux-x11-nightly 
# (필요 시 hold: apt-mark hold termux-x11-nightly)

# 4. Fcitx5 한글 입력기 (Termux용) 설치
echo -e "${GREEN}[*] Termux 환경에 한글 입력기 설치...${WHITE}"
pkg install -y fcitx5 fcitx5-hangul

# 5. Ubuntu 프로ot 배포판 설치
echo -e "${GREEN}[*] Ubuntu 프로ot 배포판 설치 중...${WHITE}"
if [ "$ub_choice" = "1" ]; then
    # (1) 기본: Ubuntu 24.04 LTS 설치
    proot-distro install ubuntu || UBUNTU_INSTALL_FAIL="yes"
else
    UBUNTU_INSTALL_FAIL="yes"  # 22.04 선택 시 기본 설치 생략, custom 진행
fi

# (2) Ubuntu 24.04 설치 실패 또는 22.04 선택 시: Ubuntu 22.04 LTS 설치
if [ "$UBUNTU_INSTALL_FAIL" = "yes" ]; then
    echo -e "${UYELLOW}[!] Ubuntu 24.04 설치를 진행할 수 없습니다. Ubuntu 22.04 LTS를 설치합니다...${WHITE}"
    # Ubuntu 22.04 minimal rootfs 다운로드
    UB_TARBALL_URL="https://cdimage.ubuntu.com/ubuntu-base/releases/22.04/release/ubuntu-base-22.04.3-base-arm64.tar.gz"
    UB_TARBALL_FILE="ubuntu-base-22.04.3-base-arm64.tar.gz"
    wget -q -O $UB_TARBALL_FILE $UB_TARBALL_URL
    if [ ! -f "$UB_TARBALL_FILE" ]; then
        echo "${URED}ERROR:${WHITE} Ubuntu 22.04 rootfs 다운로드에 실패했습니다."
        exit 1
    fi
    # SHA256 검증
    echo "다운로드 완료 - 무결성 검증 중..."
    TARBALL_SHA256_EXPECT="bdae94b05d0fca7decbe164010af2ac1b772a9dda21ed9fb5552b5674ad634a3"  # 22.04.3 base arm64 SHA256
    TARBALL_SHA256_ACTUAL=$(sha256sum $UB_TARBALL_FILE | awk '{print $1}')
    if [ "$TARBALL_SHA256_ACTUAL" != "$TARBALL_SHA256_EXPECT" ]; then
        echo "${URED}WARNING:${WHITE} SHA256 해시가 일치하지 않습니다. 네트워크 오류 가능성 있음."
        echo "계속 진행하지만, 설치에 문제가 발생할 수 있습니다."
    else
        echo "SHA256 검증 성공."
    fi
    # 임시 distro 스크립트 생성
    DISTRO_NAME="ubuntu22.04"
    DISTRO_FILE="$PREFIX/etc/proot-distro/$DISTRO_NAME.sh"
    cp $PREFIX/etc/proot-distro/distro.sh.sample $DISTRO_FILE
    sed -i "s|^DISTRO_NAME=.*|DISTRO_NAME=\"Ubuntu 22.04 LTS\"|g" $DISTRO_FILE
    sed -i "s|^DISTRO_COMMENT=.*|DISTRO_COMMENT=\"Ubuntu 22.04 LTS Jammy Jellyfish\"|g" $DISTRO_FILE
    sed -i "s|^DISTRO_ARCH=.*|DISTRO_ARCH=aarch64|g" $DISTRO_FILE
    sed -i "s|^TARBALL_STRIP_OPT=.*|TARBALL_STRIP_OPT=0|g" $DISTRO_FILE
    sed -i "s|^TARBALL_URL\[\'aarch64\'\].*|TARBALL_URL['aarch64']=\"$UB_TARBALL_URL\"|g" $DISTRO_FILE
    sed -i "s|^TARBALL_SHA256\[\'aarch64\'\].*|TARBALL_SHA256['aarch64']=\"$TARBALL_SHA256_EXPECT\"|g" $DISTRO_FILE
    # 프로ot-distro로 22.04 설치
    proot-distro install $DISTRO_NAME || {
        echo "${URED}Ubuntu 22.04 설치 실패.${WHITE} 설치 스크립트를 종료합니다."
        exit 1
    }
    UB_DISTRO="ubuntu22.04"
else
    UB_DISTRO="ubuntu"
fi

# 6. 추가 설정 및 데스크톱 환경 구성
echo -e "${GREEN}[*] Ubuntu 환경 설정 및 XFCE 데스크톱 설치...${WHITE}"
# (a) 패키지 설치 스크립트 작성
cat > ~/ubuntu_setup.sh << 'EOL'
#!/bin/bash
set -e

# Ubuntu 컨테이너 내부에서 실행되는 설정 스크립트

# 1. 기본 패키지 업데이트/업그레이드
apt-get update -y
apt-get upgrade -y

# 2. Mesa-OSMesa 충돌 패키지 제거 (필요시)
apt-get remove -y osmesa osmesa-demos || true

# 3. 데스크톱 환경(XFCE4) 및 필수 패키지 설치
DEBIAN_FRONTEND=noninteractive 
apt-get install -y xfce4 xfce4-goodies tightvncserver \
    terminator sudo x11-xserver-utils dbus-x11 xscreensaver

# 4. 사용자 생성 및 sudo 권한 부여
useradd -m -s /bin/bash ${username} || true
echo "${username}:ubuntu" | chpasswd
usermod -aG sudo ${username}

# 5. 한글 폰트 및 로케일 설치
apt-get install -y fonts-nanum fonts-noto-cjk locales language-pack-ko

# 로케일 생성 및 기본 로케일 설정
sed -i 's/# ko_KR.UTF-8/ko_KR.UTF-8/' /etc/locale.gen
locale-gen ko_KR.UTF-8
update-locale LANG=ko_KR.UTF-8

# 6. Fcitx5 한글 입력기 설치
apt-get install -y fcitx5 fcitx5-hangul fcitx5-gtk fcitx5-configtool

# 자동 시작 설정 (XFCE 세션에서 fcitx5)
mkdir -p /home/${username}/.config/autostart
cat > /home/${username}/.config/autostart/fcitx5.desktop << EOF
[Desktop Entry]
Type=Application
Name=Fcitx5
Exec=/usr/bin/fcitx5 -d
X-GNOME-Autostart-enabled=true
EOF

chown -R ${username}:${username} /home/${username}/.config

# 7. 환경 변수 설정 (한글 입력기)
echo "export GTK_IM_MODULE=fcitx" >> /etc/profile.d/fcitx.sh
echo "export QT_IM_MODULE=fcitx" >> /etc/profile.d/fcitx.sh
echo "export XMODIFIERS=@im=fcitx" >> /etc/profile.d/fcitx.sh

# 8. 완료 메시지
echo "Ubuntu 내부 설정 완료."
EOL

# (b) 스크립트에 실행 권한 부여
chmod +x ~/ubuntu_setup.sh

# (c) 준비한 스크립트를 프로ot Ubuntu 환경 내에서 실행
proot-distro login --user root --bind ~/ubuntu_setup.sh:/root/ubuntu_setup.sh $UB_DISTRO /root/ubuntu_setup.sh

# 7. 마무리: 불필요한 파일 정리
rm -f ~/ubuntu_setup.sh
rm -f termux-x11.apk
if [ "$UB_DISTRO" = "ubuntu22.04" ]; then
    rm -f $UB_TARBALL_FILE
    rm -f $PREFIX/etc/proot-distro/ubuntu22.04.sh
fi

echo -e "${GREEN}[*] 설치 완료!${WHITE} 'ubuntu' 명령으로 프로ot 환경에 진입하고, 'startXFCE'로 데스크톱을 실행하세요."