# WireGuard VPN 설치 가이드

## 개요

`wireguard-install.sh`는 AWS Lightsail에서 WireGuard VPN 서버를 자동으로 설치하고 설정하는 스크립트입니다. 이 스크립트는 복잡한 VPN 설정 과정을 자동화하여 몇 분 안에 안전한 VPN 서버를 구축할 수 있습니다.

## 설치 전 준비사항

### 1. AWS Lightsail 인스턴스 준비

**최소 권장 사양:**
- 인스턴스: $5/월 (1GB RAM, 1 vCPU) 이상
- OS: Ubuntu 22.04 LTS 또는 24.04 LTS
- 스토리지: 최소 20GB

**Elastic IP 설정 (강력 권장):**
1. Lightsail 콘솔에서 "Networking" → "Static IPs" 이동
2. "Create static IP" 클릭
3. 인스턴스에 고정 IP 할당

### 2. SSH 접속 준비

```bash
# SSH 키를 사용한 접속
ssh -i your-key.pem ubuntu@your-server-ip

# 또는 Lightsail 브라우저 SSH 사용
```

## 설치 과정

### 1. 스크립트 다운로드

```bash
# GitHub에서 직접 다운로드
wget https://github.com/shoveller/initial-script-recipes/raw/main/wireguard-install.sh
chmod +x wireguard-install.sh

# 또는 git clone 후 사용
git clone https://github.com/shoveller/initial-script-recipes.git
cd initial-script-recipes
chmod +x wireguard-install.sh
```

### 2. 스크립트 실행

```bash
sudo bash wireguard-install.sh
```

### 3. 설치 과정 상호작용

스크립트 실행 중 다음과 같은 입력이 필요합니다:

1. **관리자 패스워드 설정**
   ```
   새 관리자 패스워드를 입력하세요: [패스워드 입력]
   패스워드를 다시 입력하세요: [패스워드 재입력]
   ```

2. **첫 번째 클라이언트 이름**
   ```
   첫 번째 클라이언트 이름을 입력하세요 (기본값: client1): [클라이언트명]
   ```

### 4. AWS Lightsail 방화벽 설정

스크립트 완료 후 **반드시** AWS Lightsail 콘솔에서 방화벽을 설정해야 합니다:

1. Lightsail 인스턴스 페이지 → "Networking" 탭
2. "Firewall" 섹션에서 "Add rule" 클릭
3. 다음 설정으로 규칙 추가:
   - **Application**: Custom
   - **Protocol**: UDP
   - **Port**: 51820
4. "Create" 클릭

**보안 강화 (선택사항):**
- SSH(22/tcp) 규칙을 삭제하여 VPN을 통해서만 SSH 접속 허용

## 클라이언트 설정

### 모바일 클라이언트 (Android/iOS)

1. **WireGuard 앱 설치**
   - Android: Google Play Store에서 "WireGuard" 검색
   - iOS: App Store에서 "WireGuard" 검색

2. **QR 코드로 설정**
   ```bash
   # 서버에서 QR 코드 확인
   cd /home/ubuntu/wireguard-clients
   cat client1.conf
   ```
   - 터미널에 표시된 QR 코드를 앱으로 스캔
   - 또는 `client1_qr.png` 파일을 다운로드하여 스캔

### PC 클라이언트 (Windows/macOS/Linux)

