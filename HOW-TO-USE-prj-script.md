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
        V --> W[웹 앱 패키지 생성<br>(apps/web)];
        W --> X[Vite, React, Tailwind CSS 등<br>필요한 의존성 설치];
        X --> Y[설정 파일 생성<br>(vite.config.ts, tailwind.config.ts, postcss.config.mjs)];
        Y --> Z[기본 소스 코드 생성<br>(main.tsx, App.tsx, index.css)];
    end

    subgraph "최종 단계"
        Z --> AA[의존성 최종 설치<br>(pnpm install)];
        AA --> BB[Git 커밋];
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#f9f,stroke:#333,stroke-width:2px
    style C fill:#bbf,stroke:#333,stroke-width:2px
    style T fill:#bbf,stroke:#333,stroke-width:2px
```

## 다운로드
```shell
curl -L -o prj.sh https://github.com/shoveller/initial-script-recipes/raw/main/prj.sh
```

## 실행권한 부여
```shell
chmod +x prj.sh
```

## 웹 프론트엔드 프로젝트 스케폴드 개시
```shell
./prj.sh
```
