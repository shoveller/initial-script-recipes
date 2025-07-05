# prj.sh
> 웹 프론트엔드 프로젝트 스케폴드 자동화 스크립트(osx 전용)

## 실행 흐름

```mermaid
graph TD
    subgraph "사용자 입력"
        A[프로젝트 이름 입력] --> B[패키지 스코프 입력];
    end

    subgraph "프로젝트 초기화"
        B --> C{pnpm 설치 확인};
        C --> D[프로젝트 디렉토리 생성];
        D --> E[Git 저장소 초기화];
        E --> F[pnpm 초기화];
    end

    subgraph "기본 설정"
        F --> G[gitignore 설정];
        G --> H[@types/node 설치];
        H --> I[TypeScript 및 tsconfig.json 설정];
    end

    subgraph "CI/CD 및 버전 관리"
        I --> J[semantic-release 설정];
        J --> K[GitHub Actions 워크플로우 생성<br>(semantic-release, AWS Lambda 배포)];
    end

    subgraph "모노레포 및 개발 환경 설정"
        K --> L[package.json에<br>private, packageManager, scripts 추가];
        L --> M[Turborepo 설치];
        M --> N[Husky 및 pre-commit 훅 설정];
        N --> O[워크스페이스 구조 생성<br>(apps, packages, pnpm-workspace.yaml, turbo.json)];
    end

    subgraph "공유 패키지 설정"
        O --> P[공유 스크립트 패키지 생성<br>(@scope/scripts)];
        P --> Q[ESLint 패키지 생성<br>(@scope/eslint)];
        Q --> R[Prettier 패키지 생성<br>(@scope/prettier)];
        R --> S[루트 설정 파일 생성<br>(eslint.config.mjs, prettier.config.mjs)];
    end

    subgraph "인프라 설정 (선택)"
        S --> T{AWS 인프라 설정<br>스크립트 실행};
        T --> U[인프라 패키지 생성<br>(@scope/infra)];
        U --> V[CDK 관련 파일 생성<br>(cdk-stack.ts, cdk.ts, entry/lambda.ts, update_dns.ts)];
    end

    subgraph "웹 애플리케이션 설정"
        V --> W[React Router 웹 앱 생성<br>(apps/web)];
        W --> X[패키지 설정 및 의존성 추가<br>(scripts, eslint, prettier)];
        X --> Y[TypeScript 설정 및 타입 체크];
        Y --> Z[React Router 앱 구조 최적화<br>(ErrorBoundary, home.tsx 수정)];
    end

    subgraph "최종 단계"
        Z --> AA[VS Code 워크스페이스 설정];
        AA --> BB[프로젝트 README 및 .env 템플릿 생성];
        BB --> CC[스캐폴딩 완료];
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#bbf,stroke:#333,stroke-width:2px
    style T fill:#bbf,stroke:#333,stroke-width:2px
```

## 다운로드
```shell
# 전체 저장소 클론
git clone https://github.com/shoveller/initial-script-recipes.git
```

또는 특정 파일들만 다운로드:
```shell
# 스크립트 디렉토리 생성
mkdir -p prj-scripts

# 메인 스크립트 다운로드
curl -L -o prj.sh https://github.com/shoveller/initial-script-recipes/raw/main/prj.sh

# 템플릿 복사 헬퍼 스크립트 다운로드
curl -L -o prj-scripts/copy-template.sh https://github.com/shoveller/initial-script-recipes/raw/main/prj-scripts/copy-template.sh

# 템플릿 디렉토리 다운로드 (필요한 모든 템플릿 파일들)
mkdir -p prj-scripts/templates
# 각 템플릿 파일들을 개별적으로 다운로드하거나 저장소를 클론하는 것을 권장
```

## 실행권한 부여
```shell
chmod +x initial-script-recipes/prj.sh
```

## 웹 프론트엔드 프로젝트 스케폴드 개시
```shell
./initial-script-recipes/prj.sh
```

## 주요 변경사항
- **단일 스크립트**: 이제 `prj.sh` 하나만 실행하면 전체 스캐폴딩이 완료됩니다
- **템플릿 기반**: 하드코딩된 내용들이 `prj-scripts/` 디렉토리의 템플릿 파일들로 분리되었습니다
- **React Router**: Vite + React 대신 React Router를 사용하여 웹 애플리케이션을 생성합니다
- **통합된 워크플로우**: 기존 `prj.sh`와 `prj-scripts/prj.sh`의 기능이 하나로 통합되었습니다
