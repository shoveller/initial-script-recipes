#!/bin/bash

# AWS Lightsail에 WireGuard VPN 설치 스크립트
# 작성자: Claude Code
# 날짜: 2025-07-20
# 기반: n8n-install.sh

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 관리자 권한 확인
if [ "$EUID" -ne 0 ]; then
    error "이 스크립트는 관리자 권한으로 실행해야 합니다. 'sudo bash wireguard-install.sh' 명령어를 사용하세요."
fi

# WireGuard 설정 디렉토리
WG_CONFIG_DIR="/etc/wireguard"
WG_CLIENTS_DIR="/home/$SUDO_USER/wireguard-clients"

# 시스템 업데이트 및 기본 패키지 설치
install_packages() {
    log "시스템 업데이트 및 WireGuard 패키지 설치 중..."
    apt update && apt upgrade -y
    apt install -y wireguard wireguard-tools ufw qrencode curl wget git nano unzip
    
    # WireGuard 모듈 로드
    if ! lsmod | grep -q wireguard; then
        modprobe wireguard
        echo "wireguard" >> /etc/modules-load.d/wireguard.conf
    fi
    
    log "WireGuard 설치 완료: $(wg --version)"
}

# 관리자 패스워드 설정
setup_admin_password() {
    log "관리자 패스워드 설정..."
    read -sp "새 관리자 패스워드를 입력하세요: " ADMIN_PASSWORD
    echo
    read -sp "패스워드를 다시 입력하세요: " ADMIN_PASSWORD_CONFIRM
    echo

    if [ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_CONFIRM" ]; then
        error "패스워드가 일치하지 않습니다. 다시 시도하세요."
    fi

    echo "root:$ADMIN_PASSWORD" | chpasswd
    log "관리자 패스워드가 성공적으로 설정되었습니다."
}

# 네트워크 인터페이스 확인
get_network_interface() {
    # AWS Lightsail의 기본 인터페이스는 ens5
    NETWORK_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [ -z "$NETWORK_INTERFACE" ]; then
        NETWORK_INTERFACE="ens5"
        warn "기본 네트워크 인터페이스를 자동 감지하지 못했습니다. ens5를 사용합니다."
    fi
    log "네트워크 인터페이스: $NETWORK_INTERFACE"
}

# 서버 IP 주소 확인
get_server_ip() {
    # 외부 IP 주소 확인
    SERVER_IP=$(curl -s http://checkip.amazonaws.com/ || curl -s http://ipv4.icanhazip.com/ || curl -s http://ifconfig.me/ip)
    if [ -z "$SERVER_IP" ]; then
        error "서버의 외부 IP 주소를 확인할 수 없습니다."
    fi
    log "서버 외부 IP: $SERVER_IP"
    
    # Elastic IP 사용 권장 안내
    echo -e "${BLUE}[권장사항]${NC} AWS Lightsail에서 Elastic IP를 사용하는 것을 강력히 권장합니다."
    echo "Elastic IP를 사용하지 않으면 인스턴스 재시작 시 IP가 변경될 수 있습니다."
    echo ""
}

# IP 포워딩 활성화
enable_ip_forwarding() {
    log "IP 포워딩 활성화 중..."
    
    # IPv4 포워딩
    echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.conf
    echo 'net.ipv4.conf.all.forwarding = 1' >> /etc/sysctl.conf
    
    # IPv6 포워딩 (선택사항)
    echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.conf
    
    # 즉시 적용
    sysctl -p
    
    log "IP 포워딩이 활성화되었습니다."
}

# WireGuard 서버 키 생성
generate_server_keys() {
    log "WireGuard 서버 키 생성 중..."
    
    # 디렉토리 생성
    mkdir -p $WG_CONFIG_DIR
    chmod 700 $WG_CONFIG_DIR
    
    # 서버 개인키 생성
    wg genkey > $WG_CONFIG_DIR/server_private.key
    chmod 600 $WG_CONFIG_DIR/server_private.key
    
    # 서버 공개키 생성
    wg pubkey < $WG_CONFIG_DIR/server_private.key > $WG_CONFIG_DIR/server_public.key
    chmod 644 $WG_CONFIG_DIR/server_public.key
    
    SERVER_PRIVATE_KEY=$(cat $WG_CONFIG_DIR/server_private.key)
    SERVER_PUBLIC_KEY=$(cat $WG_CONFIG_DIR/server_public.key)
    
    log "서버 키 생성 완료"
}

# WireGuard 서버 설정
create_server_config() {
    log "WireGuard 서버 설정 파일 생성 중..."
    
    # 서버 설정 파일 생성
    cat > $WG_CONFIG_DIR/wg0.conf << EOF
[Interface]
PrivateKey = $SERVER_PRIVATE_KEY
Address = 10.8.0.1/24
ListenPort = 51820
SaveConfig = true

# NAT 규칙 설정
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o $NETWORK_INTERFACE -j MASQUERADE

# DNS 서버 설정 (Cloudflare DNS)
# DNS = 1.1.1.1, 1.0.0.1
EOF

    chmod 600 $WG_CONFIG_DIR/wg0.conf
    log "서버 설정 파일 생성 완료"
}

# 방화벽 설정 (ufw)
setup_firewall() {
    log "방화벽 설정 중..."
    
    # ufw 초기화
    ufw --force reset
    
    # 기본 정책 설정
    ufw default deny incoming
    ufw default allow outgoing
    
    # SSH 접속 허용 (현재 세션 보호)
    if [ -n "$SSH_CLIENT" ]; then
        SSH_CLIENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
        ufw allow from $SSH_CLIENT_IP to any port 22
        log "현재 SSH 연결 IP($SSH_CLIENT_IP)에서 SSH 접속을 허용했습니다."
    else
        ufw allow 22/tcp
        warn "SSH 클라이언트 IP를 확인할 수 없어 모든 IP에서 SSH를 허용했습니다."
    fi
    
    # WireGuard 포트 허용
    ufw allow 51820/udp
    
    # 방화벽 활성화
    ufw --force enable
    
    log "방화벽 설정 완료"
    
    # AWS Lightsail 방화벽 설정 안내
    echo -e "${BLUE}[중요]${NC} AWS Lightsail 콘솔에서 추가 방화벽 설정이 필요합니다:"
    echo "1. Lightsail 인스턴스 페이지로 이동"
    echo "2. 'Networking' 탭 클릭"
    echo "3. 'Firewall' 섹션에서 다음 규칙 추가:"
    echo "   - Application: Custom"
    echo "   - Protocol: UDP"
    echo "   - Port: 51820"
    echo "4. (선택사항) 보안을 위해 SSH(22/tcp) 규칙 삭제 가능"
    echo ""
}

# WireGuard 서비스 시작
start_wireguard() {
    log "WireGuard 서비스 시작 중..."
    
    # WireGuard 인터페이스 활성화
    systemctl enable wg-quick@wg0
    systemctl start wg-quick@wg0
    
    # 상태 확인
    if systemctl is-active --quiet wg-quick@wg0; then
        log "WireGuard 서비스가 성공적으로 시작되었습니다."
        log "WireGuard 상태: $(wg show)"
    else
        error "WireGuard 서비스 시작에 실패했습니다."
    fi
}

# 클라이언트 디렉토리 생성
create_client_directory() {
    log "클라이언트 설정 디렉토리 생성 중..."
    
    mkdir -p $WG_CLIENTS_DIR
    chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR
    chmod 700 $WG_CLIENTS_DIR
    
    # 클라이언트 관리 파일 생성
    echo "# WireGuard 클라이언트 목록" > $WG_CLIENTS_DIR/clients.txt
    echo "# 형식: 클라이언트명,IP주소,공개키,생성일시" >> $WG_CLIENTS_DIR/clients.txt
    
    chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR/clients.txt
    
    log "클라이언트 디렉토리 생성 완료: $WG_CLIENTS_DIR"
}

# 첫 번째 클라이언트 생성
create_first_client() {
    log "첫 번째 클라이언트 설정 생성 중..."
    
    read -p "첫 번째 클라이언트 이름을 입력하세요 (기본값: client1): " CLIENT_NAME
    if [ -z "$CLIENT_NAME" ]; then
        CLIENT_NAME="client1"
    fi
    
    # 클라이언트 키 생성
    CLIENT_PRIVATE_KEY=$(wg genkey)
    CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)
    CLIENT_IP="10.8.0.2"
    
    # 클라이언트 설정 파일 생성
    cat > $WG_CLIENTS_DIR/${CLIENT_NAME}.conf << EOF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

    chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
    
    # 서버에 클라이언트 추가
    wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32
    wg-quick save wg0
    
    # 클라이언트 목록에 추가
    echo "$CLIENT_NAME,$CLIENT_IP,$CLIENT_PUBLIC_KEY,$(date)" >> $WG_CLIENTS_DIR/clients.txt
    
    # QR 코드 생성
    qrencode -t ansiutf8 < $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
    qrencode -o $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png < $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
    chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png
    
    log "클라이언트 '$CLIENT_NAME' 생성 완료"
    log "설정 파일: $WG_CLIENTS_DIR/${CLIENT_NAME}.conf"
    log "QR 코드: $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png"
}

# 클라이언트 관리 스크립트 생성
create_client_management_scripts() {
    log "클라이언트 관리 스크립트 생성 중..."
    
    # 클라이언트 추가 스크립트
    cat > /home/$SUDO_USER/add-client.sh << 'EOF'
#!/bin/bash

# WireGuard 클라이언트 추가 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 관리자 권한 확인
if [ "$EUID" -ne 0 ]; then
    error "이 스크립트는 관리자 권한으로 실행해야 합니다."
fi

WG_CLIENTS_DIR="/home/$SUDO_USER/wireguard-clients"
SERVER_PUBLIC_KEY=$(cat /etc/wireguard/server_public.key)
SERVER_IP=$(curl -s http://checkip.amazonaws.com/)

# 클라이언트 이름 입력
read -p "새 클라이언트 이름을 입력하세요: " CLIENT_NAME
if [ -z "$CLIENT_NAME" ]; then
    error "클라이언트 이름이 필요합니다."
fi

# 중복 확인
if [ -f "$WG_CLIENTS_DIR/${CLIENT_NAME}.conf" ]; then
    error "클라이언트 '$CLIENT_NAME'이 이미 존재합니다."
fi

# 사용 가능한 IP 찾기
USED_IPS=$(grep -oP '\d+\.\d+\.\d+\.\d+' $WG_CLIENTS_DIR/clients.txt | cut -d. -f4 | sort -n | tail -1)
NEXT_IP=$((USED_IPS + 1))
CLIENT_IP="10.8.0.$NEXT_IP"

# 클라이언트 키 생성
CLIENT_PRIVATE_KEY=$(wg genkey)
CLIENT_PUBLIC_KEY=$(echo $CLIENT_PRIVATE_KEY | wg pubkey)

# 클라이언트 설정 파일 생성
cat > $WG_CLIENTS_DIR/${CLIENT_NAME}.conf << CONF
[Interface]
PrivateKey = $CLIENT_PRIVATE_KEY
Address = $CLIENT_IP/24
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
Endpoint = $SERVER_IP:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF

chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR/${CLIENT_NAME}.conf

# 서버에 클라이언트 추가
wg set wg0 peer $CLIENT_PUBLIC_KEY allowed-ips $CLIENT_IP/32
wg-quick save wg0

# 클라이언트 목록에 추가
echo "$CLIENT_NAME,$CLIENT_IP,$CLIENT_PUBLIC_KEY,$(date)" >> $WG_CLIENTS_DIR/clients.txt

# QR 코드 생성
qrencode -t ansiutf8 < $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
qrencode -o $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png < $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
chown $SUDO_USER:$SUDO_USER $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png

log "클라이언트 '$CLIENT_NAME' 추가 완료"
log "설정 파일: $WG_CLIENTS_DIR/${CLIENT_NAME}.conf"
log "QR 코드: $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png"
EOF

    # 클라이언트 제거 스크립트
    cat > /home/$SUDO_USER/remove-client.sh << 'EOF'
#!/bin/bash

# WireGuard 클라이언트 제거 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# 관리자 권한 확인
if [ "$EUID" -ne 0 ]; then
    error "이 스크립트는 관리자 권한으로 실행해야 합니다."
fi

WG_CLIENTS_DIR="/home/$SUDO_USER/wireguard-clients"

# 현재 클라이언트 목록 표시
echo "현재 등록된 클라이언트:"
cat $WG_CLIENTS_DIR/clients.txt | grep -v "^#" | nl

read -p "제거할 클라이언트 이름을 입력하세요: " CLIENT_NAME
if [ -z "$CLIENT_NAME" ]; then
    error "클라이언트 이름이 필요합니다."
fi

# 클라이언트 존재 확인
if [ ! -f "$WG_CLIENTS_DIR/${CLIENT_NAME}.conf" ]; then
    error "클라이언트 '$CLIENT_NAME'을 찾을 수 없습니다."
fi

# 클라이언트 공개키 추출
CLIENT_PUBLIC_KEY=$(grep -oP 'PublicKey = \K.*' $WG_CLIENTS_DIR/clients.txt | grep $CLIENT_NAME)

# 서버에서 클라이언트 제거
wg set wg0 peer $CLIENT_PUBLIC_KEY remove
wg-quick save wg0

# 클라이언트 파일 삭제
rm -f $WG_CLIENTS_DIR/${CLIENT_NAME}.conf
rm -f $WG_CLIENTS_DIR/${CLIENT_NAME}_qr.png

# 클라이언트 목록에서 제거
sed -i "/$CLIENT_NAME,/d" $WG_CLIENTS_DIR/clients.txt

log "클라이언트 '$CLIENT_NAME' 제거 완료"
EOF

    # 클라이언트 목록 스크립트
    cat > /home/$SUDO_USER/list-clients.sh << 'EOF'
#!/bin/bash

# WireGuard 클라이언트 목록 조회 스크립트

WG_CLIENTS_DIR="/home/$SUDO_USER/wireguard-clients"

echo "=== WireGuard 클라이언트 목록 ==="
if [ -f "$WG_CLIENTS_DIR/clients.txt" ]; then
    echo "클라이언트명 | IP주소 | 생성일시"
    echo "----------------------------------------"
    grep -v "^#" $WG_CLIENTS_DIR/clients.txt | while IFS=',' read -r name ip pubkey date; do
        echo "$name | $ip | $date"
    done
else
    echo "클라이언트 목록 파일을 찾을 수 없습니다."
fi

echo ""
echo "=== 현재 연결된 클라이언트 ==="
wg show wg0
EOF

    # 스크립트 실행 권한 부여
    chmod +x /home/$SUDO_USER/add-client.sh
    chmod +x /home/$SUDO_USER/remove-client.sh
    chmod +x /home/$SUDO_USER/list-clients.sh
    
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/add-client.sh
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/remove-client.sh
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/list-clients.sh
    
    log "클라이언트 관리 스크립트 생성 완료"
}

# 서비스 관리 스크립트 생성
create_service_scripts() {
    log "서비스 관리 스크립트 생성 중..."
    
    # WireGuard 서비스 관리 스크립트
    cat > /home/$SUDO_USER/manage-wireguard.sh << 'EOF'
#!/bin/bash

# WireGuard 서비스 관리 스크립트

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m'

while true; do
    echo -e "${BLUE}=== WireGuard VPN 관리 ===${NC}"
    echo "1) 서비스 상태 확인"
    echo "2) 서비스 시작"
    echo "3) 서비스 중지"
    echo "4) 서비스 재시작"
    echo "5) 클라이언트 목록"
    echo "6) 연결 통계"
    echo "7) 로그 보기"
    echo "8) 종료"
    echo ""
    
    read -p "선택 (1-8): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}WireGuard 서비스 상태:${NC}"
            systemctl status wg-quick@wg0
            echo ""
            echo -e "${GREEN}WireGuard 인터페이스 상태:${NC}"
            wg show
            ;;
        2)
            echo -e "${GREEN}WireGuard 서비스 시작...${NC}"
            sudo systemctl start wg-quick@wg0
            ;;
        3)
            echo -e "${YELLOW}WireGuard 서비스 중지...${NC}"
            sudo systemctl stop wg-quick@wg0
            ;;
        4)
            echo -e "${GREEN}WireGuard 서비스 재시작...${NC}"
            sudo systemctl restart wg-quick@wg0
            ;;
        5)
            ./list-clients.sh
            ;;
        6)
            echo -e "${GREEN}연결 통계:${NC}"
            wg show wg0 dump
            ;;
        7)
            echo -e "${GREEN}최근 로그:${NC}"
            journalctl -u wg-quick@wg0 -n 20 --no-pager
            ;;
        8)
            echo "종료합니다."
            exit 0
            ;;
        *)
            echo "잘못된 선택입니다."
            ;;
    esac
    
    echo ""
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
done
EOF

    chmod +x /home/$SUDO_USER/manage-wireguard.sh
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/manage-wireguard.sh
    
    log "서비스 관리 스크립트 생성 완료"
}

