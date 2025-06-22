#!/bin/bash

# n8n 데이터 S3 복원 스크립트
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

# 복원 전 확인
pre_restore_check() {
    echo -e "${RED}경고: 이 스크립트는 기존 n8n 데이터를 백업된 데이터로 완전히 대체합니다.${NC}"
    echo -e "${RED}기존 데이터는 복구할 수 없습니다.${NC}"
    echo ""
    
    read -p "정말로 복원을 진행하시겠습니까? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log "복원이 취소되었습니다."
        exit 0
    fi
    
    # 현재 실행 중인 컨테이너 확인
    if docker ps | grep -q "n8n\|n8n-db"; then
        warn "n8n 관련 컨테이너가 실행 중입니다. 복원을 위해 컨테이너를 중지해야 합니다."
        read -p "컨테이너를 중지하시겠습니까? (y/n): " stop_containers
        
        if [[ "$stop_containers" =~ ^[Yy]$ ]]; then
            log "n8n 컨테이너들을 중지합니다..."
            cd "$HOME/docker/n8n" && docker-compose down
            sleep 5
        else
            error "복원을 위해서는 컨테이너를 중지해야 합니다."
        fi
    fi
}

# S3에서 백업 목록 확인
list_available_backups() {
    log "S3에서 사용 가능한 백업 목록을 확인합니다..."
    
    echo -e "${BLUE}=== n8n 데이터 백업 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" --human-readable | grep "\.tar\.gz$" | tail -10
    
    echo -e "${BLUE}=== PostgreSQL 백업 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" --human-readable | grep "\.sql\.gz$" | tail -10
    
    echo -e "${BLUE}=== Docker 볼륨 백업 목록 ===${NC}"
    aws s3 ls "s3://$S3_BUCKET_NAME/volume-backups/" --human-readable | grep "\.tar\.gz$" | tail -10
}

# 복원할 백업 파일 선택
select_backup_files() {
    echo ""
    echo "복원 방법을 선택하세요:"
    echo "1) 최신 백업으로 복원"
    echo "2) 특정 백업 파일 선택"
    echo "3) 백업 목록 다시 보기"
    echo ""
    
    read -p "선택 (1-3): " restore_choice
    
    case $restore_choice in
        1)
            log "최신 백업 파일들을 선택합니다..."
            
            # 최신 n8n 백업 파일
            N8N_BACKUP_FILE=$(aws s3 ls "s3://$S3_BUCKET_NAME/n8n-backups/" | grep "\.tar\.gz$" | sort | tail -1 | awk '{print $4}')
            
            # 최신 PostgreSQL 백업 파일
            POSTGRES_BACKUP_FILE=$(aws s3 ls "s3://$S3_BUCKET_NAME/postgres-backups/" | grep "\.sql\.gz$" | sort | tail -1 | awk '{print $4}')
            
            if [ -z "$N8N_BACKUP_FILE" ] || [ -z "$POSTGRES_BACKUP_FILE" ]; then
                error "백업 파일을 찾을 수 없습니다."
            fi
            
            log "선택된 n8n 백업: $N8N_BACKUP_FILE"
            log "선택된 PostgreSQL 백업: $POSTGRES_BACKUP_FILE"
            ;;
        2)
            echo "n8n 백업 파일명을 입력하세요:"
            read -p "n8n 백업 파일: " N8N_BACKUP_FILE
            
            echo "PostgreSQL 백업 파일명을 입력하세요:"
            read -p "PostgreSQL 백업 파일: " POSTGRES_BACKUP_FILE
            ;;
        3)
            list_available_backups
            select_backup_files
            return
            ;;
        *)
            error "잘못된 선택입니다."
            ;;
    esac
}

# 기존 데이터 백업
backup_current_data() {
    log "복원 전 현재 데이터를 백업합니다..."
    
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    BACKUP_DIR="/tmp/n8n_pre_restore_backup_$TIMESTAMP"
    mkdir -p "$BACKUP_DIR"
    
    # 현재 n8n 데이터 백업
    if [ -d "$HOME/docker/n8n/n8n_data" ]; then
        log "현재 n8n 데이터 백업 중..."
        cp -r "$HOME/docker/n8n/n8n_data" "$BACKUP_DIR/"
        log "현재 n8n 데이터 백업 완료: $BACKUP_DIR/n8n_data"
    fi
    
    # Docker 볼륨도 백업 (있다면)
    if docker volume ls | grep -q "n8n_n8n_data"; then
        log "현재 n8n Docker 볼륨 백업 중..."
        docker run --rm -v n8n_n8n_data:/data -v "$BACKUP_DIR":/backup alpine cp -r /data /backup/n8n_volume_data
        log "현재 n8n Docker 볼륨 백업 완료: $BACKUP_DIR/n8n_volume_data"
    fi
    
    log "복원 전 백업 완료: $BACKUP_DIR"
    echo "복원에 문제가 있을 경우 이 백업을 사용할 수 있습니다."
}

