#!/bin/bash

# AWS Lightsail에 n8n, Nginx Proxy Manager, OpenWebUI 설치 스크립트
# 작성자: Cline
# 날짜: 2025-06-08

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
    error "이 스크립트는 관리자 권한으로 실행해야 합니다. 'sudo bash n8n-install.sh' 명령어를 사용하세요."
fi

# 시스템 업데이트 및 기본 패키지 설치
log "시스템 업데이트 및 기본 패키지 설치 중..."
apt update && apt upgrade -y
apt install -y curl wget git nano unzip apt-transport-https ca-certificates gnupg lsb-release python3 python3-pip

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

# 캐시 메모리 설정 (4GB)
setup_swap() {
    log "4GB 스왑 메모리 설정 중..."

    # 기존 스왑 파일 확인 및 제거
    if [ -f /swapfile ]; then
        swapoff /swapfile
        rm /swapfile
    fi

    # 4GB 스왑 파일 생성
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile

    # 부팅 시 자동 마운트 설정
    if ! grep -q "/swapfile" /etc/fstab; then
        echo "/swapfile swap swap defaults 0 0" >> /etc/fstab
    fi

    # 스왑 설정 최적화
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    sysctl -p

    log "스왑 메모리 설정 완료: $(free -h | grep Swap)"
}

# Docker 설치
install_docker() {
    log "Docker 설치 중..."

    # 기존 Docker 제거
    apt remove -y docker docker-engine docker.io containerd runc || true

    # Docker 저장소 설정
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Docker 설치
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io

    # Docker Compose 설치
    log "Docker Compose 설치 중..."
    curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Docker 서비스 시작 및 자동 시작 설정
    systemctl start docker
    systemctl enable docker

    # 현재 사용자를 docker 그룹에 추가
    usermod -aG docker $SUDO_USER

    # Docker 소켓 권한 설정
    chmod 666 /var/run/docker.sock

    log "Docker 설치 완료: $(docker --version)"
    log "Docker Compose 설치 완료: $(docker-compose --version)"
    log "Docker 권한 설정 완료. 로그아웃 후 다시 로그인하면 sudo 없이 Docker 명령어를 사용할 수 있습니다."
}

# 기본 디렉토리 구조 생성
create_directory_structure() {
    log "디렉토리 구조 생성 중..."

    # 기본 디렉토리 생성
    mkdir -p /home/$SUDO_USER/docker/{n8n,npm,openwebui}

    # n8n 데이터 디렉토리
    mkdir -p /home/$SUDO_USER/docker/n8n/data
    mkdir -p /home/$SUDO_USER/docker/n8n/n8n_data

    # npm 데이터 디렉토리
    mkdir -p /home/$SUDO_USER/docker/npm/data
    mkdir -p /home/$SUDO_USER/docker/npm/letsencrypt
    mkdir -p /home/$SUDO_USER/docker/npm/mysql

    # openwebui 데이터 디렉토리
    mkdir -p /home/$SUDO_USER/docker/openwebui/data
    mkdir -p /home/$SUDO_USER/docker/openwebui/postgres

    # 권한 설정
    chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/docker

    log "디렉토리 구조 생성 완료"
}

