#!/bin/bash

# n8n S3 백업 자동화를 위한 cron 작업 설정 스크립트
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

# 백업 스케줄 선택
select_backup_schedule() {
    echo -e "${BLUE}백업 스케줄을 선택하세요:${NC}"
    echo "1) 매일 새벽 2시 (권장)"
    echo "2) 매일 새벽 3시"
    echo "3) 매주 일요일 새벽 2시"
    echo "4) 매주 토요일 새벽 3시"
    echo "5) 사용자 정의"
    echo ""
    
    read -p "선택 (1-5): " schedule_choice
    
    case $schedule_choice in
        1)
            CRON_SCHEDULE="0 2 * * *"
            SCHEDULE_DESC="매일 새벽 2시"
            ;;
        2)
            CRON_SCHEDULE="0 3 * * *"
            SCHEDULE_DESC="매일 새벽 3시"
            ;;
        3)
            CRON_SCHEDULE="0 2 * * 0"
            SCHEDULE_DESC="매주 일요일 새벽 2시"
            ;;
        4)
            CRON_SCHEDULE="0 3 * * 6"
            SCHEDULE_DESC="매주 토요일 새벽 3시"
            ;;
        5)
            echo "Cron 표현식을 입력하세요 (예: 0 2 * * *):"
            read -p "Cron 표현식: " CRON_SCHEDULE
            read -p "스케줄 설명: " SCHEDULE_DESC
            ;;
        *)
            error "잘못된 선택입니다."
            ;;
    esac
    
    log "선택된 스케줄: $SCHEDULE_DESC ($CRON_SCHEDULE)"
}

# 백업 스크립트 경로 확인
verify_backup_script() {
    BACKUP_SCRIPT_PATH="$HOME/backup-n8n-s3.sh"
    
    if [ ! -f "$BACKUP_SCRIPT_PATH" ]; then
        warn "백업 스크립트를 찾을 수 없습니다: $BACKUP_SCRIPT_PATH"
        
        # 현재 디렉토리에서 백업 스크립트 찾기
        if [ -f "./backup-n8n-s3.sh" ]; then
            log "현재 디렉토리에서 백업 스크립트를 찾았습니다."
            cp "./backup-n8n-s3.sh" "$BACKUP_SCRIPT_PATH"
            chmod +x "$BACKUP_SCRIPT_PATH"
            log "백업 스크립트를 홈 디렉토리로 복사했습니다: $BACKUP_SCRIPT_PATH"
        else
            error "백업 스크립트(backup-n8n-s3.sh)를 찾을 수 없습니다."
        fi
    else
        log "백업 스크립트 확인: $BACKUP_SCRIPT_PATH"
        chmod +x "$BACKUP_SCRIPT_PATH"
    fi
}

# 로그 디렉토리 생성
create_log_directory() {
    LOG_DIR="$HOME/logs/backup"
    mkdir -p "$LOG_DIR"
    log "로그 디렉토리 생성: $LOG_DIR"
}

# cron 작업 추가
setup_cron_job() {
    log "cron 작업 설정 중..."
    
    # 현재 사용자의 crontab 백업
    crontab -l > /tmp/current_crontab 2>/dev/null || touch /tmp/current_crontab
    
    # 기존 백업 cron 작업 제거 (있다면)
    grep -v "backup-n8n-s3.sh" /tmp/current_crontab > /tmp/new_crontab
    
    # 새 cron 작업 추가
    echo "# n8n S3 자동 백업 - $SCHEDULE_DESC" >> /tmp/new_crontab
    echo "$CRON_SCHEDULE $BACKUP_SCRIPT_PATH >> $LOG_DIR/backup.log 2>&1" >> /tmp/new_crontab
    echo "" >> /tmp/new_crontab
    
    # 새 crontab 적용
    crontab /tmp/new_crontab
    
    # 임시 파일 정리
    rm /tmp/current_crontab /tmp/new_crontab
    
    log "cron 작업이 추가되었습니다."
}

# 로그 로테이션 설정
setup_log_rotation() {
    log "로그 로테이션 설정 중..."
    
    # logrotate 설정 파일 생성
    sudo tee /etc/logrotate.d/n8n-backup << EOF
$LOG_DIR/backup.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    copytruncate
}
EOF
    
    log "로그 로테이션 설정 완료 (30일 보관)"
}

