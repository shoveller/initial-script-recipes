# 유틸리티 설명

## format.mjs

- 서브패키지에서 타입체크(`tsc`) > prettier > eslint 를 순차 실행하는 유틸리티입니다.

### 사용법

1. package.json 의 devDependencies 에 `"@company/scripts": "workspace:*"` 를 추가하세요.
2. package.json 의 scripts 에 `"format": "format-app apps/web"` 을 추가하세요.
3. turbo.json 에 일괄 실행하는 명령어가 있고, 이것을 프로젝트 루트의 package.json 이 호출합니다.
4. 프로젝트 루트에서 `pnpm format` 을 호출하면 수동으로 실행할 수 있습니다.
5. `.husky/pre-commit` 에 `pnpm format` 을 등록했으므로 커밋할때 자동으로 호출됩니다.

## sync-catalog.mjs

- 서브패키지의 중복 디펜던시를 pnpm 의 카탈로그로 관리하는 유틸리티입니다.
- [pnpm codemod](https://github.com/pnpm/codemod) 라는 프로그램을 사용합니다.
- .github/workflows 아래의 워크플로우가 참조하는 pnpm 버전을 업데이트하는 부가기능이 있습니다.
- 바이너리로 등록이 되어 있습니다.

### 사용법

1. 프로젝트 루트의 package.json 의 devDependencies 에 `"@company/scripts": "workspace:*"` 가 추가되어 있습니다.
2. 프로젝트 루트에서 `pnpm sync-catalog` 을 호출하면 수동으로 실행됩니다.

## sync-versions.mjs

- 모든 서브패키지의 package.json 버전을 프로젝트 루트의 package.json 버전으로 동기화합니다.