# 환경 변수 설정
setup_environment() {
    log "환경 변수 설정 중..."

    # 도메인 설정
    read -p "n8n 웹훅 URL을 입력하세요 (예: https://n8n.example.com): " N8N_WEBHOOK_URL

    # URL에서 도메인 추출
    N8N_DOMAIN=$(echo $N8N_WEBHOOK_URL | sed -E 's|https?://||' | sed -E 's|:[0-9]+$||')

    # 암호화 키 생성
    N8N_ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')

    # PostgreSQL 비밀번호 생성
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')


    # n8n .env 파일 생성
    cat > /home/$SUDO_USER/docker/n8n/.env << EOF
# n8n 기본 설정
N8N_HOST=$N8N_DOMAIN
N8N_PORT=5678
N8N_PROTOCOL=https

# 보안을 위한 암호화 키
N8N_ENCRYPTION_KEY=$N8N_ENCRYPTION_KEY

# Webhook URL 설정
N8N_WEBHOOK_URL=$N8N_WEBHOOK_URL
WEBHOOK_URL=$N8N_WEBHOOK_URL

# PostgreSQL 데이터베이스 설정
POSTGRES_DB=n8n
POSTGRES_USER=n8n
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# 이메일 설정 (선택사항)
N8N_EMAIL_MODE=smtp
N8N_SMTP_HOST=
N8N_SMTP_PORT=587
N8N_SMTP_USER=
N8N_SMTP_PASS=
N8N_SMTP_SENDER=

# 프록시 및 보안 설정
N8N_TRUSTED_PROXIES=*
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
N8N_RUNNERS_ENABLED=true
EOF

    # OpenWebUI 환경 변수
    OPENWEBUI_DB_PASSWORD=$(openssl rand -base64 32 | tr -dc 'A-Za-z0-9')

    log "환경 변수 설정 완료"
}

