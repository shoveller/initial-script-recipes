#!/bin/bash

# n8n 데이터 S3 백업 스크립트
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
load_config() {
    CONFIG_FILE="$HOME/.s3-backup-config"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log "설정 파일 로드 완료: $CONFIG_FILE"
    else
        error "설정 파일을 찾을 수 없습니다: $CONFIG_FILE"
    fi
}

# Docker 컨테이너 상태 확인
check_containers() {
    log "Docker 컨테이너 상태 확인 중..."
    
    # n8n 컨테이너 확인
    if ! docker ps | grep -q "n8n"; then
        warn "n8n 컨테이너가 실행 중이 아닙니다."
    else
        log "n8n 컨테이너가 실행 중입니다."
    fi
    
    # PostgreSQL 컨테이너 확인
    if ! docker ps | grep -q "n8n-db"; then
        warn "PostgreSQL 컨테이너가 실행 중이 아닙니다."
    else
        log "PostgreSQL 컨테이너가 실행 중입니다."
    fi
}

# n8n 데이터 백업
backup_n8n_data() {
    log "n8n 데이터 백업 시작..."
    
    # n8n 데이터 디렉토리 확인
    N8N_DATA_PATH="$HOME/docker/n8n/n8n_data"
    if [ ! -d "$N8N_DATA_PATH" ]; then
        error "n8n 데이터 디렉토리를 찾을 수 없습니다: $N8N_DATA_PATH"
    fi
    
    # 백업 파일 이름 생성
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    N8N_BACKUP_FILE="n8n_data_backup_${TIMESTAMP}.tar.gz"
    
    # n8n 데이터 압축
    log "n8n 데이터 압축 중..."
    cd "$HOME/docker/n8n"
    tar -czf "/tmp/$N8N_BACKUP_FILE" n8n_data/
    
    if [ $? -eq 0 ]; then
        log "n8n 데이터 압축 완료: $N8N_BACKUP_FILE"
    else
        error "n8n 데이터 압축 실패"
    fi
    
    # S3에 업로드
    log "n8n 데이터를 S3에 업로드 중..."
    aws s3 cp "/tmp/$N8N_BACKUP_FILE" "s3://$S3_BUCKET_NAME/n8n-backups/$N8N_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log "n8n 데이터 S3 업로드 완료"
        # 임시 파일 삭제
        rm "/tmp/$N8N_BACKUP_FILE"
        log "임시 백업 파일 삭제 완료"
    else
        error "n8n 데이터 S3 업로드 실패"
    fi
}

# PostgreSQL 데이터 백업
backup_postgres_data() {
    log "PostgreSQL 데이터 백업 시작..."
    
    # PostgreSQL 컨테이너가 실행 중인지 확인
    if ! docker ps | grep -q "n8n-db"; then
        error "PostgreSQL 컨테이너가 실행 중이 아닙니다. 먼저 컨테이너를 시작하세요."
    fi
    
    # 환경 변수 로드
    ENV_FILE="$HOME/docker/n8n/.env"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    else
        error "n8n 환경 변수 파일을 찾을 수 없습니다: $ENV_FILE"
    fi
    
    # 백업 파일 이름 생성
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    POSTGRES_BACKUP_FILE="postgres_backup_${TIMESTAMP}.sql"
    
    # PostgreSQL 데이터베이스 덤프
    log "PostgreSQL 데이터베이스 덤프 중..."
    docker exec n8n-db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" > "/tmp/$POSTGRES_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log "PostgreSQL 덤프 완료: $POSTGRES_BACKUP_FILE"
    else
        error "PostgreSQL 덤프 실패"
    fi
    
    # 덤프 파일 압축
    log "PostgreSQL 덤프 파일 압축 중..."
    gzip "/tmp/$POSTGRES_BACKUP_FILE"
    POSTGRES_BACKUP_FILE="${POSTGRES_BACKUP_FILE}.gz"
    
    # S3에 업로드
    log "PostgreSQL 백업을 S3에 업로드 중..."
    aws s3 cp "/tmp/$POSTGRES_BACKUP_FILE" "s3://$S3_BUCKET_NAME/postgres-backups/$POSTGRES_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log "PostgreSQL 백업 S3 업로드 완료"
        # 임시 파일 삭제
        rm "/tmp/$POSTGRES_BACKUP_FILE"
        log "임시 백업 파일 삭제 완료"
    else
        error "PostgreSQL 백업 S3 업로드 실패"
    fi
}