# 이메일 알림 설정 (선택사항)
setup_email_notification() {
    echo ""
    read -p "백업 완료 시 이메일 알림을 받으시겠습니까? (y/n): " setup_email
    
    if [[ "$setup_email" =~ ^[Yy]$ ]]; then
        # mailutils 설치 확인
        if ! command -v mail &> /dev/null; then
            log "mailutils 패키지 설치 중..."
            sudo apt update && sudo apt install -y mailutils
        fi
        
        read -p "알림을 받을 이메일 주소를 입력하세요: " EMAIL_ADDRESS
        
        # 이메일 알림이 포함된 백업 스크립트 래퍼 생성
        cat > "$HOME/backup-n8n-s3-with-email.sh" << EOF
#!/bin/bash

# 백업 실행
$BACKUP_SCRIPT_PATH

# 백업 결과 확인
if [ \$? -eq 0 ]; then
    echo "n8n 백업이 성공적으로 완료되었습니다." | mail -s "n8n 백업 완료 - \$(date)" $EMAIL_ADDRESS
else
    echo "n8n 백업 중 오류가 발생했습니다. 로그를 확인해주세요." | mail -s "n8n 백업 실패 - \$(date)" $EMAIL_ADDRESS
fi
EOF
        
        chmod +x "$HOME/backup-n8n-s3-with-email.sh"
        
        # crontab 업데이트 (이메일 알림 포함)
        crontab -l | sed "s|$BACKUP_SCRIPT_PATH|$HOME/backup-n8n-s3-with-email.sh|g" | crontab -
        
        log "이메일 알림 설정 완료: $EMAIL_ADDRESS"
    fi
}

# 백업 테스트
test_backup() {
    echo ""
    read -p "지금 백업을 테스트하시겠습니까? (y/n): " test_now
    
    if [[ "$test_now" =~ ^[Yy]$ ]]; then
        log "백업 테스트 실행 중..."
        $BACKUP_SCRIPT_PATH
        
        if [ $? -eq 0 ]; then
            log "백업 테스트 성공!"
        else
            warn "백업 테스트 실패. 설정을 확인하세요."
        fi
    fi
}

# 설정 요약 표시
show_summary() {
    echo ""
    echo -e "${BLUE}=== 자동 백업 설정 요약 ===${NC}"
    echo "백업 스케줄: $SCHEDULE_DESC"
    echo "Cron 표현식: $CRON_SCHEDULE"
    echo "백업 스크립트: $BACKUP_SCRIPT_PATH"
    echo "로그 파일: $LOG_DIR/backup.log"
    echo ""
    echo -e "${GREEN}현재 설정된 cron 작업:${NC}"
    crontab -l | grep -A1 -B1 "backup-n8n-s3"
    echo ""
}

# 관리 스크립트 생성
create_management_script() {
    log "백업 관리 스크립트 생성 중..."
    
    cat > "$HOME/manage-n8n-backup.sh" << 'EOF'
#!/bin/bash

# n8n 백업 관리 스크립트

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

show_menu() {
    echo -e "${BLUE}=== n8n 백업 관리 ===${NC}"
    echo "1) 즉시 백업 실행"
    echo "2) 백업 로그 확인"
    echo "3) cron 작업 상태 확인"
    echo "4) cron 작업 제거"
    echo "5) S3 백업 목록 확인"
    echo "6) 종료"
    echo ""
}

while true; do
    show_menu
    read -p "선택 (1-6): " choice
    
    case $choice in
        1)
            echo -e "${GREEN}백업을 실행합니다...${NC}"
            $HOME/backup-n8n-s3.sh
            ;;
        2)
            echo -e "${GREEN}백업 로그:${NC}"
            tail -50 $HOME/logs/backup/backup.log 2>/dev/null || echo "로그 파일이 없습니다."
            ;;
        3)
            echo -e "${GREEN}cron 작업 상태:${NC}"
            crontab -l | grep -A1 -B1 "backup-n8n-s3" || echo "설정된 백업 cron 작업이 없습니다."
            ;;
        4)
            echo -e "${YELLOW}cron 작업을 제거합니다...${NC}"
            crontab -l | grep -v "backup-n8n-s3" | grep -v "n8n S3 자동 백업" | crontab -
            echo "cron 작업이 제거되었습니다."
            ;;
        5)
            if [ -f "$HOME/.s3-backup-config" ]; then
                source "$HOME/.s3-backup-config"
                echo -e "${GREEN}S3 백업 목록:${NC}"
                aws s3 ls "s3://$S3_BUCKET_NAME/" --recursive --human-readable
            else
                echo "S3 설정 파일을 찾을 수 없습니다."
            fi
            ;;
        6)
            echo "종료합니다."
            exit 0
            ;;
        *)
            echo -e "${RED}잘못된 선택입니다.${NC}"
            ;;
    esac
    
    echo ""
    read -p "계속하려면 Enter를 누르세요..."
    echo ""
done
EOF
    
    chmod +x "$HOME/manage-n8n-backup.sh"
    log "백업 관리 스크립트 생성 완료: $HOME/manage-n8n-backup.sh"
}

# 메인 실행 부분
log "n8n S3 백업 자동화 설정 시작..."

# 백업 스케줄 선택
select_backup_schedule

# 백업 스크립트 경로 확인
verify_backup_script

# 로그 디렉토리 생성
create_log_directory

# cron 작업 설정
setup_cron_job

# 로그 로테이션 설정
setup_log_rotation

# 이메일 알림 설정 (선택사항)
setup_email_notification

# 관리 스크립트 생성
create_management_script

# 설정 요약 표시
show_summary

# 백업 테스트
test_backup

log "n8n S3 백업 자동화 설정이 완료되었습니다!"
log "백업 관리는 다음 명령어로 실행하세요: $HOME/manage-n8n-backup.sh"