# n8n Docker Compose 파일 생성
create_n8n_compose() {
    log "n8n Docker Compose 파일 생성 중..."

    cat > /home/$SUDO_USER/docker/n8n/docker-compose.yml << EOF
services:
  n8n:
    image: n8nio/n8n:latest
    restart: always
    container_name: n8n
    ports:
      - "\${N8N_PORT}:5678"
    environment:
      - N8N_HOST=\${N8N_HOST}
      - N8N_PORT=\${N8N_PORT}
      - N8N_PROTOCOL=\${N8N_PROTOCOL}
      - NODE_ENV=production
      - N8N_ENCRYPTION_KEY=\${N8N_ENCRYPTION_KEY}
      - N8N_WEBHOOK_URL=\${N8N_WEBHOOK_URL}
      - WEBHOOK_URL=\${WEBHOOK_URL}
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=\${POSTGRES_DB}
      - DB_POSTGRESDB_USER=\${POSTGRES_USER}
      - DB_POSTGRESDB_PASSWORD=\${POSTGRES_PASSWORD}
      - N8N_EMAIL_MODE=\${N8N_EMAIL_MODE}
      - N8N_SMTP_HOST=\${N8N_SMTP_HOST}
      - N8N_SMTP_PORT=\${N8N_SMTP_PORT}
      - N8N_SMTP_USER=\${N8N_SMTP_USER}
      - N8N_SMTP_PASS=\${N8N_SMTP_PASS}
      - N8N_SMTP_SENDER=\${N8N_SMTP_SENDER}
      - N8N_TRUSTED_PROXIES=*
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - N8N_RUNNERS_ENABLED=true
      - GENERIC_TIMEZONE=Asia/Seoul
      - PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
      - PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
      - N8N_BINARY_DATA_MODE=filesystem
      - N8N_TEMPLATES_ENABLED=true
      - N8N_PERSONALIZATION_ENABLED=false
    volumes:
      - ./n8n_data:/home/node/.n8n
    depends_on:
      - postgres
    networks:
      - n8n-network

  chrome:
    container_name: browserless_chrome
    image: browserless/chrome:latest
    restart: always
    ports:
      - "3000:3000"
    environment:
      - CONNECTION_TIMEOUT=600000
      - MAX_CONCURRENT_SESSIONS=5
      - TOKEN=
      - PREBOOT_CHROME=true
      - KEEP_ALIVE=true
      - DEBUG=false
    shm_size: 1gb
    networks:
      - n8n-network

  postgres:
    container_name: n8n-db
    image: postgres:14-alpine
    restart: always
    environment:
      - POSTGRES_DB=\${POSTGRES_DB}
      - POSTGRES_USER=\${POSTGRES_USER}
      - POSTGRES_PASSWORD=\${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - n8n-network
    ports:
      - "5432:5432"

volumes:
  n8n_data:
  postgres_data:

networks:
  n8n-network:
    driver: bridge
EOF

    log "n8n Docker Compose 파일 생성 완료"
}

# Nginx Proxy Manager Docker Compose 파일 생성
create_npm_compose() {
    log "Nginx Proxy Manager Docker Compose 파일 생성 중..."

    cat > /home/$SUDO_USER/docker/npm/docker-compose.yml << EOF
services:
  npm:
    container_name: npm
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '443:443'
      - '81:81'
    environment:
      DB_MYSQL_HOST: "db"
      DB_MYSQL_PORT: 3306
      DB_MYSQL_USER: "npm"
      DB_MYSQL_PASSWORD: "npm"
      DB_MYSQL_NAME: "npm"
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    depends_on:
      - db
  db:
    container_name: npm-db
    image: 'yobasystems/alpine-mariadb:latest'
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: 'npm'
      MYSQL_DATABASE: 'npm'
      MYSQL_USER: 'npm'
      MYSQL_PASSWORD: 'npm'
      TZ: Asia/Seoul
    volumes:
      - ./mysql:/var/lib/mysql
networks:
  default:
    name: npm
EOF

    log "Nginx Proxy Manager Docker Compose 파일 생성 완료"
}

# OpenWebUI Docker Compose 파일 생성
create_openwebui_compose() {
    log "OpenWebUI Docker Compose 파일 생성 중..."

    cat > /home/$SUDO_USER/docker/openwebui/docker-compose.yml << EOF
services:
  webui-db:
    container_name: open-webui-db
    image: postgres:13
    environment:
      - POSTGRES_DB=webui
      - POSTGRES_USER=webui
      - POSTGRES_PASSWORD=$OPENWEBUI_DB_PASSWORD
    ports:
      - "5433:5432"
    volumes:
      - ./postgres:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U webui -d webui -p 5432"]
      interval: 3s
      timeout: 5s
      retries: 5
    restart: always

  open-webui:
    container_name: open-webui
    image: ghcr.io/open-webui/open-webui:main
    depends_on:
      webui-db:
        condition: service_healthy
    ports:
      - "2000:8080"
    environment:
      - 'DATABASE_URL=postgresql://webui:$OPENWEBUI_DB_PASSWORD@webui-db:5432/webui'
    volumes:
      - ./data:/app/backend/data
    restart: unless-stopped

networks:
  default:
    driver: bridge
EOF

    log "OpenWebUI Docker Compose 파일 생성 완료"
}

# 설정 변경 스크립트 생성
create_config_scripts() {
    log "설정 변경 스크립트 생성 중..."

    # n8n 설정 변경 스크립트
    cat > /home/$SUDO_USER/docker/n8n/update-n8n-config.sh << EOF
#!/bin/bash

# n8n 설정 변경 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "\${GREEN}n8n 설정 변경 스크립트\${NC}"
echo "현재 설정을 불러오는 중..."

# .env 파일 경로
ENV_FILE=".env"

# .env 파일이 존재하는지 확인
if [ ! -f "\$ENV_FILE" ]; then
    echo -e "\${YELLOW}경고: .env 파일을 찾을 수 없습니다.\${NC}"
    exit 1
fi

# 현재 설정 불러오기
source "\$ENV_FILE"

# 메뉴 표시
echo "변경할 설정을 선택하세요:"
echo "1) N8N 웹훅 URL 변경"
echo "2) 이메일 설정 변경"
echo "3) 데이터베이스 비밀번호 변경"
echo "4) 종료"

read -p "선택 (1-4): " choice

case \$choice in
    1)
        read -p "새 웹훅 URL을 입력하세요 (예: https://n8n.example.com): " new_webhook
        # URL에서 도메인 추출
        new_domain=\$(echo \$new_webhook | sed -E 's|https?://||' | sed -E 's|:[0-9]+$||')

        # .env 파일 업데이트
        sed -i "s|N8N_HOST=.*|N8N_HOST=\$new_domain|" \$ENV_FILE
        sed -i "s|N8N_WEBHOOK_URL=.*|N8N_WEBHOOK_URL=\$new_webhook|" \$ENV_FILE
        sed -i "s|WEBHOOK_URL=.*|WEBHOOK_URL=\$new_webhook|" \$ENV_FILE

        echo -e "\${GREEN}웹훅 URL이 업데이트되었습니다.\${NC}"
        ;;
    2)
        read -p "SMTP 호스트 (예: smtp.gmail.com): " smtp_host
        read -p "SMTP 포트 (예: 587): " smtp_port
        read -p "SMTP 사용자 이메일: " smtp_user
        read -sp "SMTP 비밀번호: " smtp_pass
        echo
        read -p "발신자 이메일: " smtp_sender

        # .env 파일 업데이트
        sed -i "s|N8N_SMTP_HOST=.*|N8N_SMTP_HOST=\$smtp_host|" \$ENV_FILE
        sed -i "s|N8N_SMTP_PORT=.*|N8N_SMTP_PORT=\$smtp_port|" \$ENV_FILE
        sed -i "s|N8N_SMTP_USER=.*|N8N_SMTP_USER=\$smtp_user|" \$ENV_FILE
        sed -i "s|N8N_SMTP_PASS=.*|N8N_SMTP_PASS=\$smtp_pass|" \$ENV_FILE
        sed -i "s|N8N_SMTP_SENDER=.*|N8N_SMTP_SENDER=\$smtp_sender|" \$ENV_FILE

        echo -e "\${GREEN}이메일 설정이 업데이트되었습니다.\${NC}"
        ;;
    3)
        # 새 비밀번호 생성
        new_password=\$(openssl rand -base64 32)

        # .env 파일 업데이트
        sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=\$new_password|" \$ENV_FILE

        echo -e "\${GREEN}데이터베이스 비밀번호가 업데이트되었습니다.\${NC}"
        echo "새 비밀번호: \$new_password"
        echo "이 비밀번호를 안전한 곳에 보관하세요."
        ;;
    4)
        echo "종료합니다."
        exit 0
        ;;
    *)
        echo -e "\${YELLOW}잘못된 선택입니다. 다시 시도하세요.\${NC}"
        exit 1
        ;;