# n8n 데이터 복원
restore_n8n_data() {
    log "n8n 데이터 복원 시작..."
    
    # S3에서 백업 파일 다운로드
    log "S3에서 n8n 백업 파일 다운로드 중: $N8N_BACKUP_FILE"
    aws s3 cp "s3://$S3_BUCKET_NAME/n8n-backups/$N8N_BACKUP_FILE" "/tmp/$N8N_BACKUP_FILE"
    
    if [ $? -ne 0 ]; then
        error "n8n 백업 파일 다운로드에 실패했습니다."
    fi
    
    # 기존 n8n 데이터 디렉토리 제거
    if [ -d "$HOME/docker/n8n/n8n_data" ]; then
        log "기존 n8n 데이터 디렉토리 제거 중..."
        rm -rf "$HOME/docker/n8n/n8n_data"
    fi
    
    # 백업 파일 압축 해제
    log "n8n 백업 파일 압축 해제 중..."
    cd "$HOME/docker/n8n"
    tar -xzf "/tmp/$N8N_BACKUP_FILE"
    
    if [ $? -eq 0 ]; then
        log "n8n 데이터 복원 완료"
        rm "/tmp/$N8N_BACKUP_FILE"
    else
        error "n8n 데이터 복원에 실패했습니다."
    fi
}

# PostgreSQL 데이터 복원
restore_postgres_data() {
    log "PostgreSQL 데이터 복원 시작..."
    
    # 환경 변수 로드
    ENV_FILE="$HOME/docker/n8n/.env"
    if [ -f "$ENV_FILE" ]; then
        source "$ENV_FILE"
    else
        error "n8n 환경 변수 파일을 찾을 수 없습니다: $ENV_FILE"
    fi
    
    # S3에서 백업 파일 다운로드
    log "S3에서 PostgreSQL 백업 파일 다운로드 중: $POSTGRES_BACKUP_FILE"
    aws s3 cp "s3://$S3_BUCKET_NAME/postgres-backups/$POSTGRES_BACKUP_FILE" "/tmp/$POSTGRES_BACKUP_FILE"
    
    if [ $? -ne 0 ]; then
        error "PostgreSQL 백업 파일 다운로드에 실패했습니다."
    fi
    
    # 압축 해제
    log "PostgreSQL 백업 파일 압축 해제 중..."
    gunzip "/tmp/$POSTGRES_BACKUP_FILE"
    POSTGRES_SQL_FILE="/tmp/$(basename "$POSTGRES_BACKUP_FILE" .gz)"
    
    # PostgreSQL 컨테이너 시작 (데이터베이스 복원을 위해)
    log "PostgreSQL 컨테이너 시작 중..."
    cd "$HOME/docker/n8n"
    docker-compose up -d postgres
    
    # PostgreSQL이 준비될 때까지 대기
    log "PostgreSQL이 준비될 때까지 대기 중..."
    sleep 10
    
    # 기존 데이터베이스 삭제 및 재생성
    log "기존 데이터베이스 초기화 중..."
    docker exec n8n-db psql -U "$POSTGRES_USER" -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"
    docker exec n8n-db psql -U "$POSTGRES_USER" -c "CREATE DATABASE $POSTGRES_DB;"
    
    # 백업 데이터 복원
    log "PostgreSQL 데이터 복원 중..."
    docker exec -i n8n-db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" < "$POSTGRES_SQL_FILE"
    
    if [ $? -eq 0 ]; then
        log "PostgreSQL 데이터 복원 완료"
        rm "$POSTGRES_SQL_FILE"
    else
        error "PostgreSQL 데이터 복원에 실패했습니다."
    fi
}

