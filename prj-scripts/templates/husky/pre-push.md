# pre-push 스크립트 주요 기능

- `.env` 파일들을 자동으로 GitHub 시크릿/변수로 업로드
- `.env` → Repository secrets/variables (예: `API_KEY=secret123`, `BASE_URL_VAR=https://api.com`)
- `.env.{environment}` → Environment secrets/variables (예: `.env.staging` → staging 환경)
- `.env.org` → Organization secrets/variables (예: `SHARED_DB_URL=postgres://...`)
- `_VAR` 접미사 → Variable로 저장, 나머지 → Secret으로 저장
- 환경이 없으면 자동 생성, CI 환경에서는 실행하지 않음
- GitHub CLI 인증 필요, 시스템 변수 및 빈 값 자동 제외