esac

echo "변경 사항을 적용하려면 n8n 서비스를 재시작하세요:"
echo "cd /home/\$USER/docker/n8n && docker-compose down && docker-compose up -d"
EOF

    # OpenWebUI 설정 변경 스크립트
    cat > /home/$SUDO_USER/docker/openwebui/update-openwebui-config.sh << EOF
#!/bin/bash

# OpenWebUI 설정 변경 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "\${GREEN}OpenWebUI 설정 변경 스크립트\${NC}"

# docker-compose.yml 파일 경로
COMPOSE_FILE="docker-compose.yml"

# docker-compose.yml 파일이 존재하는지 확인
if [ ! -f "\$COMPOSE_FILE" ]; then
    echo -e "\${YELLOW}경고: docker-compose.yml 파일을 찾을 수 없습니다.\${NC}"
    exit 1
fi

# 메뉴 표시
echo "변경할 설정을 선택하세요:"
echo "1) 데이터베이스 비밀번호 변경"
echo "2) 포트 변경"
echo "3) 종료"

read -p "선택 (1-3): " choice

case \$choice in
    1)
        # 새 비밀번호 생성
        new_password=\$(openssl rand -base64 12)

        # 현재 비밀번호 추출
        current_password=\$(grep -oP "POSTGRES_PASSWORD=\K[^'\"]*" \$COMPOSE_FILE | head -1)

        # docker-compose.yml 파일 업데이트
        sed -i "s|POSTGRES_PASSWORD=\$current_password|POSTGRES_PASSWORD=\$new_password|g" \$COMPOSE_FILE
        sed -i "s|postgresql://webui:\$current_password@|postgresql://webui:\$new_password@|g" \$COMPOSE_FILE

        echo -e "\${GREEN}데이터베이스 비밀번호가 업데이트되었습니다.\${NC}"
        echo "새 비밀번호: \$new_password"
        echo "이 비밀번호를 안전한 곳에 보관하세요."
        ;;
    2)
        read -p "새 포트 번호를 입력하세요 (현재: 2000): " new_port

        # docker-compose.yml 파일 업데이트
        sed -i "s|\"2000:8080\"|\"$new_port:8080\"|g" \$COMPOSE_FILE

        echo -e "\${GREEN}포트가 \$new_port로 업데이트되었습니다.\${NC}"
        ;;
    3)
        echo "종료합니다."
        exit 0
        ;;
    *)
        echo -e "\${YELLOW}잘못된 선택입니다. 다시 시도하세요.\${NC}"
        exit 1
        ;;