# Docker 볼륨 복원 (선택사항)
restore_docker_volumes() {
    echo ""
    read -p "Docker 볼륨도 복원하시겠습니까? (y/n): " restore_volumes
    
    if [[ "$restore_volumes" =~ ^[Yy]$ ]]; then
        log "Docker 볼륨 복원 시작..."
        
        # 사용 가능한 볼륨 백업 목록 확인
        echo -e "${BLUE}사용 가능한 볼륨 백업:${NC}"
        aws s3 ls "s3://$S3_BUCKET_NAME/volume-backups/" | grep "\.tar\.gz$" | tail -5
        
        echo ""
        read -p "복원할 n8n 볼륨 백업 파일명을 입력하세요 (선택사항): " N8N_VOLUME_FILE
        read -p "복원할 PostgreSQL 볼륨 백업 파일명을 입력하세요 (선택사항): " POSTGRES_VOLUME_FILE
        
        # n8n 볼륨 복원
        if [ -n "$N8N_VOLUME_FILE" ]; then
            log "n8n Docker 볼륨 복원 중..."
            aws s3 cp "s3://$S3_BUCKET_NAME/volume-backups/$N8N_VOLUME_FILE" "/tmp/$N8N_VOLUME_FILE"
            
            # 기존 볼륨 제거 및 재생성
            docker volume rm n8n_n8n_data 2>/dev/null || true
            docker volume create n8n_n8n_data
            
            # 볼륨 데이터 복원
            docker run --rm -v n8n_n8n_data:/data -v /tmp:/backup alpine tar xzf "/backup/$N8N_VOLUME_FILE" -C /data
            rm "/tmp/$N8N_VOLUME_FILE"
            log "n8n Docker 볼륨 복원 완료"
        fi
        
        # PostgreSQL 볼륨 복원
        if [ -n "$POSTGRES_VOLUME_FILE" ]; then
            log "PostgreSQL Docker 볼륨 복원 중..."
            aws s3 cp "s3://$S3_BUCKET_NAME/volume-backups/$POSTGRES_VOLUME_FILE" "/tmp/$POSTGRES_VOLUME_FILE"
            
            # 기존 볼륨 제거 및 재생성
            docker volume rm n8n_postgres_data 2>/dev/null || true
            docker volume create n8n_postgres_data
            
            # 볼륨 데이터 복원
            docker run --rm -v n8n_postgres_data:/data -v /tmp:/backup alpine tar xzf "/backup/$POSTGRES_VOLUME_FILE" -C /data
            rm "/tmp/$POSTGRES_VOLUME_FILE"
            log "PostgreSQL Docker 볼륨 복원 완료"
        fi
    fi
}

# 서비스 재시작
restart_services() {
    log "n8n 서비스 재시작 중..."
    
    cd "$HOME/docker/n8n"
    
    # 모든 컨테이너 중지
    docker-compose down
    
    # 잠시 대기
    sleep 5
    
    # 서비스 재시작
    docker-compose up -d
    
    log "n8n 서비스 재시작 완료"
    
    # 서비스 상태 확인
    sleep 10
    log "서비스 상태 확인 중..."
    docker-compose ps
}

# 복원 검증
verify_restore() {
    log "복원 검증 중..."
    
    # n8n 컨테이너 상태 확인
    if docker ps | grep -q "n8n"; then
        log "✓ n8n 컨테이너가 정상적으로 실행 중입니다."
    else
        warn "✗ n8n 컨테이너가 실행되지 않았습니다."
    fi
    
    # PostgreSQL 컨테이너 상태 확인
    if docker ps | grep -q "n8n-db"; then
        log "✓ PostgreSQL 컨테이너가 정상적으로 실행 중입니다."
    else
        warn "✗ PostgreSQL 컨테이너가 실행되지 않았습니다."
    fi
    
    # n8n 데이터 디렉토리 확인
    if [ -d "$HOME/docker/n8n/n8n_data" ]; then
        log "✓ n8n 데이터 디렉토리가 존재합니다."
        log "데이터 크기: $(du -sh "$HOME/docker/n8n/n8n_data" | cut -f1)"
    else
        warn "✗ n8n 데이터 디렉토리를 찾을 수 없습니다."
    fi
    
    echo ""
    log "복원이 완료되었습니다."
    log "n8n 웹 인터페이스에 접속하여 데이터가 정상적으로 복원되었는지 확인하세요."
}

# 복원 완료 후 정리
cleanup_after_restore() {
    log "복원 후 정리 작업 중..."
    
    # 임시 파일 정리
    rm -f /tmp/n8n_data_backup_*.tar.gz
    rm -f /tmp/postgres_backup_*.sql.gz
    rm -f /tmp/postgres_backup_*.sql
    
    log "임시 파일 정리 완료"
}

# 메인 실행 부분
log "n8n S3 복원 스크립트 시작..."

# 설정 파일 로드
load_config

# AWS CLI 연결 확인
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    error "AWS CLI 인증 실패. 자격 증명을 확인하세요."
fi

# 복원 전 확인
pre_restore_check

# 사용 가능한 백업 목록 확인
list_available_backups

# 복원할 백업 파일 선택
select_backup_files

# 기존 데이터 백업
backup_current_data

# 데이터 복원 실행
restore_n8n_data
restore_postgres_data
restore_docker_volumes

# 서비스 재시작
restart_services

# 복원 검증
verify_restore

# 정리 작업
cleanup_after_restore

log "n8n S3 복원 완료!"
echo ""
echo -e "${BLUE}복원 완료 후 확인사항:${NC}"
echo "1. n8n 웹 인터페이스에 접속하여 워크플로우가 정상적으로 복원되었는지 확인"
echo "2. 모든 연결과 자격 증명이 올바르게 작동하는지 확인"
echo "3. 중요한 워크플로우를 테스트하여 정상 작동하는지 확인"
echo ""
echo "문제가 있을 경우 복원 전 백업을 사용하여 롤백할 수 있습니다."