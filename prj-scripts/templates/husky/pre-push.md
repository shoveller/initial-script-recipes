# pre-push 스크립트 주요 기능

- `.env` 파일들을 자동으로 GitHub 시크릿/변수로 업로드
- `.env` → Repository secrets (예: `API_KEY=secret123`)
- `.env.var` → Repository variables (예: `BASE_URL=https://api.com`)
- `.env.{environment}` → Environment secrets (예: `.env.staging`)
- `.env.{environment}.var` → Environment variables (예: `.env.staging.var`)
- `.env.org` → Organization secrets (예: `SHARED_DB_URL=postgres://...`)
- `.env.org.var` → Organization variables (예: `PUBLIC_API_URL=https://api.com`)
- `.env.dep` → Dependabot secrets (예: `SHARED_DB_URL=postgres://...`)
- `.env.code` → Codespaces secrets (예: `SHARED_DB_URL=postgres://...`)
- 환경이 없으면 자동 생성, CI 환경에서는 실행하지 않음
- GitHub CLI 인증 필요, 시스템 변수 및 빈 값 자동 제외