# Docker 볼륨 데이터 백업 (추가 방법)
backup_docker_volumes() {
    log "Docker 볼륨 데이터 백업 시작..."
    
    # 볼륨 목록 확인
    log "Docker 볼륨 목록:"
    docker volume ls | grep -E "(n8n|postgres)"
    
    # 백업 파일 이름 생성
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    VOLUME_BACKUP_FILE="docker_volumes_backup_${TIMESTAMP}.tar.gz"
    
    # Docker 볼륨 백업
    log "Docker 볼륨 백업 중..."
    
    # n8n 볼륨 백업
    if docker volume ls | grep -q "n8n_n8n_data"; then
        docker run --rm -v n8n_n8n_data:/data -v /tmp:/backup alpine tar czf /backup/n8n_volume_${TIMESTAMP}.tar.gz -C /data .
        
        # S3에 업로드
        aws s3 cp "/tmp/n8n_volume_${TIMESTAMP}.tar.gz" "s3://$S3_BUCKET_NAME/volume-backups/n8n_volume_${TIMESTAMP}.tar.gz"
        rm "/tmp/n8n_volume_${TIMESTAMP}.tar.gz"
        log "n8n 볼륨 백업 완료"
    fi
    
    # PostgreSQL 볼륨 백업
    if docker volume ls | grep -q "n8n_postgres_data"; then
        docker run --rm -v n8n_postgres_data:/data -v /tmp:/backup alpine tar czf /backup/postgres_volume_${TIMESTAMP}.tar.gz -C /data .
        
        # S3에 업로드
        aws s3 cp "/tmp/postgres_volume_${TIMESTAMP}.tar.gz" "s3://$S3_BUCKET_NAME/volume-backups/postgres_volume_${TIMESTAMP}.tar.gz"
        rm "/tmp/postgres_volume_${TIMESTAMP}.tar.gz"
        log "PostgreSQL 볼륨 백업 완료"
    fi
}

# 오래된 백업 파일 정리
cleanup_old_backups() {
    log "오래된 백업 파일 정리 시작..."
    
    # 30일 이상 된 백업 파일 삭제
    CLEANUP_DATE=$(date -d "30 days ago" '+%Y-%m-%d')
    
    log "30일 이전 백업 파일들을 정리합니다 (기준일: $CLEANUP_DATE)"
    
    # n8n 백업 정리
    aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" | while read -r line; do
        backup_date=$(echo $line | awk '{print $1}')
        backup_file=$(echo $line | awk '{print $4}')
        
        if [[ "$backup_date" < "$CLEANUP_DATE" ]]; then
            log "오래된 n8n 백업 파일 삭제: $backup_file"
            aws s3 rm "s3://$S3_BUCKET_NAME/n8n-backups/$backup_file"
        fi
    done
    
    # PostgreSQL 백업 정리
    aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" | while read -r line; do
        backup_date=$(echo $line | awk '{print $1}')
        backup_file=$(echo $line | awk '{print $4}')
        
        if [[ "$backup_date" < "$CLEANUP_DATE" ]]; then
            log "오래된 PostgreSQL 백업 파일 삭제: $backup_file"
            aws s3 rm "s3://$S3_BUCKET_NAME/postgres-backups/$backup_file"
        fi
    done
    
    log "오래된 백업 파일 정리 완료"
}

# 백업 상태 확인
check_backup_status() {
    log "백업 상태 확인..."
    
    # S3 버킷의 백업 파일 목록 확인
    echo -e "${BLUE}=== n8n 백업 파일 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" --human-readable
    
    echo -e "${BLUE}=== PostgreSQL 백업 파일 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" --human-readable
    
    echo -e "${BLUE}=== Docker 볼륨 백업 파일 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/volume-backups/" --human-readable
}

# 메인 실행 부분
log "n8n S3 백업 스크립트 시작..."

# 설정 파일 로드
load_config

# Docker 컨테이너 상태 확인
check_containers

# AWS CLI 연결 확인
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    error "AWS CLI 인증 실패. 자격 증명을 확인하세요."
fi

# 백업 실행
backup_n8n_data
backup_postgres_data
backup_docker_volumes

# 오래된 백업 파일 정리
cleanup_old_backups

# 백업 상태 확인
check_backup_status

log "n8n S3 백업 완료!"
log "백업된 파일들은 다음 위치에 저장되었습니다:"
log "  - n8n 데이터: s3://$S3_BUCKET_NAME/n8n-backups/"
log "  - PostgreSQL: s3://$S3_BUCKET_NAME/postgres-backups/"
log "  - Docker 볼륨: s3://$S3_BUCKET_NAME/volume-backups/"