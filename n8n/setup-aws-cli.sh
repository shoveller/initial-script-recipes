#!/bin/bash

# AWS CLI 설치 및 설정 스크립트
# 작성자: Claude
# 날짜: 2025-06-22

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
    error "이 스크립트는 관리자 권한으로 실행해야 합니다. 'sudo bash setup-aws-cli.sh' 명령어를 사용하세요."
fi

# AWS CLI 설치
install_aws_cli() {
    log "AWS CLI 설치 중..."
    
    # 시스템 업데이트
    apt update
    
    # Python과 pip 설치
    apt install -y python3 python3-pip curl unzip
    
    # AWS CLI v2 설치
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    
    # 임시 파일 정리
    rm -rf awscliv2.zip aws/
    
    log "AWS CLI 설치 완료: $(aws --version)"
}

# AWS 자격 증명 설정
setup_aws_credentials() {
    log "AWS 자격 증명 설정..."
    
    echo "AWS IAM 사용자의 자격 증명을 입력하세요."
    echo "백업을 위해서는 S3에 대한 읽기/쓰기 권한이 필요합니다."
    echo ""
    
    read -p "AWS Access Key ID: " AWS_ACCESS_KEY_ID
    read -sp "AWS Secret Access Key: " AWS_SECRET_ACCESS_KEY
    echo
    read -p "Default region (예: ap-northeast-2): " AWS_DEFAULT_REGION
    read -p "Default output format (json 권장): " AWS_DEFAULT_OUTPUT
    
    # 기본값 설정
    if [ -z "$AWS_DEFAULT_OUTPUT" ]; then
        AWS_DEFAULT_OUTPUT="json"
    fi
    
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
    
    log "AWS 자격 증명 설정 완료"
}

# S3 버킷 생성 또는 확인
setup_s3_bucket() {
    log "S3 버킷 설정..."
    
    read -p "백업용 S3 버킷 이름을 입력하세요 (예: my-n8n-backup): " S3_BUCKET_NAME
    
    # 버킷 존재 여부 확인
    if sudo -u $SUDO_USER aws s3 ls "s3://$S3_BUCKET_NAME" 2>/dev/null; then
        log "S3 버킷 '$S3_BUCKET_NAME'이 이미 존재합니다."
    else
        log "S3 버킷 '$S3_BUCKET_NAME'을 생성합니다..."
        if sudo -u $SUDO_USER aws s3 mb "s3://$S3_BUCKET_NAME"; then
            log "S3 버킷 생성 완료"
        else
            error "S3 버킷 생성에 실패했습니다. 권한을 확인하세요."
        fi
    fi
    
    # 버킷 이름을 환경 변수 파일에 저장
    echo "S3_BUCKET_NAME=$S3_BUCKET_NAME" > /home/$SUDO_USER/.s3-backup-config
    chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.s3-backup-config
    
    log "S3 버킷 설정 완료"
}

# AWS CLI 테스트
test_aws_cli() {
    log "AWS CLI 연결 테스트 중..."
    
    # AWS 자격 증명 테스트
    if sudo -u $SUDO_USER aws sts get-caller-identity > /dev/null 2>&1; then
        log "AWS CLI 연결 테스트 성공"
        
        # 계정 정보 표시
        ACCOUNT_INFO=$(sudo -u $SUDO_USER aws sts get-caller-identity)
        echo -e "${BLUE}AWS 계정 정보:${NC}"
        echo "$ACCOUNT_INFO" | python3 -m json.tool
    else
        error "AWS CLI 연결 테스트 실패. 자격 증명을 확인하세요."
    fi
}

# 메인 실행 부분
log "AWS CLI 설치 및 설정 시작..."

# AWS CLI 설치
install_aws_cli

# AWS 자격 증명 설정
setup_aws_credentials

# S3 버킷 설정
setup_s3_bucket

# AWS CLI 테스트
test_aws_cli

log "AWS CLI 설치 및 설정이 완료되었습니다."
log "이제 S3 백업 스크립트를 실행할 수 있습니다."