esac

echo "변경 사항을 적용하려면 OpenWebUI 서비스를 재시작하세요:"
echo "cd /home/\$USER/docker/openwebui && docker-compose down && docker-compose up -d"
EOF

    # 스크립트 실행 권한 부여
    chmod +x /home/$SUDO_USER/docker/n8n/update-n8n-config.sh
    chmod +x /home/$SUDO_USER/docker/openwebui/update-openwebui-config.sh

    log "설정 변경 스크립트 생성 완료"
}

# AWS CLI 설치 및 S3 백업 설정
setup_aws_backup() {
    echo ""
    read -p "S3 백업 기능을 설정하시겠습니까? (y/n): " setup_backup
    
    if [[ "$setup_backup" =~ ^[Yy]$ ]]; then
        log "AWS CLI 설치 및 S3 백업 설정 중..."
        
        # AWS CLI v2 설치
        log "AWS CLI 설치 중..."
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip -q awscliv2.zip
        ./aws/install
        rm -rf awscliv2.zip aws/
        log "AWS CLI 설치 완료: $(aws --version)"
        
        # AWS 자격 증명 설정
        log "AWS 자격 증명 설정..."
        echo "AWS IAM 사용자의 자격 증명을 입력하세요."
        echo "백업을 위해서는 S3에 대한 읽기/쓰기 권한이 필요합니다."
        echo ""
        
        read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
        read -p "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
        echo
        read -p "Default region (예: ap-northeast-2): " AWS_DEFAULT_REGION
        
        # 기본값 설정
        AWS_DEFAULT_OUTPUT="json"

        # AWS 자격 증명 파일 생성
        sudo -u $SUDO_USER mkdir -p /home/$SUDO_USER/.aws
        
        cat > /home/$SUDO_USER/.aws/credentials << EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
EOF
        
        cat > /home/$SUDO_USER/.aws/config << EOF
[default]
region = $AWS_DEFAULT_REGION
output = $AWS_DEFAULT_OUTPUT
EOF
        
        # 권한 설정
        chown -R $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.aws
        chmod 600 /home/$SUDO_USER/.aws/credentials
        chmod 600 /home/$SUDO_USER/.aws/config
        
        # S3 버킷 설정
        log "S3 버킷 설정..."
        
        # 고유한 버킷 이름 생성
        RANDOM_SUFFIX=$(openssl rand -hex 4)
        CURRENT_USER=$(whoami)
        SUGGESTED_BUCKET_NAME="n8n-backup-${CURRENT_USER}-${RANDOM_SUFFIX}"
        
        echo "S3 버킷 이름 규칙:"
        echo "- 3-63자 길이"
        echo "- 소문자, 숫자, 하이픈(-), 마침표(.)만 사용"
        echo "- 언더스코어(_) 사용 불가"
        echo "- 전 세계적으로 고유해야 함"
        echo ""
        read -p "백업용 S3 버킷 이름을 입력하세요 (기본값: ${SUGGESTED_BUCKET_NAME}): " S3_BUCKET_NAME
        
        # 기본값 설정
        if [ -z "$S3_BUCKET_NAME" ]; then
            S3_BUCKET_NAME="$SUGGESTED_BUCKET_NAME"
        fi
        
        # 버킷 존재 여부 확인 및 생성
        if sudo -u $SUDO_USER aws s3 ls "s3://$S3_BUCKET_NAME" 2>/dev/null; then
            log "S3 버킷 '$S3_BUCKET_NAME'이 이미 존재합니다."
        else
            log "S3 버킷 '$S3_BUCKET_NAME'을 생성합니다..."
            if sudo -u $SUDO_USER aws s3 mb "s3://$S3_BUCKET_NAME"; then
                log "S3 버킷 생성 완료"
            else
                warn "S3 버킷 생성에 실패했습니다. 수동으로 생성하거나 권한을 확인하세요."
            fi
        fi
        
        # 버킷 이름을 환경 변수 파일에 저장
        echo "S3_BUCKET_NAME=$S3_BUCKET_NAME" > /home/$SUDO_USER/.s3-backup-config
        chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.s3-backup-config
        
        # AWS CLI 연결 테스트
        log "AWS CLI 연결 테스트 중..."
        if sudo -u $SUDO_USER aws sts get-caller-identity > /dev/null 2>&1; then
            log "AWS CLI 연결 테스트 성공"
        else
            warn "AWS CLI 연결 테스트 실패. 나중에 자격 증명을 확인하세요."
        fi
        
        # 백업 스크립트 생성
        create_backup_scripts
        
        log "AWS CLI 및 S3 백업 설정 완료"
    else
        log "S3 백업 설정을 건너뜁니다."
    fi
}

