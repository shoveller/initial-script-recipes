# Infrastructure Package

AWS CDK와 Cloudflare DNS를 사용한 자동화된 배포 시스템입니다.

## 🚀 주요 기능

- **AWS CDK 배포**: Lambda Function URL과 CloudFront 배포
- **자동 DNS 업데이트**: Cloudflare DNS 레코드 자동 관리
- **환경변수 자동 업데이트**: 배포 후 .env 파일 자동 갱신

## 📋 실행 흐름

```mermaid
graph TD
    A[pnpm deploy] --> B[cdk.ts 실행]
    B --> C[CdkStack 생성]
    C --> D[Lambda Function 배포]
    C --> E[CloudFront Distribution 생성]
    C --> F[S3 Bucket 생성 및 정적 파일 배포]
    
    D --> G[Lambda Function URL 생성]
    G --> H[onDeploySuccess 콜백 호출]
    H --> I[updateEnvRecordValueAndDNS 실행]
    
    I --> J[.env 파일 읽기]
    J --> K[RECORD_VALUE 업데이트]
    K --> L{DOMAIN 환경변수 확인}
    
    L -->|DOMAIN 없음| M[DNS 업데이트 건너뜀]
    L -->|DOMAIN 있음| N[createDNSConfig 함수 호출]
    
    N --> O[updateDNS 함수 호출]
    O --> Q[Wrangler 설치 확인]
    
    Q --> S[기존 DNS 레코드 조회]
    
    S --> U{기존 레코드 존재?}
    
    U -->|없음| W[새 DNS 레코드 생성]
    U -->|있음| X[기존 DNS 레코드 업데이트]
    
    W --> AA[완료!]
    X --> AA
    M --> AA
    
    classDef startEnd fill:#e1f5fe,stroke:#01579b,stroke-width:2px,color:#000000
    classDef cdk fill:#f3e5f5,stroke:#4a148c,stroke-width:2px,color:#000000
    classDef aws fill:#e8f5e8,stroke:#1b5e20,stroke-width:2px,color:#000000
    classDef env fill:#fff8e1,stroke:#f57f17,stroke-width:2px,color:#000000
    classDef dns fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#000000
    classDef decision fill:#fce4ec,stroke:#880e4f,stroke-width:2px,color:#000000
    
    class A,AA startEnd
    class B,C,H,I cdk
    class D,E,F,G aws
    class J,K,N,O env
    class Q,S,W,X,M dns
    class L,U decision
```

## 🛠️ 스크립트 명령어

### 배포 관련
- `pnpm bootstrap`: CDK 부트스트랩 및 첫 배포
- `pnpm deploy`: CDK 배포 (hotswap 모드)
- `pnpm destroy`: CDK 스택 삭제

### DNS 관리
- `pnpm update-dns`: Wrangler CLI로 DNS 업데이트

## 🔧 환경변수 설정

### 필수 환경변수
```bash
# AWS 관련
AWS_ACCOUNT_ID=your-aws-account-id
AWS_DEFAULT_REGION=ap-northeast-2

# Cloudflare 관련 (DNS 업데이트 시 필요)
CLOUDFLARE_API_TOKEN=your-cloudflare-api-token
CLOUDFLARE_ACCOUNT_ID=your-cloudflare-account-id
```

### DNS 업데이트 관련 환경변수
```bash
# 도메인 설정 (선택사항 - 없으면 DNS 업데이트 건너뜀)
DOMAIN=example.com
SUBDOMAIN=api  # 선택사항 - 없으면 메인 도메인 사용

# DNS 레코드 설정
RECORD_TYPE=CNAME
RECORD_VALUE=lambda-url.amazonaws.com  # 자동 업데이트됨
TTL=300
```

## 📝 환경변수 설정 규칙

### DOMAIN 처리
- **DOMAIN이 설정되지 않은 경우**: DNS 업데이트를 완전히 건너뜁니다
- **DOMAIN이 설정된 경우**: DNS 업데이트를 진행합니다

### SUBDOMAIN 처리
- **SUBDOMAIN이 없는 경우**: 메인 도메인(example.com)에 레코드 설정
- **SUBDOMAIN이 있는 경우**: 서브도메인(api.example.com)에 레코드 설정

## 🌐 DNS 업데이트 방식

### Wrangler CLI 방식
```bash
pnpm update-dns
```

## 🔄 자동화된 배포 프로세스

1. **CDK 배포**: `pnpm deploy` 실행
2. **Lambda 생성**: AWS Lambda Function URL 생성
3. **환경변수 업데이트**: .env 파일의 RECORD_VALUE 자동 업데이트
4. **DNS 업데이트**: Cloudflare DNS 레코드 자동 업데이트 (DOMAIN이 설정된 경우)

## ⚠️ 주의사항

- **DOMAIN 환경변수가 없으면** DNS 업데이트는 자동으로 건너뜁니다
- **Wrangler CLI 사용 시** `wrangler` 명령어가 전역으로 설치되어야 합니다

## 🚨 트러블슈팅

### DNS 업데이트 실패 시
배포는 성공했지만 DNS 업데이트가 실패한 경우 수동으로 실행:
```bash
cd packages/infra
pnpm update-dns
```

### Wrangler CLI 설치
```bash
npm install -g wrangler
```