# 토큰 및 환경변수 획득 가이드

이 문서는 프로젝트에서 필요한 다양한 API 토큰과 환경변수를 획득하는 방법을 설명합니다.

## 목차

1. [GitHub 관련 토큰](#github-관련-토큰)
2. [AWS 관련 설정](#aws-관련-설정)
3. [Cloudflare 토큰](#cloudflare-토큰)
4. [데이터베이스 연결](#데이터베이스-연결)
5. [외부 API 토큰](#외부-api-토큰)
6. [개발 환경별 설정](#개발-환경별-설정)

## GitHub 관련 토큰

### 1. GitHub Personal Access Token (PAT)

**용도**: GitHub API 접근, 프라이빗 저장소 액세스, GitHub Actions에서 사용

**획득 방법**:
1. GitHub 로그인 → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. "Generate new token (classic)" 클릭
3. 필요한 스코프 선택:
   - `repo`: 저장소 전체 액세스
   - `workflow`: GitHub Actions 워크플로우 수정
   - `write:packages`: 패키지 레지스트리 접근
   - `read:org`: 조직 정보 읽기

**환경변수 설정**:
```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2. GitHub App Token

**용도**: 더 세밀한 권한 제어, 조직 차원의 자동화

**획득 방법**:
1. GitHub Settings → Developer settings → GitHub Apps
2. "New GitHub App" 클릭
3. 앱 설정 후 Private key 다운로드
4. JWT 토큰 생성 후 Installation Access Token 획득

**환경변수 설정**:
```bash
GITHUB_APP_ID=123456
GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
GITHUB_APP_INSTALLATION_ID=12345678
```

## AWS 관련 설정

### 1. AWS Access Keys

**용도**: AWS 서비스 접근, CDK 배포, S3 업로드 등

**획득 방법**:
1. AWS Console → IAM → Users → 사용자 선택
2. "Security credentials" 탭 → "Create access key"
3. Use case 선택 (CLI, SDK 등)
4. Access Key ID와 Secret Access Key 저장

**환경변수 설정**:
```bash
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012
```

### 2. AWS IAM Role (권장)

**용도**: EC2, Lambda, GitHub Actions에서 안전한 AWS 접근

**획득 방법**:
1. AWS Console → IAM → Roles → "Create role"
2. Trust entity 선택 (AWS service, Web identity 등)
3. 필요한 정책 연결
4. Role ARN 복사

**환경변수 설정**:
```bash
AWS_ROLE_ARN=arn:aws:iam::123456789012:role/MyRole
AWS_ROLE_SESSION_NAME=MySession
```

### 3. AWS CDK Bootstrap

**용도**: CDK 스택 배포를 위한 초기 설정

**설정 명령**:
```bash
# 기본 리전에 bootstrap
npx cdk bootstrap

# 특정 계정/리전에 bootstrap
npx cdk bootstrap aws://123456789012/us-east-1
```

## Cloudflare 토큰

### 1. Cloudflare API Token

**용도**: DNS 레코드 관리, Zone 설정, 캐시 정리

**획득 방법**:
1. Cloudflare Dashboard 로그인
2. 우측 상단 프로필 → "My Profile" → "API Tokens"
3. "Create Token" 클릭
4. 템플릿 선택 또는 커스텀 토큰 생성:
   - **Zone:Read**, **DNS:Edit** 권한 필요
   - 특정 Zone에 대해서만 권한 부여 권장

**환경변수 설정**:
```bash
CLOUDFLARE_API_TOKEN=your-api-token-here
CLOUDFLARE_ZONE_ID=your-zone-id-here
```

### 2. Cloudflare Zone ID 확인

**확인 방법**:
1. Cloudflare Dashboard → 도메인 선택
2. 우측 사이드바에서 "Zone ID" 확인

### 3. Cloudflare Global API Key (레거시)

**획득 방법**:
1. Cloudflare Dashboard → 프로필 → "API Tokens"
2. "Global API Key" 섹션에서 "View" 클릭

**환경변수 설정**:
```bash
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_KEY=your-global-api-key
```

## 데이터베이스 연결

### 1. PostgreSQL

**로컬 개발**:
```bash
DATABASE_URL=postgresql://username:password@localhost:5432/database_name
```

**클라우드 서비스**:
```bash
# Supabase
DATABASE_URL=postgresql://postgres:password@db.abcdefghijklmn.supabase.co:5432/postgres

# Neon
DATABASE_URL=postgresql://username:password@ep-xxx-xxx.us-east-1.aws.neon.tech/neondb

# Railway
DATABASE_URL=postgresql://postgres:password@containers-us-west-xxx.railway.app:5432/railway
```

### 2. MySQL

```bash
DATABASE_URL=mysql://username:password@localhost:3306/database_name
```

### 3. MongoDB

```bash
# 로컬
MONGODB_URI=mongodb://localhost:27017/database_name

# MongoDB Atlas
MONGODB_URI=mongodb+srv://username:password@cluster0.xxx.mongodb.net/database_name
```

### 4. Redis

```bash
# 로컬
REDIS_URL=redis://localhost:6379

# 클라우드
REDIS_URL=rediss://username:password@redis-xxx.upstash.io:6380
```

## 외부 API 토큰

### 1. OpenAI API

**획득 방법**:
1. OpenAI Platform (platform.openai.com) 로그인
2. API Keys → "Create new secret key"

**환경변수 설정**:
```bash
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2. Stripe

**획득 방법**:
1. Stripe Dashboard 로그인
2. Developers → API keys
3. Publishable key (공개용)와 Secret key (비밀용) 확인

**환경변수 설정**:
```bash
# 테스트 환경
STRIPE_PUBLISHABLE_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 프로덕션 환경
STRIPE_PUBLISHABLE_KEY=pk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_live_xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 3. SendGrid (이메일 서비스)

**획득 방법**:
1. SendGrid Dashboard 로그인
2. Settings → API Keys → "Create API Key"

**환경변수 설정**:
```bash
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 4. Twilio (SMS/통화 서비스)

**획득 방법**:
1. Twilio Console 로그인
2. Account → API Keys & Tokens

**환경변수 설정**:
```bash
TWILIO_ACCOUNT_SID=ACxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
TWILIO_AUTH_TOKEN=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## 개발 환경별 설정

### 1. 환경 구분

```bash
# 공통
NODE_ENV=development  # development, production, test

# 개발 환경
DEBUG=true
LOG_LEVEL=debug

# 프로덕션 환경
DEBUG=false
LOG_LEVEL=error
```

### 2. 도메인 설정

```bash
# 개발 환경
DOMAIN=localhost:3000
FRONTEND_URL=http://localhost:3000
BACKEND_URL=http://localhost:3001

# 프로덕션 환경
DOMAIN=example.com
FRONTEND_URL=https://example.com
BACKEND_URL=https://api.example.com
```

### 3. 시크릿 키 생성

**JWT Secret 생성**:
```bash
# Node.js에서 생성
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"

# OpenSSL 사용
openssl rand -hex 32
```

**환경변수 설정**:
```bash
JWT_SECRET=your-generated-32-character-hex-string
SESSION_SECRET=another-generated-secret-key
```

## 보안 모범 사례

### 1. 토큰 관리

- **최소 권한 원칙**: 필요한 최소한의 권한만 부여
- **정기 갱신**: 토큰을 정기적으로 갱신
- **즉시 폐기**: 사용하지 않는 토큰은 즉시 삭제
- **분리 관리**: 개발/스테이징/프로덕션 환경별로 다른 토큰 사용

### 2. 환경변수 보안

- **Git 제외**: `.env` 파일을 `.gitignore`에 추가
- **암호화 저장**: 시크릿 관리 서비스 사용 (GitHub Secrets, AWS Secrets Manager 등)
- **접근 제한**: 필요한 사람만 접근 가능하도록 제한

### 3. 모니터링

- **사용량 모니터링**: API 사용량 및 비정상적인 접근 감지
- **로그 확인**: 토큰 사용 로그 정기 확인
- **알림 설정**: 의심스러운 활동에 대한 알림 설정

## 예시 .env 파일

```bash
# 개발 환경 예시
NODE_ENV=development
DEBUG=true

# 서버 설정
PORT=3000
DOMAIN=localhost:3000

# 데이터베이스
DATABASE_URL=postgresql://postgres:password@localhost:5432/myapp_dev

# 외부 API
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRIPE_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxx

# AWS
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
AWS_DEFAULT_REGION=us-east-1
AWS_ACCOUNT_ID=123456789012

# Cloudflare
CLOUDFLARE_API_TOKEN=your-api-token-here
CLOUDFLARE_ZONE_ID=your-zone-id-here

# GitHub
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# 시크릿 키
JWT_SECRET=your-generated-32-character-hex-string
SESSION_SECRET=another-generated-secret-key
```

## 문제 해결

### 토큰 관련 오류

1. **Invalid token**: 토큰이 만료되었거나 잘못된 경우
   - 토큰 재생성 또는 갱신
   - 환경변수 설정 확인

2. **Permission denied**: 권한이 부족한 경우
   - 토큰 권한 범위 확인
   - 필요한 스코프 추가

3. **Rate limit exceeded**: API 호출 한도 초과
   - API 사용량 확인
   - 호출 빈도 조정

### 환경변수 관련 오류

1. **Environment variable not found**: 환경변수가 설정되지 않은 경우
   - `.env` 파일 존재 확인
   - 변수명 오타 확인

2. **Connection refused**: 데이터베이스 연결 실패
   - 연결 정보 확인
   - 서비스 실행 상태 확인

이 가이드를 참고하여 프로젝트에 필요한 토큰과 환경변수를 안전하게 설정하세요.