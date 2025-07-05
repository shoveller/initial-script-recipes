# 아이디어
- husky 를 사용해서 github 푸시 직전에 .env 파일을 github 시크릿으로 자동 업데이트 하자
    - `.husky/pre-push` 를 사용하면 푸시할때마다 단방향으로 시크릿을 동기화할 수 있을 것이다.
    - 리파지토리 레벨, 조직 레벨, 환경 레벨 시크릿도 자동으로 동기화되면 좋겠다.

# 깃허브 secret과 variable의 우선순위
- 깃허브에는 2종류의 변수를 저장할 수 있다.
    - secret : 어떤 경우에도 외부에 노출하면 안되는 정보를 저장한다.
    - variable : 공개 정보를 저장한다.
- 깃허브의 secret과 variable은 리파지토리별, 환경별, 조직별로 저장할 수 있고, 적용하는 우선순위가 있다.
    1. Environment secrets, variable (가장 높은 우선순위)
        1. production , develop 등으로 설정한 환경별 시크릿과 변수
    2. Repository secrets, variable
        1. 가장 흔하게 보는 시크릿과 변수
    3. Organization secrets, variable
        1. 조직 안의 모든 리파지토리에서 사용할 수 있는 시크릿과 변수
- 최근에는 Dependabot secrets , Codespaces secrets 기능이 추가되었으므로 반영했다.
    - Dependabot 은 디펜던시를 자동으로 업데이트하는 봇이다.
    - Codespaces 는 클라우드 기반 개발환경이다.
    - 둘 다 시크릿만 지정할 수 있다.

# 설계
- `.env` 파일들을 자동으로 GitHub 시크릿/변수로 업로드
- `.env` → Repository secrets (예: `API_KEY=secret123`)
- `.env.var` → Repository variables (예: `BASE_URL=https://api.com`)
- `.env.{environment}` → Environment secrets (예: `.env.staging`)
- `.env.{environment}.var` → Environment variables (예: `.env.staging.var`)
- `.env.org` → Organization secrets (예: `SHARED_DB_URL=postgres://...`)
- `.env.org.var` → Organization variables (예: `PUBLIC_API_URL=https://api.com`)
- `.env.dep` → Dependabot secrets (예: `SHARED_DB_URL=postgres://...`)
- `.env.code`  → Codespaces secrets (예: `SHARED_DB_URL=postgres://...`)