# 백업 스크립트 생성
create_backup_scripts() {
    log "백업 스크립트 생성 중..."
    
    # n8n 백업 스크립트 생성
    cat > /home/$SUDO_USER/backup-n8n-s3.sh << 'EOF'
#!/bin/bash

# n8n 데이터 S3 백업 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# 설정 파일 로드
if [ -f "$HOME/.s3-backup-config" ]; then
    source "$HOME/.s3-backup-config"
else
    error "S3 백업 설정 파일을 찾을 수 없습니다: $HOME/.s3-backup-config"
fi

# AWS CLI 연결 확인
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    error "AWS CLI 인증 실패. 자격 증명을 확인하세요."
fi

log "n8n S3 백업 시작..."

# 백업 파일 이름 생성
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

# n8n 데이터 백업
if [ -d "$HOME/docker/n8n/n8n_data" ]; then
    log "n8n 데이터 백업 중..."
    cd "$HOME/docker/n8n"
    tar -czf "/tmp/n8n_data_backup_${TIMESTAMP}.tar.gz" n8n_data/
    
    # S3에 업로드
    aws s3 cp "/tmp/n8n_data_backup_${TIMESTAMP}.tar.gz" "s3://$S3_BUCKET_NAME/n8n-backups/"
    rm "/tmp/n8n_data_backup_${TIMESTAMP}.tar.gz"
    log "n8n 데이터 백업 완료"
fi

# PostgreSQL 데이터 백업
if docker ps | grep -q "n8n-db"; then
    log "PostgreSQL 데이터 백업 중..."
    
    # 환경 변수 로드
    source "$HOME/docker/n8n/.env"
    
    # PostgreSQL 덤프
    docker exec n8n-db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" | gzip > "/tmp/postgres_backup_${TIMESTAMP}.sql.gz"
    
    # S3에 업로드
    aws s3 cp "/tmp/postgres_backup_${TIMESTAMP}.sql.gz" "s3://$S3_BUCKET_NAME/postgres-backups/"
    rm "/tmp/postgres_backup_${TIMESTAMP}.sql.gz"
    log "PostgreSQL 백업 완료"
fi

# 30일 이상 된 백업 파일 정리
log "오래된 백업 파일 정리 중..."
CLEANUP_DATE=$(date -d "30 days ago" '+%Y-%m-%d')

aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" | while read -r line; do
    backup_date=$(echo $line | awk '{print $1}')
    backup_file=$(echo $line | awk '{print $4}')
    
    if [[ "$backup_date" < "$CLEANUP_DATE" ]] && [[ -n "$backup_file" ]]; then
        log "오래된 백업 파일 삭제: $backup_file"
        aws s3 rm "s3://$S3_BUCKET_NAME/n8n-backups/$backup_file"
    fi
done

aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" | while read -r line; do
    backup_date=$(echo $line | awk '{print $1}')
    backup_file=$(echo $line | awk '{print $4}')
    
    if [[ "$backup_date" < "$CLEANUP_DATE" ]] && [[ -n "$backup_file" ]]; then
        log "오래된 백업 파일 삭제: $backup_file"
        aws s3 rm "s3://$S3_BUCKET_NAME/postgres-backups/$backup_file"
    fi
done

log "n8n S3 백업 완료!"
EOF
    
    # 복원 스크립트 생성
    cat > /home/$SUDO_USER/restore-n8n-s3.sh << 'EOF'
#!/bin/bash

# n8n 데이터 S3 복원 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 설정 파일 로드
if [ -f "$HOME/.s3-backup-config" ]; then
    source "$HOME/.s3-backup-config"
else
    error "S3 백업 설정 파일을 찾을 수 없습니다"
fi

echo -e "${RED}경고: 이 작업은 기존 n8n 데이터를 완전히 대체합니다!${NC}"
read -p "정말로 복원을 진행하시겠습니까? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    log "복원이 취소되었습니다."
    exit 0
fi

# 사용 가능한 백업 목록 표시
echo -e "${BLUE}사용 가능한 백업 목록:${NC}"
echo "=== n8n 데이터 백업 ==="
aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" --human-readable | tail -10
echo "=== PostgreSQL 백업 ==="
aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" --human-readable | tail -10

echo ""
read -p "최신 백업으로 복원하시겠습니까? (y/n): " use_latest

if [[ "$use_latest" =~ ^[Yy]$ ]]; then
    # 최신 백업 파일 선택
    N8N_BACKUP_FILE=$(aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" | grep "\.tar\.gz$" | sort | tail -1 | awk '{print $4}')
    POSTGRES_BACKUP_FILE=$(aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" | grep "\.sql\.gz$" | sort | tail -1 | awk '{print $4}')
else
    read -p "n8n 백업 파일명을 입력하세요: " N8N_BACKUP_FILE
    read -p "PostgreSQL 백업 파일명을 입력하세요: " POSTGRES_BACKUP_FILE
fi

# 컨테이너 중지
log "n8n 컨테이너 중지 중..."
cd "$HOME/docker/n8n" && docker-compose down

# n8n 데이터 복원
if [ -n "$N8N_BACKUP_FILE" ]; then
    log "n8n 데이터 복원 중..."
    aws s3 cp "s3://$S3_BUCKET_NAME/n8n-backups/$N8N_BACKUP_FILE" "/tmp/"
    
    rm -rf "$HOME/docker/n8n/n8n_data"
    cd "$HOME/docker/n8n"
    tar -xzf "/tmp/$N8N_BACKUP_FILE"
    rm "/tmp/$N8N_BACKUP_FILE"
    log "n8n 데이터 복원 완료"
fi

# PostgreSQL 데이터 복원
if [ -n "$POSTGRES_BACKUP_FILE" ]; then
    log "PostgreSQL 데이터 복원 중..."
    aws s3 cp "s3://$S3_BUCKET_NAME/postgres-backups/$POSTGRES_BACKUP_FILE" "/tmp/"
    
    # PostgreSQL만 시작
    docker-compose up -d postgres
    sleep 10
    
    # 환경 변수 로드
    source "$HOME/docker/n8n/.env"
    
    # 데이터베이스 초기화 및 복원
    docker exec n8n-db psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    docker exec n8n-db psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB;"
    
    gunzip -c "/tmp/$POSTGRES_BACKUP_FILE" | docker exec -i n8n-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
    rm "/tmp/$POSTGRES_BACKUP_FILE"
    log "PostgreSQL 데이터 복원 완료"
fi

# 모든 서비스 재시작
log "n8n 서비스 재시작 중..."
docker-compose up -d

log "복원이 완료되었습니다!"
EOF
    
    # 백업 관리 스크립트 생성
    cat > /home/$SUDO_USER/manage-backup.sh << 'EOF'
#!/bin/bash

# n8n 백업 관리 스크립트

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

while true; do
    echo -e "${BLUE}=== n8n 백업 관리 ===${NC}"
    echo "1) 즉시 백업 실행"
    echo "2) S3 백업 목록 확인"
    echo "3) 데이터 복원"
    echo "4) 자동 백업 설정"
    echo "5) 종료"
    echo ""
    
    read -p "선택 (1-5): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}백업을 실행합니다...${NC}"
            $HOME/backup-n8n-s3.sh
            ;;
        2)
            if [ -f "$HOME/.s3-backup-config" ]; then
                source "$HOME/.s3-backup-config"
                echo -e "${GREEN}S3 백업 목록:${NC}"
                aws s3 ls "s3://$S3_BUCKET_NAME/" --recursive --human-readable
            else
                echo "S3 설정을 찾을 수 없습니다."
            fi
            ;;
        3)
            echo -e "${GREEN}데이터 복원을 시작합니다...${NC}"
            $HOME/restore-n8n-s3.sh
            ;;
        4)
            echo "자동 백업 설정 (매일 새벽 2시)"
            (crontab -l 2>/dev/null; echo "0 2 * * * $HOME/backup-n8n-s3.sh >> $HOME/backup.log 2>&1") | crontab -
            echo "자동 백업이 설정되었습니다."
            ;;
        5)
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
    
    # 스크립트 실행 권한 부여
    chmod +x /home/$SUDO_USER/backup-n8n-s3.sh
    chmod +x /home/$SUDO_USER/restore-n8n-s3.sh
    chmod +x /home/$SUDO_USER/manage-backup.sh
    
    log "백업 스크립트 생성 완료"
    log "백업 관리: $HOME/manage-backup.sh"
}

