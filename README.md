# Termux-XFCE 자동 설치기 (Galaxy Tab s9 ultra)

Ubuntu 24.04 또는 22.04 환경에서 XFCE 데스크탑 환경을 자동 구성합니다.

## 특징

- Termux + Ubuntu Proot 환경 자동 구성
- XFCE4 데스크탑 + Termux:X11 앱 자동 설치
- 한글 입력기(Fcitx5) 및 폰트 자동 설치
- Ubuntu 24.04 설치 실패 시 22.04로 자동 대체

## 사용법

```bash
pkg install git -y
git clone https://github.com/hawoond/hawoond-xfce.git
cd hawoond-xfce
chmod +x install.sh startXFCE
./install.sh