1. **WireGuard 설치**
   - Windows: [wireguard.com](https://www.wireguard.com/install/)에서 다운로드
   - macOS: App Store 또는 Homebrew (`brew install wireguard-tools`)
   - Linux: 패키지 매니저 (`apt install wireguard`)

2. **설정 파일 다운로드**
   ```bash
   # 서버에서 설정 파일 다운로드
   scp ubuntu@your-server-ip:/home/ubuntu/wireguard-clients/client1.conf ./
   ```

3. **WireGuard에 설정 추가**
   - 설정 파일을 WireGuard 앱에 임포트
   - 연결 활성화

## 관리 명령어

### 클라이언트 관리

```bash
# 새 클라이언트 추가
sudo ./add-client.sh

# 클라이언트 제거
sudo ./remove-client.sh

# 클라이언트 목록 확인
./list-clients.sh
```

### 서비스 관리

```bash
# WireGuard 관리 메뉴
./manage-wireguard.sh

# 서비스 상태 확인
sudo systemctl status wg-quick@wg0

# 서비스 재시작
sudo systemctl restart wg-quick@wg0

# 연결된 클라이언트 확인
sudo wg show
```

### 백업 및 복원

```bash
# 설정 백업
./backup-wireguard.sh

# 설정 복원
./restore-wireguard.sh
```

## 연결 테스트

### 1. VPN 연결 확인

클라이언트에서 VPN 연결 후:

```bash
# 외부 IP 확인 (VPN 서버 IP와 동일해야 함)
curl ifconfig.me

# DNS 누수 테스트
nslookup google.com
```

### 2. 서버에서 연결 상태 확인

```bash
# 연결된 클라이언트 확인
sudo wg show

# 연결 통계
sudo wg show wg0 dump

# 로그 확인
journalctl -u wg-quick@wg0 -f
```

## 문제 해결

### 1. 연결이 안 되는 경우

**방화벽 확인:**
```bash
# 서버 방화벽 상태
sudo ufw status

# WireGuard 포트 확인
sudo netstat -ulnp | grep 51820
```

**AWS Lightsail 방화벽 확인:**
- 콘솔에서 UDP 51820 포트가 열려있는지 확인

### 2. DNS 문제

클라이언트 설정에서 DNS 서버 변경:
```ini
[Interface]
DNS = 8.8.8.8, 8.8.4.4  # Google DNS
# 또는
DNS = 1.1.1.1, 1.0.0.1  # Cloudflare DNS
```

### 3. 속도가 느린 경우

**MTU 조정:**
```bash
# 클라이언트 설정에 MTU 추가
[Interface]
MTU = 1420
```

**서버 성능 확인:**
```bash
# CPU 사용률
top

# 네트워크 사용률
iftop
```

### 4. 서비스 재시작

```bash
# WireGuard 완전 재시작
sudo systemctl stop wg-quick@wg0
sudo systemctl start wg-quick@wg0

# 설정 다시 로드
sudo wg-quick down wg0
sudo wg-quick up wg0
```

## 보안 권장사항

### 1. 정기적인 키 교체

```bash
# 3-6개월마다 서버 키 재생성 권장
sudo wg genkey > /etc/wireguard/server_private_new.key
sudo wg pubkey < /etc/wireguard/server_private_new.key > /etc/wireguard/server_public_new.key
```

### 2. 클라이언트 관리

- 사용하지 않는 클라이언트는 즉시 제거
- 직원 퇴사 시 관련 클라이언트 즉시 삭제
- 정기적으로 연결 로그 확인

### 3. 서버 보안

```bash
# 정기적인 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 로그 모니터링
tail -f /var/log/syslog | grep wireguard
```

### 4. 백업

- 주기적으로 설정 백업 실행
- 중요한 설정 변경 전 백업 생성
- 백업 파일은 안전한 별도 위치에 보관

## 비용 최적화

### AWS Lightsail 인스턴스 선택

- **개인 사용**: $5/월 (1GB RAM)
- **소규모 팀(~10명)**: $10/월 (2GB RAM)
- **중간 규모(~50명)**: $20/월 (4GB RAM)

### 데이터 전송 비용

- Lightsail은 월 데이터 전송량 포함
- $5 플랜: 1TB/월 포함
- 초과 시 $0.09/GB

## 추가 기능

### 1. 다중 서버 설정

여러 지역에 VPN 서버 구축 시:
- 각 서버마다 다른 서브넷 사용 (10.8.1.0/24, 10.8.2.0/24 등)
- 클라이언트에서 서버별 프로필 관리

### 2. 로드 밸런싱

트래픽 분산을 위한 설정:
```bash
# 클라이언트에서 여러 서버 설정
[Peer]
PublicKey = Server1PublicKey
Endpoint = server1.example.com:51820
AllowedIPs = 0.0.0.0/1

[Peer]
PublicKey = Server2PublicKey
Endpoint = server2.example.com:51820
AllowedIPs = 128.0.0.0/1
```

## 업데이트 및 유지보수

### 스크립트 업데이트

```bash
# 최신 스크립트 다운로드
wget -O wireguard-install-new.sh https://raw.githubusercontent.com/your-repo/wireguard-install.sh

# 백업 후 업데이트
./backup-wireguard.sh
sudo bash wireguard-install-new.sh
```

### WireGuard 업데이트

```bash
# 패키지 업데이트
sudo apt update
sudo apt upgrade wireguard wireguard-tools

# 서비스 재시작
sudo systemctl restart wg-quick@wg0
```

## 지원 및 문의

- **GitHub Issues**: 버그 리포트 및 기능 요청
- **Documentation**: 추가 설정 가이드
- **Community**: WireGuard 공식 커뮤니티

---

**주의사항**: 이 가이드는 AWS Lightsail Ubuntu 환경에 최적화되어 있습니다. 다른 플랫폼에서는 일부 명령어나 설정이 다를 수 있습니다.