# 서비스 시작 스크립트 생성
create_start_script() {
    log "서비스 시작 스크립트 생성 중..."

    cat > /home/$SUDO_USER/docker/start-services.sh << EOF
#!/bin/bash

# 서비스 시작 스크립트

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "\${GREEN}서비스 시작 스크립트\${NC}"

# Nginx Proxy Manager 시작
echo "Nginx Proxy Manager 시작 중..."
cd /home/\$USER/docker/npm && docker-compose up -d
sleep 5

# n8n 시작
echo "n8n 시작 중..."
cd /home/\$USER/docker/n8n && docker-compose up -d
sleep 5

# OpenWebUI 시작
echo "OpenWebUI 시작 중..."
cd /home/\$USER/docker/openwebui && docker-compose up -d

echo -e "\${GREEN}모든 서비스가 시작되었습니다.\${NC}"
echo "Nginx Proxy Manager: http://your-server-ip:81"
echo "n8n: https://\$(grep N8N_HOST /home/\$USER/docker/n8n/.env | cut -d= -f2)"
echo "OpenWebUI: http://your-server-ip:2000"
EOF

    # 스크립트 실행 권한 부여
    chmod +x /home/$SUDO_USER/docker/start-services.sh

    log "서비스 시작 스크립트 생성 완료"
}

# 메인 실행 부분
log "AWS Lightsail에 n8n, Nginx Proxy Manager, OpenWebUI 설치 시작..."

# 관리자 패스워드 설정
setup_admin_password

# 스왑 메모리 설정
setup_swap

# Docker 설치
install_docker

# 디렉토리 구조 생성
create_directory_structure

# 환경 변수 설정
setup_environment

# Docker Compose 파일 생성
create_n8n_compose
create_npm_compose
create_openwebui_compose

# 설정 변경 스크립트 생성
create_config_scripts

# AWS 백업 설정
setup_aws_backup

# 서비스 시작 스크립트 생성
create_start_script

log "설치가 완료되었습니다."
log "서비스를 시작하려면 다음 명령어를 실행하세요:"
log "cd /home/$SUDO_USER/docker && ./start-services.sh"
log ""
log "백업 관리를 위해서는 다음 명령어를 사용하세요:"
log "./manage-backup.sh"
log ""
log "Docker 권한 문제가 있다면 다음 명령어를 실행하세요:"
log "sudo chmod 666 /var/run/docker.sock"