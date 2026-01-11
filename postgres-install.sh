#!/usr/bin/env bash

# 에러 발생 시 스크립트 중단
set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Railway pgvector 인프라 스케폴딩 시작 ===${NC}\n"

# 1. Railway CLI 설치 여부 확인
if ! command -v railway &> /dev/null; then
    echo -e "${RED}❌ 에러: Railway CLI가 설치되어 있지 않습니다.${NC}"
    echo "다음 명령어로 설치를 먼저 진행해 주세요:"
    echo -e "${GREEN}brew install railway${NC} (macOS)"
    echo "또는 공식 가이드를 참조하세요: https://docs.railway.app/guides/cli"
    exit 1
fi

# 2. 프로젝트 이름 인터렉티브하게 받기
read -p "🚀 생성할 프로젝트(디렉토리) 이름을 입력하세요: " PROJECT_NAME

if [[ -z "$PROJECT_NAME" ]]; then
    echo -e "${RED}❌ 에러: 프로젝트 이름은 필수입니다.${NC}"
    exit 1
fi

# 3. 작업 디렉토리 생성 및 이동
if [ -d "$PROJECT_NAME" ]; then
    echo -e "${RED}⚠️  주의: 이미 '$PROJECT_NAME' 디렉토리가 존재합니다.${NC}"
    read -p "계속 진행할까요? (y/N): " CONT
    [[ $CONT =~ ^[Yy]$ ]] || exit 1
else
    mkdir -p "$PROJECT_NAME"
fi

cd "$PROJECT_NAME"

# 4. 인프라 설정 파일 생성
echo "📦 설정 파일 생성 중..."

# Dockerfile
echo "FROM pgvector/pgvector:pg17" > Dockerfile

# railway.json (배포 전략 정의)
cat <<EOF > railway.json
{
  "\$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE"
  },
  "deploy": {
    "numReplicas": 1,
    "sleepApplication": false,
    "restartPolicyType": "ON_FAILURE"
  }
}
EOF

# 5. Railway 초기화
echo -e "${GREEN}🔗 Railway 프로젝트를 연결합니다...${NC}"
# 이미 로그인 되어 있다고 가정하지만, 안 되어 있으면 여기서 웹 브라우저가 뜹니다.
railway init

# 6. 환경 변수 및 랜덤 비밀번호 생성
# openssl을 사용하여 URL-safe한 20자 비밀번호 생성
DB_PASSWORD=$(openssl rand -base64 16 | tr -dc 'A-Za-z0-9' | head -c 20)

echo "🔐 환경 변수를 설정 중..."
railway variables set \
  POSTGRES_PASSWORD="$DB_PASSWORD" \
  POSTGRES_USER=postgres \
  POSTGRES_DB=ai_app_db \
  PGDATA=/var/lib/postgresql/data/pgdata

# 7. TCP 도메인 생성 (외부 접속 허용)
echo "🌐 TCP 프록시 도메인 생성 중..."
railway domain --port 5432 --tcp

echo -e "\n${GREEN}===============================================${NC}"
echo -e "✅ 스케폴딩 완료!"
echo -e "📂 경로: ${BLUE}$(pwd)${NC}"
echo -e "🔑 DB 비밀번호: ${BLUE}$DB_PASSWORD${NC}"
echo -e "📢 다음 단계:"
echo -e "   1. ${GREEN}railway up${NC} 명령어로 배포를 시작하세요."
echo -e "   2. 대시보드에서 ${GREEN}Volume${NC}을 /var/lib/postgresql/data 에 마운트하세요."
echo -e "${GREEN}===============================================${NC}"