# 백업 및 복원 스크립트 생성
create_backup_scripts() {
    log "백업 및 복원 스크립트 생성 중..."
    
    # 백업 스크립트
    cat > /home/$SUDO_USER/backup-wireguard.sh << 'EOF'
#!/bin/bash

# WireGuard 설정 백업 스크립트

BACKUP_DIR="/home/$USER/wireguard-backup"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
BACKUP_FILE="wireguard_backup_${TIMESTAMP}.tar.gz"

echo "WireGuard 설정 백업 중..."

# 백업 디렉토리 생성
mkdir -p $BACKUP_DIR

# 설정 파일 백업
sudo tar -czf $BACKUP_DIR/$BACKUP_FILE \
    /etc/wireguard/ \
    /home/$USER/wireguard-clients/ \
    /home/$USER/*.sh 2>/dev/null

sudo chown $USER:$USER $BACKUP_DIR/$BACKUP_FILE

echo "백업 완료: $BACKUP_DIR/$BACKUP_FILE"

# 오래된 백업 파일 정리 (30일 이상)
find $BACKUP_DIR -name "wireguard_backup_*.tar.gz" -mtime +30 -delete
EOF

    # 복원 스크립트
    cat > /home/$SUDO_USER/restore-wireguard.sh << 'EOF'
#!/bin/bash

# WireGuard 설정 복원 스크립트

BACKUP_DIR="/home/$USER/wireguard-backup"

echo "사용 가능한 백업 파일:"
ls -la $BACKUP_DIR/wireguard_backup_*.tar.gz 2>/dev/null || {
    echo "백업 파일을 찾을 수 없습니다."
    exit 1
}

read -p "복원할 백업 파일명을 입력하세요: " BACKUP_FILE

if [ ! -f "$BACKUP_DIR/$BACKUP_FILE" ]; then
    echo "백업 파일을 찾을 수 없습니다."
    exit 1
fi

echo -e "\033[0;31m경고: 현재 설정이 모두 삭제됩니다!\033[0m"
read -p "정말로 복원하시겠습니까? (yes/no): " confirm

if [ "$confirm" = "yes" ]; then
    # 서비스 중지
    sudo systemctl stop wg-quick@wg0
    
    # 설정 복원
    sudo tar -xzf $BACKUP_DIR/$BACKUP_FILE -C /
    
    # 서비스 재시작
    sudo systemctl start wg-quick@wg0
    
    echo "복원이 완료되었습니다."
else
    echo "복원이 취소되었습니다."
fi
EOF

    chmod +x /home/$SUDO_USER/backup-wireguard.sh
    chmod +x /home/$SUDO_USER/restore-wireguard.sh
    
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/backup-wireguard.sh
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/restore-wireguard.sh
    
    log "백업 및 복원 스크립트 생성 완료"
}

# 메인 실행 부분
main() {
    log "AWS Lightsail에 WireGuard VPN 설치 시작..."
    
    # 관리자 패스워드 설정
    setup_admin_password
    
    # 시스템 패키지 설치
    install_packages
    
    # 네트워크 설정
    get_network_interface
    get_server_ip
    enable_ip_forwarding
    
    # WireGuard 설정
    generate_server_keys
    create_server_config
    
    # 방화벽 설정
    setup_firewall
    
    # WireGuard 서비스 시작
    start_wireguard
    
    # 클라이언트 관리
    create_client_directory
    create_first_client
    create_client_management_scripts
    
    # 관리 도구 생성
    create_service_scripts
    create_backup_scripts
    
    log "WireGuard VPN 설치가 완료되었습니다!"
    echo ""
    echo -e "${BLUE}=== 설치 완료 정보 ===${NC}"
    echo "서버 IP: $SERVER_IP"
    echo "WireGuard 포트: 51820/UDP"
    echo "클라이언트 설정: $WG_CLIENTS_DIR/"
    echo ""
    echo -e "${BLUE}=== 관리 명령어 ===${NC}"
    echo "클라이언트 추가: sudo ./add-client.sh"
    echo "클라이언트 제거: sudo ./remove-client.sh"
    echo "클라이언트 목록: ./list-clients.sh"
    echo "서비스 관리: ./manage-wireguard.sh"
    echo "설정 백업: ./backup-wireguard.sh"
    echo ""
    echo -e "${YELLOW}[중요]${NC} AWS Lightsail 콘솔에서 UDP 포트 51820을 허용해야 합니다!"
    echo ""
}

# 실행
main