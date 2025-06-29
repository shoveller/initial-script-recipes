#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Pure function to check if pnpm is installed
check_pnpm_installed() {
    echo -e "${BLUE}pnpm 설치 상태를 확인합니다...${NC}" >&2

    if ! command -v pnpm &> /dev/null; then
        echo -e "${RED}pnpm이 설치되어 있지 않습니다.${NC}" >&2
        echo -e "${YELLOW}pnpm을 설치하려면 다음 명령을 실행하세요:${NC}" >&2
        echo -e "${YELLOW}npm install -g pnpm${NC}" >&2
        exit 1
    fi

    local pnpm_version
    pnpm_version=$(pnpm -v 2>/dev/null | head -1 | tr -d '[:space:]' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')

    if [[ -z "$pnpm_version" ]]; then
        echo -e "${RED}pnpm 버전을 확인할 수 없습니다.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}pnpm이 설치되어 있습니다.${NC}" >&2
    echo "$pnpm_version"
}

# Pure function to get user input for project name and package scope
get_project_inputs() {
    echo -e "${BLUE}프로젝트 이름을 입력하세요:${NC}" >&2
    read -r project_name </dev/tty

    echo -e "${BLUE}패키지 스코프를 입력하세요 (예: @company):${NC}" >&2
    read -r package_scope </dev/tty

    if [[ -z "$project_name" || -z "$package_scope" ]]; then
        echo -e "${RED}프로젝트 이름과 패키지 스코프를 모두 입력해야 합니다.${NC}" >&2
        exit 1
    fi

    echo "$project_name $package_scope"
}

# Pure function to initialize project directory
init_project() {
    local project_name=$1

    echo -e "${GREEN}프로젝트 '$project_name' 디렉토리를 생성합니다...${NC}"
    mkdir -p "$project_name"
    cd "$project_name"

    echo -e "${GREEN}Git 저장소를 초기화합니다...${NC}"
    git init

    echo -e "${GREEN}pnpm을 초기화합니다...${NC}"
    pnpm init
}

# Pure function to setup gitignore
setup_gitignore() {
    echo -e "${GREEN}.gitignore 파일을 생성합니다...${NC}"
    pnpm dlx mrm@latest gitignore

    echo -e "${GREEN}.gitignore 파일을 수정합니다...${NC}"
    # .vscode/ 항목 삭제
    sed -i.bak '/^\.vscode\/$/d' .gitignore

    # .lh/ 항목 추가
    echo ".lh/" >> .gitignore
    
    # .turbo/ 항목 추가
    echo ".turbo/" >> .gitignore

    # cdk.out/ 항목 추가
    echo "cdk.out/" >> .gitignore

    # 백업 파일 삭제
    rm -f .gitignore.bak
}

# Pure function to setup @types/node
setup_types_node() {
    echo -e "${GREEN}@types/node를 설정합니다...${NC}"

    local node_version
    node_version=$(node -v 2>/dev/null | grep -o '[0-9]\+' | head -1)

    if [[ -z "$node_version" ]]; then
        echo -e "${RED}Node.js 버전을 확인할 수 없습니다.${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}Node.js 버전 $node_version을 감지했습니다.${NC}"

    # Install @types/node with major version only
    pnpm i -D "@types/node@$node_version"
}

# Pure function to setup TypeScript
setup_typescript() {
    echo -e "${GREEN}TypeScript를 설치합니다...${NC}"
    pnpm i -D typescript

    echo -e "${GREEN}tsconfig.json 파일을 생성합니다...${NC}"
    cat > tsconfig.json << 'EOF'
{
  "compilerOptions": {
    /* 컴파일 성능 최적화 */
    "skipLibCheck": true, // 라이브러리 타입 정의 파일 검사 건너뛰기 (빌드 속도 향상)
    "incremental": true, // 증분 컴파일 활성화 (이전 빌드 정보 재사용)
    "tsBuildInfoFile": "./node_modules/.cache/tsc/tsbuildinfo", // 증분 컴파일 정보 저장 위치

    /* 출력 제어 */
    "noEmit": true, // JavaScript 파일 생성하지 않음 (타입 검사만 수행)

    /* 엄격한 타입 검사 */
    "strict": true, // 모든 엄격한 타입 검사 옵션 활성화
    "noUnusedLocals": true, // 사용하지 않는 지역 변수 에러 처리
    "noUnusedParameters": true, // 사용하지 않는 함수 매개변수 에러 처리
    "noFallthroughCasesInSwitch": true, // switch문에서 break 누락 시 에러 처리
    "noUncheckedSideEffectImports": true, // 부작용이 있는 import 구문의 타입 검사 강화

    /* 구문 분석 최적화 */
    "erasableSyntaxOnly": true // TypeScript 고유 구문만 제거하고 JavaScript 호환성 유지
  }
}
EOF
}

# Pure function to setup semantic-release
setup_semantic_release() {
    local pnpm_version=$1

    echo -e "${GREEN}semantic-release를 설치합니다...${NC}"
    pnpm i -D semantic-release @semantic-release/commit-analyzer @semantic-release/release-notes-generator @semantic-release/changelog @semantic-release/npm @semantic-release/github @semantic-release/git

    echo -e "${GREEN}release.config.ts 파일을 생성합니다...${NC}"
    cat > release.config.ts << 'EOF'
import { GlobalConfig } from 'semantic-release'

// GitHub Actions 환경 변수로부터 저장소 URL 생성
const getRepositoryUrl = (): string => {
  // GitHub Actions 환경에서 실행 중인 경우
  if (!process.env.GITHUB_REPOSITORY) {
    throw new Error('env.GITHUB_REPOSITORY not found')
  }

  // 로컬 환경 또는 환경 변수가 없는 경우 기본값 사용
  return `${process.env.GITHUB_SERVER_URL || 'https://github.com'}/${process.env.GITHUB_REPOSITORY}`
}

const config: GlobalConfig = {
  branches: ['main'],
  repositoryUrl: getRepositoryUrl(),
  tagFormat: '${version}',
  plugins: [
    '@semantic-release/commit-analyzer', // 커밋 메시지를 분석하여 버전 결정
    '@semantic-release/release-notes-generator', // CHANGELOG.md에 들어갈 릴리스 노트를 생성
    '@semantic-release/changelog', // CHANGELOG.md 업데이트
    [
      '@semantic-release/npm',
      {
        npmPublish: false
      }
    ], // npm 배포, package.json 업데이트
    '@semantic-release/github', // GitHub Release를 생성
    [
      '@semantic-release/git', //  Git 커밋 및 푸시
      {
        assets: ['CHANGELOG.md', 'package.json', 'packages/*/package.json', 'apps/*/package.json'],
        message:
          'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}'
      }
    ]
  ]
}

export default config
EOF

    echo -e "${GREEN}GitHub Actions workflow 디렉토리를 생성합니다...${NC}"
    mkdir -p .github/workflows

    echo -e "${GREEN}semantic-release GitHub Actions workflow를 생성합니다...${NC}"
    cat > .github/workflows/semantic-release.yml << EOF
name: semantic-release

on:
  workflow_dispatch:
  push:
    branches:
      - main

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Install pnpm
        uses: pnpm/action-setup@v4
        with:
          version: '$pnpm_version'
          run_install: false

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm i --frozen-lockfile

      - name: Semantic Release
        env:
          GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
        run: pnpm semantic-release

      - name: Sync package versions
        run: |
          # semantic-release 실행 후 서브패키지들 버전 동기화
          cd packages/scripts && node sync-versions.mjs

      - name: Commit version sync
        run: |
          git config --local user.email "action@github.com"
          git config --local user.name "GitHub Action"
          git add packages/*/package.json
          git diff --staged --quiet || git commit -m "chore: sync package versions [skip ci]"
          git push

EOF
}

# Pure function to create AWS Lambda deployment workflow
create_aws_deployment_workflow() {
    local pnpm_version=$1

    echo -e "${GREEN}AWS Lambda 배포 GitHub Actions workflow를 생성합니다...${NC}"
    cat > .github/workflows/deploy-aws-lambda.yml << EOF
name: Deploy to aws lambda

on:
   workflow_dispatch:
   workflow_run:
      workflows: ['semantic-release']
      types:
         - completed
      branches:
         - main
   push:
      branches:
         - develop

jobs:
   deploy:
      runs-on: ubuntu-latest
      steps:
         - name: Checkout repository
           uses: actions/checkout@v4

         - name: Install pnpm
           uses: pnpm/action-setup@v4
           with:
              version: '$pnpm_version'
              run_install: false

         - name: Setup Node.js
           uses: actions/setup-node@v4
           with:
              node-version: '20'
              cache: 'pnpm'

         - name: Install dependencies
           run: pnpm i --frozen-lockfile

         - name: Deploy to AWS Lambda
           env:
              AWS_ACCOUNT_ID: \${{ secrets.AWS_ACCOUNT_ID }}
              AWS_DEFAULT_REGION: \${{ secrets.AWS_DEFAULT_REGION }}
           run: pnpm deploy

         - name: 배포 성공 알림
           if: success()
           uses: cbrgm/telegram-github-action@v1
           with:
             token: \${{ secrets.TELEGRAM_TOKEN }}
             to: \${{ secrets.TELEGRAM_CHAT_ID }}
             message: |
               ✅ 배포 성공
               브랜치: \${{ github.ref_name }}
               배포 URL: https://\${{ secrets.SUBDOMAIN && format('{0}.{1}', secrets.SUBDOMAIN, secrets.DOMAIN) || secrets.DOMAIN }}

         - name: 배포 실패 알림
           if: failure()
           uses: cbrgm/telegram-github-action@v1
           with:
             token: \${{ secrets.TELEGRAM_TOKEN }}
             to: \${{ secrets.TELEGRAM_CHAT_ID }}
             message: |
               ❌ 배포 실패
               브랜치: \${{ github.ref_name }}
               작업 링크: https://github.com/\${{ github.repository }}/actions/runs/\${{ github.run_id }}
EOF
}

# Pure function to setup package.json private field and scripts
setup_package_json_private() {
    local pnpm_version=$1

    echo -e "${GREEN}package.json에 private: true, packageManager, scripts를 설정합니다...${NC}"

    # Use jq if available, otherwise use sed
    if command -v jq &> /dev/null; then
        jq --arg version "$pnpm_version" '. + {"private": true, "packageManager": ("pnpm@" + $version), "scripts": {"format": "turbo format", "dev": "turbo dev", "sync-catalog": "sync-catalog", "prepare": "husky", "bootstrap": "turbo bootstrap", "build": "turbo build", "deploy": "turbo deploy", "destroy": "turbo destroy"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Create a proper package.json using Node.js
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.private = true;
        pkg.packageManager = 'pnpm@$pnpm_version';
        pkg.scripts = {
            'format': 'turbo format',
            'dev': 'turbo dev',
            'sync-catalog': 'sync-catalog',
            'prepare': 'husky',
            'bootstrap': 'turbo bootstrap',
            'build': 'turbo build',
            'deploy': 'turbo deploy',
            'destroy': 'turbo destroy'
        };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi
}

# Pure function to install and setup turborepo
setup_turborepo() {
    echo -e "${GREEN}Turborepo를 설치합니다...${NC}"
    pnpm i turbo
}

# Pure function to install and setup husky
setup_husky() {
    echo -e "${GREEN}Husky를 설치합니다...${NC}"
    pnpm i husky
    pnpm husky init

    echo -e "${GREEN}pre-commit 훅을 설정합니다...${NC}"
    echo "pnpm format" > .husky/pre-commit
}

# Pure function to create workspace structure with complete turbo config
create_workspace_structure() {
    local package_scope=$1
    local project_name=$2

    echo -e "${GREEN}워크스페이스 구조를 생성합니다...${NC}"
    mkdir -p apps packages

    echo -e "${GREEN}pnpm-workspace.yaml을 생성합니다...${NC}"
    cat > pnpm-workspace.yaml << 'EOF'
packages:
  - 'apps/*'
  - 'packages/*'
EOF

    echo -e "${GREEN}turbo.json을 생성합니다...${NC}"
    cat > turbo.json << EOF
{
  "\$schema": "https://turbo.build/schema.json",
  "remoteCache": {
    "enabled": false
  },
  "tasks": {
     "format": {
      "cache": false
     },
     "dev": {
      "cache": false,
      "persistent": true
    },
     "version": {
       "dependsOn": ["^version"]
     },
     "build": {},
     "deploy": {},
     "destroy": {},
     "bootstrap": {},
     "${package_scope}/infra#deploy": {
       "dependsOn": [
         "${package_scope}/web#build"
       ],
       "cache": false
     }
   }
}
EOF
}

# Pure function to create sync-catalog script
create_sync_catalog_script() {
    echo -e "${GREEN}sync-catalog.mjs 파일을 생성합니다...${NC}"
    cat > sync-catalog.mjs << 'EOF'
#!/usr/bin/env node

import { execSync } from 'child_process'
import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// 프로젝트 루트 디렉토리
const rootDir = join(__dirname, '../../')

/**
 * 프로젝트 루트의 package.json에서 pnpm 버전을 추출
 */
function getPnpmVersionFromPackageJson() {
  try {
    const packageJsonPath = join(rootDir, 'package.json')
    const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'))

    if (!packageJson.packageManager) {
      throw new Error('package.json에 packageManager 필드가 없습니다.')
    }

    // "pnpm@9.5.0" 형태에서 버전만 추출
    const match = packageJson.packageManager.match(/pnpm@(.+)/)
    if (!match) {
      throw new Error('packageManager 필드에서 pnpm 버전을 찾을 수 없습니다.')
    }

    return match[1]
  } catch (error) {
    console.error('❌ pnpm 버전 추출 실패:', error.message)
    process.exit(1)
  }
}

/**
 * .github/workflows 디렉토리에서 모든 workflow 파일을 찾기
 */
function findWorkflowFiles() {
  const workflowDir = join(rootDir, '.github/workflows')
  const files = []

  try {
    const entries = readdirSync(workflowDir)

    for (const entry of entries) {
      const fullPath = join(workflowDir, entry)
      const stat = statSync(fullPath)

      if (
        stat.isFile() &&
        (entry.endsWith('.yml') || entry.endsWith('.yaml'))
      ) {
        files.push(fullPath)
      }
    }
  } catch (error) {
    console.warn(
      '⚠️  .github/workflows 디렉토리를 찾을 수 없습니다:',
      error.message
    )
  }

  return files
}

/**
 * GitHub Actions workflow 파일에서 pnpm 버전 업데이트
 */
function updatePnpmVersionInWorkflow(filePath, newVersion) {
  try {
    let content = readFileSync(filePath, 'utf8')
    let updated = false

    // "- name: Install pnpm" 다음에 오는 pnpm/action-setup의 version 찾기
    const regex =
      /(- name:\s*Install pnpm[\s\S]*?uses:\s*pnpm\/action-setup@[^\n]*\n\s*with:[\s\S]*?version:\s*['"]?)([^'"\n]+)(['"]?)/gi

    content = content.replace(
      regex,
      (match, prefix, currentVersion, suffix) => {
        if (currentVersion !== newVersion) {
          console.log(
            `  📝 ${filePath}에서 pnpm 버전 업데이트: ${currentVersion} → ${newVersion}`
          )
          updated = true
          return prefix + newVersion + suffix
        }
        return match
      }
    )

    if (updated) {
      writeFileSync(filePath, content, 'utf8')
      return true
    }

    return false
  } catch (error) {
    console.error(`❌ ${filePath} 업데이트 실패:`, error.message)
    return false
  }
}

/**
 * pnpm codemod-catalog 실행
 */
function runCodemodCatalog() {
  try {
    console.log('🔄 pnpm codemod-catalog 실행 중...')
    execSync('pnpx codemod pnpm/catalog', {
      cwd: rootDir,
      stdio: 'inherit'
    })

    console.log('✅ codemod-catalog 실행 완료')
  } catch (error) {
    console.error('❌ codemod-catalog 실행 실패:', error.message)
    console.error(
      '오류 세부사항:',
      error.stderr?.toString() || '알 수 없는 오류'
    )
    process.exit(1)
  }
}

/**
 * 메인 실행 함수
 */
function main() {
  console.log('🎯 sync-catalog 스크립트 시작\n')

  // 1. pnpm codemod-catalog 실행
  runCodemodCatalog()

  // 2. package.json에서 pnpm 버전 추출
  const pnpmVersion = getPnpmVersionFromPackageJson()
  console.log(`📦 현재 pnpm 버전: ${pnpmVersion}\n`)

  // 3. GitHub Actions workflow 파일들 찾기
  const workflowFiles = findWorkflowFiles()
  console.log(`🔍 발견된 workflow 파일: ${workflowFiles.length}개\n`)

  // 4. 각 workflow 파일에서 pnpm 버전 업데이트
  let totalUpdated = 0

  for (const filePath of workflowFiles) {
    console.log(`🔧 ${filePath} 처리 중...`)
    if (updatePnpmVersionInWorkflow(filePath, pnpmVersion)) {
      totalUpdated++
    } else {
      console.log(`  ℹ️  ${filePath}는 업데이트가 필요하지 않습니다.`)
    }
  }

  console.log(`\n✨ 완료! ${totalUpdated}개 파일이 업데이트되었습니다.`)

  if (totalUpdated > 0) {
    console.log('\n💡 변경사항을 커밋하는 것을 잊지 마세요!')
  }
}

// 스크립트 실행
main()
EOF
}

# Pure function to setup scripts package README
setup_scripts_readme() {
    echo -e "${GREEN}scripts 패키지 README.md 파일을 생성합니다...${NC}"

    cat > packages/scripts/README.md << 'EOF'
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
EOF
}

# Pure function to add scripts package to root devDependencies
add_scripts_to_root_dependencies() {
    local package_scope=$1

    echo -e "${GREEN}루트 package.json에 scripts 패키지 의존성을 추가합니다...${NC}"

    # Use jq if available, otherwise use Node.js
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '.devDependencies = (.devDependencies // {}) + {($scope + "/scripts"): "workspace:*"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.devDependencies = pkg.devDependencies || {};
        pkg.devDependencies['$package_scope/scripts'] = 'workspace:*';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi
}

# Pure function to setup scripts package
setup_scripts_package() {
    local package_scope=$1

    echo -e "${GREEN}scripts 패키지를 설정합니다...${NC}"
    mkdir -p packages/scripts
    cd packages/scripts

    pnpm init

    # Update package.json for scripts package
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/scripts"), "private": true, "main": "index.js", "scripts": {"version": "node sync-versions.mjs"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/scripts';
        pkg.private = true;
        pkg.main = 'index.js';
        pkg.scripts = { 'version': 'node sync-versions.mjs' };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}sync-versions.mjs 파일을 생성합니다...${NC}"
    cat > sync-versions.mjs << 'EOF'
#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 루트 package.json에서 버전 읽기
const rootPackagePath = path.join(__dirname, '..', '..', 'package.json');
const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, 'utf8'));
const rootVersion = rootPackage.version;

console.log(`Syncing all packages to version: ${rootVersion}`);

// packages 디렉토리의 모든 서브패키지 찾기
const packagesDir = path.join(__dirname, '..');
const packages = fs.readdirSync(packagesDir);

packages.forEach(packageName => {
  const packagePath = path.join(packagesDir, packageName, 'package.json');

  if (fs.existsSync(packagePath) && packageName !== 'scripts') {
    const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const oldVersion = packageJson.version;
    packageJson.version = rootVersion;

    fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\n');
    console.log(`Updated ${packageJson.name}: ${oldVersion} → ${rootVersion}`);
  }
});

console.log('Version sync completed!');
EOF

    echo -e "${GREEN}format.mjs 파일을 생성합니다...${NC}"
    cat > format.mjs << 'EOF'
#!/usr/bin/env node

import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function runCommand(command, cwd) {
  try {
    execSync(command, {
      cwd,
      stdio: 'inherit',
      encoding: 'utf8'
    });
  } catch (error) {
    console.error(`Error running command: ${command}`);
    process.exit(1);
  }
}

const projectRoot = path.resolve(__dirname, '../..');
const targetDir = process.argv[2];

if (!targetDir) {
  console.error('Usage: node format.mjs <app-directory>');
  process.exit(1);
}

const appPath = path.resolve(projectRoot, targetDir);

console.log(`Running format in ${appPath}`);

runCommand('tsc', appPath);
runCommand('prettier --write "**/*.{ts,tsx,cjs,mjs,json,html,css,js,jsx}" --cache --config prettier.config.mjs', appPath);
runCommand('eslint --fix --cache --cache-location ./node_modules/.cache/eslint .', appPath);

console.log('Format completed successfully!');
EOF

    # sync-catalog.mjs 파일 생성
    create_sync_catalog_script

    # package.json에 bin 섹션 추가
    echo -e "${GREEN}package.json에 bin 섹션을 추가합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/scripts"), "private": true, "main": "index.js", "bin": {"format-app": "./format.mjs", "sync-catalog": "./sync-catalog.mjs"}, "scripts": {"version": "node sync-versions.mjs"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/scripts';
        pkg.private = true;
        pkg.main = 'index.js';
        pkg.bin = {
            'format-app': './format.mjs',
            'sync-catalog': './sync-catalog.mjs'
        };
        pkg.scripts = { 'version': 'node sync-versions.mjs' };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    cd ../..
}

# Pure function to setup ESLint package
setup_eslint_package() {
    local package_scope=$1

    echo -e "${GREEN}ESLint 패키지를 설정합니다...${NC}"
    mkdir -p packages/eslint
    cd packages/eslint

    pnpm init

    # Update package.json for ESLint package
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/eslint"), "private": true, "main": "index.mjs"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/eslint';
        pkg.private = true;
        pkg.main = 'index.mjs';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}ESLint 의존성을 설치합니다...${NC}"
    pnpm i @eslint/js eslint globals typescript-eslint eslint-plugin-unused-imports @typescript-eslint/eslint-plugin @typescript-eslint/parser

    echo -e "${GREEN}ESLint 설정 파일을 생성합니다...${NC}"
    cat > index.mjs << 'EOF'
import js from '@eslint/js'
import globals from 'globals'
import tseslint from 'typescript-eslint'
import unusedImports from 'eslint-plugin-unused-imports'

const defaultCodeStyle = {
  files: ['**/*.{ts,tsx}'],
  languageOptions: {
    ecmaVersion: 'latest',
    globals: {
      ...globals.browser,
      ...globals.node
    }
  },
  plugins: {
    'unused-imports': unusedImports
  },
  rules: {
    'max-depth': ['error', 2],
    'padding-line-between-statements': [
      'error',
      { blankLine: 'always', prev: '*', next: 'return' },
      { blankLine: 'always', prev: '*', next: 'if' },
      { blankLine: 'always', prev: 'function', next: '*' },
      { blankLine: 'always', prev: '*', next: 'function' }
    ],
    'no-restricted-syntax': [
      'error',
      {
        selector: 'TSInterfaceDeclaration',
        message: 'Interface 대신 type 을 사용하세요.'
      },
      {
        selector: 'VariableDeclaration[kind="let"]',
        message: 'let 대신 const 를 사용하세요.'
      },
      {
        selector: 'VariableDeclaration[kind="var"]',
        message: 'var 대신 const 를 사용하세요.'
      },
      {
        selector: 'SwitchStatement',
        message: 'switch 대신 if 를 사용하세요.'
      },
      {
        selector: 'ConditionalExpression',
        message: '삼항 연산자 대신 if 를 사용하세요.'
      },
      {
        selector: 'IfStatement[alternate]',
        message: 'else 대신 early return 을 사용하세요.'
      },
      {
        selector: 'ForStatement',
        message:
          'for 루프 대신 배열 메서드(map, filter, reduce 등)를 사용하세요.'
      },
      {
        selector: 'WhileStatement',
        message: 'while 루프 대신 배열 메서드나 재귀를 사용하세요.'
      },
      {
        selector: 'DoWhileStatement',
        message: 'do-while 루프 대신 배열 메서드나 재귀를 사용하세요.'
      },
      {
        selector: 'ForInStatement',
        message:
          'for-in 루프 대신 Object.keys(), Object.values(), Object.entries()를 사용하세요.'
      },
      {
        selector: 'ForOfStatement',
        message: 'for-of 루프 대신 배열 메서드를 사용하세요.'
      },
      {
        selector: 'CallExpression[callee.property.name="push"]',
        message:
          'push() 대신 concat() 또는 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="pop"]',
        message: 'pop() 대신 slice() 메소드를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="shift"]',
        message: 'shift() 대신 slice() 메소드를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="unshift"]',
        message:
          'unshift() 대신 concat() 또는 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="splice"]',
        message:
          'splice() 대신 slice() 및 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="reverse"]',
        message:
          'reverse() 대신 [...array].reverse()를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="fill"]',
        message: 'fill() 대신 map()을 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'CallExpression[callee.property.name="copyWithin"]',
        message: 'copyWithin() 대신 map()을 사용하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="assign"]',
        message:
          'Object.assign() 대신 스프레드 연산자를 사용하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="defineProperty"]',
        message:
          'Object.defineProperty() 대신 새 객체를 생성하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="defineProperties"]',
        message:
          'Object.defineProperties() 대신 새 객체를 생성하세요. (부수효과 방지)'
      },
      {
        selector:
          'CallExpression[callee.object.name="Object"][callee.property.name="setPrototypeOf"]',
        message:
          'Object.setPrototypeOf() 대신 Object.create()를 사용하세요. (부수효과 방지)'
      },
      {
        selector: 'UnaryExpression[operator="delete"]',
        message:
          'delete 연산자 대신 새 객체를 생성하고 원하는 속성만 포함하세요. (부수효과 방지)'
      },
      {
        selector:
          'AssignmentExpression[left.type="Identifier"][left.name=/^(params?|args?|arguments|prop|props|parameter|parameters)$/]',
        message:
          '함수 파라미터는 직접 수정하지 마세요. 새 변수를 만들어 사용하세요.'
      },
      {
        selector:
          'AssignmentExpression[left.type="MemberExpression"][left.object.name=/^(params?|args?|arguments|prop|props|parameter|parameters)$/]',
        message:
          '함수 파라미터의 속성은 직접 수정하지 마세요. 객체를 복사하여 사용하세요.'
      },
      {
        selector:
          'FunctionDeclaration > BlockStatement > ExpressionStatement > AssignmentExpression[left.type="Identifier"]',
        message:
          '함수 내에서 파라미터를 재할당하지 마세요. 새 변수를 만들어 사용하세요.'
      },
      {
        selector:
          'ArrowFunctionExpression > BlockStatement > ExpressionStatement > AssignmentExpression[left.type="Identifier"]',
        message:
          '함수 내에서 파라미터를 재할당하지 마세요. 새 변수를 만들어 사용하세요.'
      }
    ],
    'no-unused-vars': 'off',
    'unused-imports/no-unused-imports': 'error',
    'unused-imports/no-unused-vars': [
      'warn',
      {
        vars: 'all',
        varsIgnorePattern: '^_',
        args: 'after-used',
        argsIgnorePattern: '^_'
      }
    ],
    'no-param-reassign': ['error', { props: true }],
    'no-shadow': 'off', // 기본 ESLint 규칙은 비활성화
    '@typescript-eslint/no-shadow': [
      'error',
      {
        builtinGlobals: true,
        hoist: 'all',
        allow: [] // 예외를 허용하고 싶은 변수 이름들
      }
    ]
  }
}

export default tseslint.config(defaultCodeStyle, {
  extends: [js.configs.recommended, ...tseslint.configs.recommended],
  files: ['**/*.{ts,tsx}'],
  languageOptions: {
    ecmaVersion: 'latest',
    globals: globals.browser
  }
})
EOF

    cd ../..
}

# Pure function to setup Prettier package
setup_prettier_package() {
    local package_scope=$1

    echo -e "${GREEN}Prettier 패키지를 설정합니다...${NC}"
    mkdir -p packages/prettier
    cd packages/prettier

    pnpm init

    # Update package.json for Prettier package
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/prettier"), "private": true, "main": "index.mjs"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/prettier';
        pkg.private = true;
        pkg.main = 'index.mjs';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}Prettier 의존성을 설치합니다...${NC}"
    pnpm i prettier prettier-plugin-classnames prettier-plugin-css-order @ianvs/prettier-plugin-sort-imports

    echo -e "${GREEN}Prettier 설정 파일을 생성합니다...${NC}"
    cat > index.mjs << 'EOF'
/** @type {import('prettier').Config} */
export default {
  endOfLine: 'lf',
  semi: false,
  singleQuote: true,
  tabWidth: 2,
  trailingComma: 'none',
  // import sort[s]
  plugins: [
    '@ianvs/prettier-plugin-sort-imports',
    'prettier-plugin-css-order',
    'prettier-plugin-classnames'
  ],
  endingPosition: 'absolute',
  importOrder: [
    '^react',
    '',
    '<BUILTIN_MODULES>',
    '<THIRD_PARTY_MODULES>',
    '',
    '.css$',
    '.scss$',
    '^[.]'
  ],
  importOrderParserPlugins: ['typescript', 'jsx', 'decorators-legacy']
  // import sort[e]
}
EOF

    cd ../..
}

# Pure function to create root config files
create_root_config_files() {
    local package_scope=$1

    echo -e "${GREEN}루트 설정 파일을 생성합니다...${NC}"

    # Create eslint.config.mjs
    echo "export { default } from '$package_scope/eslint'" > eslint.config.mjs

    # Create prettier.config.mjs
    echo "export { default } from '$package_scope/prettier'" > prettier.config.mjs
}

# Pure function to create AWS infrastructure setup script
create_aws_infra_script() {
    local package_scope=$1

    echo -e "${GREEN}AWS 인프라 설정 스크립트를 생성합니다...${NC}"
    mkdir -p packages/scripts
    
    echo -e "${GREEN}set-aws-infra.sh 파일을 생성합니다...${NC}"
    cat > packages/scripts/set-aws-infra.sh << EOF
#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if /packages/infra directory exists and ask for deletion consent
check_and_remove_infra_dir() {
    if [[ -d "packages/infra" ]]; then
        echo -e "\${YELLOW}packages/infra 디렉토리가 이미 존재합니다.\${NC}"
        echo -e "\${YELLOW}삭제하고 새로 생성하시겠습니까? (y/N):\${NC}"
        read -r response </dev/tty
        
        if [[ "\$response" =~ ^[Yy]\$ ]]; then
            echo -e "\${GREEN}기존 packages/infra 디렉토리를 삭제합니다...\${NC}"
            rm -rf packages/infra
        else
            echo -e "\${RED}작업을 취소합니다.\${NC}"
            exit 1
        fi
    fi
}

# Initialize packages/infra directory
init_infra_dir() {
    echo -e "\${GREEN}packages/infra 디렉토리를 생성하고 이동합니다...\${NC}"
    mkdir -p packages/infra
    cd packages/infra
    
    echo -e "\${GREEN}pnpm init으로 초기화합니다...\${NC}"
    pnpm init
}

# Edit package.json for infra package
edit_infra_package_json() {
    local scope_name="\$1"
    
    echo -e "\${GREEN}package.json을 편집합니다...\${NC}"
    
    if command -v jq &> /dev/null; then
        jq --arg scope "\$scope_name" '. + {"name": (\$scope + "/infra"), "scripts": {"bootstrap": "cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10", "deploy": "cdk deploy --hotswap --require-approval never --concurrency 10 --quiet", "destroy": "tsx destroy.ts"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '\$scope_name/infra';
        pkg.scripts = {
            'bootstrap': 'cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10',
            'deploy': 'cdk deploy --hotswap --require-approval never --concurrency 10 --quiet',
            'destroy': 'tsx destroy.ts'
        };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi
}

# Install dependencies
install_dependencies() {
    echo -e "\${GREEN}디펜던시를 설치합니다...\${NC}"
    pnpm i @react-router/architect aws-cdk aws-cdk-lib constructs esbuild tsx dotenv dotenv-cli
}

# Get scope name from user input or from root package.json
get_scope_name() {
    # Try to extract from root package.json first
    if [[ -f "../../package.json" ]]; then
        local scope_from_package=\$(node -e "
            try {
                const pkg = JSON.parse(require('fs').readFileSync('../../package.json', 'utf8'));
                const name = pkg.name || '';
                const match = name.match(/^(@[^/]+)\//);
                console.log(match ? match[1] : '');
            } catch (e) {
                console.log('');
            }
        ")
        
        if [[ -n "\$scope_from_package" ]]; then
            echo "\$scope_from_package"
            return
        fi
    fi
    
    # Ask user for scope name if not found
    echo -e "\${BLUE}스코프 이름을 입력하세요 (예: @company):\${NC}" >&2
    read -r scope_name </dev/tty
    echo "\$scope_name"
}

# Main execution
main() {
    echo -e "\${BLUE}=== AWS 인프라 설정을 시작합니다 ===\${NC}"
    
    # Move to project root if we're in packages/scripts
    if [[ \$(basename "\$(pwd)") == "scripts" ]]; then
        cd ../..
    fi
    
    # Get scope name
    scope_name=\$(get_scope_name)
    
    if [[ -z "\$scope_name" ]]; then
        echo -e "\${RED}스코프 이름을 입력해야 합니다.\${NC}"
        exit 1
    fi
    
    echo -e "\${YELLOW}스코프 이름: \$scope_name\${NC}"
    
    # Execute setup functions
    check_and_remove_infra_dir
    init_infra_dir
    edit_infra_package_json "\$scope_name"
    install_dependencies
    
    echo -e "\${GREEN}=== AWS 인프라 설정이 완료되었습니다! ===\${NC}"
    echo -e "\${BLUE}다음 단계: CDK 파일들을 생성하고 배포를 진행하세요.\${NC}"
}

# Run main function
main "\$@"
EOF

    # Grant execution permissions
    chmod +x packages/scripts/set-aws-infra.sh
    echo -e "${GREEN}set-aws-infra.sh에 실행 권한을 부여했습니다.${NC}"
}

# Pure function to setup infrastructure package
setup_infra_package() {
    local package_scope=$1
    local project_name=$2

    echo -e "${GREEN}Infrastructure 패키지를 설정합니다...${NC}"
    mkdir -p packages/infra
    cd packages/infra

    pnpm init

    # Update package.json for infra package with enhanced scripts
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/infra"), "private": true, "scripts": {"bootstrap": "cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10", "deploy": "cdk deploy --hotswap --require-approval never --concurrency 10 --quiet", "destroy": "tsx destroy.ts", "update-dns": "tsx update_dns.ts"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/infra';
        pkg.private = true;
        pkg.scripts = {
            'bootstrap': 'cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10',
            'deploy': 'cdk deploy --hotswap --require-approval never --concurrency 10 --quiet',
            'destroy': 'tsx destroy.ts',
            'update-dns': 'tsx update_dns.ts'
        };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}Infrastructure 의존성을 설치합니다...${NC}"
    pnpm i @react-router/architect aws-cdk aws-cdk-lib constructs esbuild tsx dotenv dotenv-cli

    echo -e "${GREEN}향상된 CDK Stack 파일을 생성합니다...${NC}"
    cat > cdk-stack.ts << 'EOF'
import * as cdk from 'aws-cdk-lib'
import { Construct } from 'constructs'
import * as lambda from 'aws-cdk-lib/aws-lambda'
import * as nodejs from 'aws-cdk-lib/aws-lambda-nodejs'
import * as s3 from 'aws-cdk-lib/aws-s3'
import * as s3deploy from 'aws-cdk-lib/aws-s3-deployment'
import * as cloudfront from 'aws-cdk-lib/aws-cloudfront'
import * as origins from 'aws-cdk-lib/aws-cloudfront-origins'

type CdkStackProps = cdk.StackProps & {
  // 람다 어댑터의 위치
  lambdaEntry: string
  // 빌드된 static asset 의 위치
  staticAssetPath: string
  // 환경 정보
  environment: string
  // 배포 성공 시 콜백 함수 (Lambda URL 전달)
  onDeploySuccess?: (lambdaUrl: string) => void | Promise<void>
  // DNS 삭제 콜백 함수
  onDestroy?: () => void | Promise<void>
}

export class CdkStack extends cdk.Stack {
  constructor(scope: Construct, id: string, props?: CdkStackProps) {
    super(scope, id, props)

    // 엔트리포인트에서 람다함수를 참조해서 빌드
    const lambdaFunction = new nodejs.NodejsFunction(this, `${id}-handler`, {
      runtime: lambda.Runtime.NODEJS_22_X,
      handler: 'handler',
      entry: props?.lambdaEntry,
      bundling: {
        externalModules: [
          '@aws-sdk/*',
          'aws-sdk' // Not actually needed (or provided): https://github.com/remix-run/react-router/issues/13341
        ],
        minify: true,
        sourceMap: true,
        target: 'es2022'
      },
      environment: {
        NODE_ENV: props?.environment || ''
      }
    })

    // Create Function URL for the Lambda
    const functionUrl = lambdaFunction.addFunctionUrl({
      authType: lambda.FunctionUrlAuthType.NONE
    })

    // Create S3 bucket for static assets
    const staticBucket = new s3.Bucket(this, `${id}-s3`, {
      enforceSSL: true,
      publicReadAccess: false,
      blockPublicAccess: s3.BlockPublicAccess.BLOCK_ALL,
      removalPolicy: cdk.RemovalPolicy.DESTROY,
      autoDeleteObjects: true
    })

    // Create CloudFront distribution
    const distribution = new cloudfront.Distribution(
      this,
      `${id}-Distribution`,
      {
        defaultBehavior: {
          origin: new origins.FunctionUrlOrigin(functionUrl),
          viewerProtocolPolicy:
            cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
          allowedMethods: cloudfront.AllowedMethods.ALLOW_ALL,
          cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
          originRequestPolicy:
            cloudfront.OriginRequestPolicy.ALL_VIEWER_EXCEPT_HOST_HEADER,
          cachePolicy: cloudfront.CachePolicy.CACHING_DISABLED
        },
        additionalBehaviors: {
          '/assets/*': {
            origin: origins.S3BucketOrigin.withOriginAccessControl(
              staticBucket,
              {
                originAccessLevels: [
                  cloudfront.AccessLevel.READ,
                  cloudfront.AccessLevel.LIST
                ]
              }
            ),
            viewerProtocolPolicy:
              cloudfront.ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
            allowedMethods: cloudfront.AllowedMethods.ALLOW_GET_HEAD_OPTIONS,
            cachedMethods: cloudfront.CachedMethods.CACHE_GET_HEAD_OPTIONS,
            cachePolicy: new cloudfront.CachePolicy(
              this,
              `${id}-StaticCachePolicy`,
              {
                headerBehavior: cloudfront.CacheHeaderBehavior.allowList(
                  'CloudFront-Viewer-Country'
                ),
                queryStringBehavior: cloudfront.CacheQueryStringBehavior.none(),
                cookieBehavior: cloudfront.CacheCookieBehavior.none(),
                defaultTtl: cdk.Duration.days(365),
                maxTtl: cdk.Duration.days(365),
                minTtl: cdk.Duration.days(365)
              }
            )
          }
        }
      }
    )

    // Deploy static assets to S3
    new s3deploy.BucketDeployment(this, `${id}-StaticAssets`, {
      sources: [s3deploy.Source.asset(props?.staticAssetPath || '')],
      destinationBucket: staticBucket,
      destinationKeyPrefix: 'assets',
      distribution,
      distributionPaths: ['/assets/*']
    })

    new cdk.CfnOutput(this, `${id}-DomainName`, {
      value: `https://${distribution.domainName}`,
      description: 'CloudFront Distribution URL'
    })

    // Lambda Function URL을 출력하고 콜백 호출
    new cdk.CfnOutput(this, `${id}-LambdaUrl`, {
      value: functionUrl.url,
      description: 'Lambda Function URL'
    })

    // 배포 성공 시 콜백 호출 (Lambda URL에서 도메인 부분만 추출)
    if (props?.onDeploySuccess) {
      // Lambda URL에서 도메인 부분만 추출 (https:// 제거하고 trailing slash 제거)
      const lambdaDomain = functionUrl.url
        .replace(/^https?:\/\//, '')
        .replace(/\/$/, '')

      // 스택 생성 후 콜백 호출을 위해 nextTick 사용
      process.nextTick(async () => {
        try {
          await props.onDeploySuccess!(lambdaDomain)
        } catch (error) {
          console.error('❌ 배포 후 처리 중 오류 발생:', error)
        }
      })
    }
  }
}
EOF

    echo -e "${GREEN}향상된 CDK 애플리케이션 파일을 생성합니다...${NC}"
    cat > cdk.ts << EOF
#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'
import { CdkStack } from './cdk-stack'
import * as path from 'path'
import { execSync } from 'child_process'
import { writeFileSync, readFileSync } from 'fs'
import { updateDNS, deleteDNS } from './update_dns'

/**
 * 프로젝트 루트의 package.json에서 프로젝트 이름을 가져오는 순수함수
 */
function getProjectName(): string {
  const packageJsonPath = path.join(__dirname, '../../package.json')
  const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf-8'))

  return packageJson.name || 'unknown-project'
}

const projectName = getProjectName()
// Get current git branch name
const branchName = execSync('git rev-parse --abbrev-ref HEAD', {
  encoding: 'utf-8'
}).trim()
const environment = process.env.NODE_ENV || 'development'
const lambdaEntry = path.join(__dirname, './entry/lambda.ts')
const staticAssetPath = path.join(
  __dirname,
  '../../apps/web/build/client/assets'
)

type EnvUpdateResult = {
  lines: string[]
  updated: boolean
}

/**
 * .env 파일 경로를 생성하는 순수함수
 */
function createEnvPath(): string {
  return path.join(__dirname, '../../.env')
}

/**
 * 환경변수 라인을 업데이트하는 순수함수
 */
function updateEnvLines(lines: string[], lambdaUrl: string): EnvUpdateResult {
  return lines.reduce<EnvUpdateResult>(
    (acc, line) => {
      if (line.startsWith('RECORD_VALUE=')) {
        return {
          lines: [...acc.lines, \`RECORD_VALUE=\${lambdaUrl}\`],
          updated: true
        }
      }

      return {
        lines: [...acc.lines, line],
        updated: acc.updated
      }
    },
    { lines: [], updated: false }
  )
}

/**
 * 새로운 환경변수 라인을 추가하는 순수함수
 */
function addEnvLine(lines: string[], lambdaUrl: string): string[] {
  return [...lines, \`RECORD_VALUE=\${lambdaUrl}\`]
}

/**
 * 로그 메시지를 생성하는 순수함수
 */
function createEnvLogMessages(lambdaUrl: string) {
  return {
    success: \`✅ .env 파일의 RECORD_VALUE가 업데이트되었습니다: \${lambdaUrl}\`,
    dnsStart: '\\n🌐 Cloudflare DNS 업데이트를 시작합니다...',
    dnsSkip: 'ℹ️ DOMAIN이 설정되지 않아 DNS 업데이트를 건너뜁니다.',
    error: '❌ .env 파일 또는 DNS 업데이트 실패:',
    manual: '\\n💡 DNS 업데이트가 실패했습니다. 수동으로 실행해주세요:',
    command: '   cd packages/infra && pnpm update-dns'
  }
}

/**
 * DNS 업데이트 에러를 확인하는 순수함수
 */
function isDomainMissingError(error: unknown): boolean {
  return (
    error instanceof Error &&
    error.message.includes('DOMAIN 환경변수가 설정되지 않아')
  )
}

/**
 * DNS 업데이트를 처리하는 순수함수
 */
async function processDNSUpdate(): Promise<void> {
  await updateDNS() // Wrangler CLI 사용
}

/**
 * DNS 업데이트를 실행하는 함수
 */
async function executeDNSUpdate(
  messages: ReturnType<typeof createEnvLogMessages>
): Promise<void> {
  console.log(messages.dnsStart)

  try {
    await processDNSUpdate()
  } catch (error) {
    if (isDomainMissingError(error)) {
      console.log(messages.dnsSkip)

      return
    }

    throw error
  }
}

/**
 * DNS 삭제를 처리하는 순수함수
 */
async function processDNSDelete(): Promise<void> {
  await deleteDNS() // Wrangler CLI 사용
}

/**
 * DNS 삭제를 실행하는 함수
 */
async function executeDNSDelete(): Promise<void> {
  console.log('\\n🗑️ Cloudflare DNS 레코드 삭제를 시작합니다...')

  try {
    await processDNSDelete()
  } catch (error) {
    if (isDomainMissingError(error)) {
      console.log('ℹ️ DOMAIN이 설정되지 않아 DNS 삭제를 건너뜁니다.')

      return
    }

    console.error('❌ DNS 삭제 실패:', error)
    console.log('\\n💡 DNS 레코드 삭제가 실패했습니다. 수동으로 실행해주세요:')
    console.log('   cd packages/infra && pnpm update-dns (Wrangler CLI로 수동 삭제)')
  }
}

const getUpdatedFinalLines = ({
  lambdaUrl,
  envPath
}: {
  lambdaUrl: string
  envPath: string
}) => {
  const envContent = readFileSync(envPath, 'utf-8')
  const lines = envContent.split('\\n')
  const updatedResult = updateEnvLines(lines, lambdaUrl)

  if (updatedResult.updated) {
    return updatedResult.lines
  }

  return addEnvLine(updatedResult.lines, lambdaUrl)
}

/**
 * .env 파일의 RECORD_VALUE를 업데이트하고 DNS를 업데이트하는 함수
 */
async function updateEnvRecordValueAndDNS(lambdaUrl: string): Promise<void> {
  const envPath = createEnvPath()
  const messages = createEnvLogMessages(lambdaUrl)

  try {
    // 1. .env 파일 업데이트
    const finalLines = getUpdatedFinalLines({ envPath, lambdaUrl })
    writeFileSync(envPath, finalLines.join('\\n'))
    console.log(messages.success)

    // 2. DNS 업데이트 실행
    await executeDNSUpdate(messages)
  } catch (error) {
    console.error(messages.error, error)
    console.log(messages.manual)
    console.log(messages.command)
  }
}

/**
 * DNS 삭제를 포함한 완전한 스택 삭제 함수
 */
export async function destroyStackWithDNS(): Promise<void> {
  console.log('🗑️ 스택 삭제 시작: DNS 레코드 및 AWS 리소스를 삭제합니다...')

  // 1. DNS 레코드 삭제 먼저 실행
  try {
    await executeDNSDelete()
  } catch (error) {
    console.warn('⚠️ DNS 삭제 중 오류가 발생했지만 스택 삭제를 계속 진행합니다:', error)
  }

  // 2. CDK 스택 삭제
  console.log('\\n🔥 AWS CDK 스택 삭제 중...')
  try {
    execSync('npx cdk destroy --force', { 
      stdio: 'inherit',
      cwd: __dirname 
    })
    console.log('✅ 스택 삭제가 완료되었습니다!')
  } catch (error) {
    console.error('❌ CDK 스택 삭제 실패:', error)
    throw error
  }
}

const app = new cdk.App()
new CdkStack(app, \`\${projectName}-\${branchName}\`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT || process.env.AWS_ACCOUNT_ID,
    region:
      process.env.CDK_DEFAULT_REGION ||
      process.env.AWS_DEFAULT_REGION ||
      'ap-northeast-2'
  },
  lambdaEntry,
  staticAssetPath,
  environment,
  tags: {
    Environment: environment,
    Project: projectName
  },
  onDeploySuccess: updateEnvRecordValueAndDNS
})
EOF

    echo -e "${GREEN}CDK 설정 파일을 생성합니다...${NC}"
    cat > cdk.json << 'EOF'
{
  "app": "pnpm tsx cdk.ts",
  "watch": {
    "include": [
      "**"
    ],
    "exclude": [
      "README.md",
      "cdk*.json",
      "**/*.d.ts",
      "**/*.js",
      "tsconfig.json",
      "package*.json",
      "yarn.lock",
      "node_modules",
      "test"
    ]
  },
  "context": {
    "@aws-cdk/aws-lambda:recognizeLayerVersion": true,
    "@aws-cdk/core:checkSecretUsage": true,
    "@aws-cdk/core:target-partitions": [
      "aws",
      "aws-cn"
    ],
    "@aws-cdk-containers/ecs-service-extensions:enableDefaultLogDriver": true,
    "@aws-cdk/aws-ec2:uniqueImdsv2TemplateName": true,
    "@aws-cdk/aws-ecs:arnFormatIncludesClusterName": true,
    "@aws-cdk/aws-iam:minimizePolicies": true,
    "@aws-cdk/core:validateSnapshotRemovalPolicy": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeyAliasStackSafeResourceName": true,
    "@aws-cdk/aws-s3:createDefaultLoggingPolicy": true,
    "@aws-cdk/aws-sns-subscriptions:restrictSqsDescryption": true,
    "@aws-cdk/aws-apigateway:disableCloudWatchRole": true,
    "@aws-cdk/core:enablePartitionLiterals": true,
    "@aws-cdk/aws-events:eventsTargetQueueSameAccount": true,
    "@aws-cdk/aws-ecs:disableExplicitDeploymentControllerForCircuitBreaker": true,
    "@aws-cdk/aws-iam:importedRoleStackSafeDefaultPolicyName": true,
    "@aws-cdk/aws-s3:serverAccessLogsUseBucketPolicy": true,
    "@aws-cdk/aws-route53-patters:useCertificate": true,
    "@aws-cdk/customresources:installLatestAwsSdkDefault": false,
    "@aws-cdk/aws-rds:databaseProxyUniqueResourceName": true,
    "@aws-cdk/aws-codedeploy:removeAlarmsFromDeploymentGroup": true,
    "@aws-cdk/aws-apigateway:authorizerChangeDeploymentLogicalId": true,
    "@aws-cdk/aws-ec2:launchTemplateDefaultUserData": true,
    "@aws-cdk/aws-secretsmanager:useAttachedSecretResourcePolicyForSecretTargetAttachments": true,
    "@aws-cdk/aws-redshift:columnId": true,
    "@aws-cdk/aws-stepfunctions-tasks:enableEmrServicePolicyV2": true,
    "@aws-cdk/aws-ec2:restrictDefaultSecurityGroup": true,
    "@aws-cdk/aws-apigateway:requestValidatorUniqueId": true,
    "@aws-cdk/aws-kms:aliasNameRef": true,
    "@aws-cdk/aws-autoscaling:generateLaunchTemplateInsteadOfLaunchConfig": true,
    "@aws-cdk/core:includePrefixInUniqueNameGeneration": true,
    "@aws-cdk/aws-efs:denyAnonymousAccess": true,
    "@aws-cdk/aws-opensearchservice:enableOpensearchMultiAzWithStandby": true,
    "@aws-cdk/aws-lambda-nodejs:useLatestRuntimeVersion": true,
    "@aws-cdk/aws-efs:mountTargetOrderInsensitiveLogicalId": true,
    "@aws-cdk/aws-rds:auroraClusterChangeScopeOfInstanceParameterGroupWithEachParameters": true,
    "@aws-cdk/aws-appsync:useArnForSourceApiAssociationIdentifier": true,
    "@aws-cdk/aws-rds:preventRenderingDeprecatedCredentials": true,
    "@aws-cdk/aws-codepipeline-actions:useNewDefaultBranchForCodeCommitSource": true,
    "@aws-cdk/aws-cloudwatch-actions:changeLambdaPermissionLogicalIdForLambdaAction": true,
    "@aws-cdk/aws-codepipeline:crossAccountKeysDefaultValueToFalse": true,
    "@aws-cdk/aws-codepipeline:defaultPipelineTypeToV2": true,
    "@aws-cdk/aws-kms:reduceCrossAccountRegionPolicyScope": true,
    "@aws-cdk/aws-eks:nodegroupNameAttribute": true,
    "@aws-cdk/aws-ec2:ebsDefaultGp3Volume": true,
    "@aws-cdk/aws-ecs:removeDefaultDeploymentAlarm": true,
    "@aws-cdk/custom-resources:logApiResponseDataPropertyTrueDefault": false,
    "@aws-cdk/aws-s3:keepNotificationInImportedBucket": false,
    "@aws-cdk/aws-ecs:enableImdsBlockingDeprecatedFeature": false,
    "@aws-cdk/aws-ecs:disableEcsImdsBlocking": true,
    "@aws-cdk/aws-ecs:reduceEc2FargateCloudWatchPermissions": true,
    "@aws-cdk/aws-dynamodb:resourcePolicyPerReplica": true,
    "@aws-cdk/aws-ec2:ec2SumTImeoutEnabled": true,
    "@aws-cdk/aws-appsync:appSyncGraphQLAPIScopeLambdaPermission": true,
    "@aws-cdk/aws-rds:setCorrectValueForDatabaseInstanceReadReplicaInstanceResourceId": true,
    "@aws-cdk/core:cfnIncludeRejectComplexResourceUpdateCreatePolicyIntrinsics": true,
    "@aws-cdk/aws-lambda-nodejs:sdkV3ExcludeSmithyPackages": true,
    "@aws-cdk/aws-stepfunctions-tasks:fixRunEcsTaskPolicy": true,
    "@aws-cdk/aws-ec2:bastionHostUseAmazonLinux2023ByDefault": true,
    "@aws-cdk/aws-route53-targets:userPoolDomainNameMethodWithoutCustomResource": true,
    "@aws-cdk/aws-elasticloadbalancingV2:albDualstackWithoutPublicIpv4SecurityGroupRulesDefault": true,
    "@aws-cdk/aws-iam:oidcRejectUnauthorizedConnections": true,
    "@aws-cdk/core:enableAdditionalMetadataCollection": true
  }
}
EOF

    echo -e "${GREEN}Lambda entry 파일을 생성합니다...${NC}"
    mkdir -p entry
    cat > entry/lambda.ts << EOF
import { createRequestHandler } from '@react-router/architect'
// @ts-expect-error (no types declared for build)
import * as build from '$package_scope/web/build/server'

export const handler = createRequestHandler({
  build,
  mode: process.env.NODE_ENV
})
EOF

    echo -e "${GREEN}DNS 관리 파일을 생성합니다...${NC}"
    cat > update_dns.ts << 'EOF'
import { execSync } from 'node:child_process'
import { config } from 'dotenv'
import { join } from 'node:path'

// .env 파일에서 환경변수 로드 (프로젝트 루트에서)
config({ path: join(__dirname, '../../.env') })

type CloudflareRecord = {
  id?: string
  type: string
  name: string
  content: string
  ttl: number
}

type DNSConfig = {
  apiToken: string
  accountId: string
  domain: string
  subdomain?: string
  recordType: string
  recordValue: string
  ttl: number
}

/**
 * 환경변수에서 필요한 값을 가져오는 순수함수
 */
function getRequiredEnv(key: string): string {
  const value = process.env[key]

  if (!value) {
    throw new Error(`❌ 필수 환경변수가 설정되지 않았습니다: ${key}`)
  }

  return value
}

/**
 * 환경변수에서 DNS 설정을 구성하는 순수함수
 * DOMAIN이 없으면 null을 반환하여 DNS 업데이트를 건너뛸 수 있도록 함
 */
function createDNSConfig(): DNSConfig | null {
  // DOMAIN이 없으면 DNS 업데이트를 하지 않음
  const domain = process.env.DOMAIN

  if (!domain) {
    return null
  }

  return {
    apiToken: getRequiredEnv('CLOUDFLARE_API_TOKEN'),
    accountId: getRequiredEnv('CLOUDFLARE_ACCOUNT_ID'),
    domain,
    recordType: getRequiredEnv('RECORD_TYPE'),
    recordValue: getRequiredEnv('RECORD_VALUE'),
    subdomain: process.env.SUBDOMAIN, // 선택사항 - 없으면 메인 도메인 사용
    ttl: Number.parseInt(process.env.TTL || '300', 10)
  }
}

/**
 * 전체 도메인을 생성하는 순수함수
 */
function getFullDomain(domain: string, subdomain?: string): string {
  if (subdomain) {
    return `${subdomain}.${domain}`
  }

  return domain
}

/**
 * DNS 레코드 객체를 생성하는 순수함수
 */
function createDNSRecord(dnsConfig: DNSConfig): CloudflareRecord {
  return {
    type: dnsConfig.recordType,
    name: getFullDomain(dnsConfig.domain, dnsConfig.subdomain),
    content: dnsConfig.recordValue,
    ttl: dnsConfig.ttl
  }
}

/**
 * Wrangler CLI 명령어를 생성하는 순수함수
 */
function createWranglerCommand(
  action: 'create' | 'update' | 'list' | 'delete',
  domain: string,
  record?: CloudflareRecord,
  recordId?: string
): string {
  if (action === 'list') {
    return `wrangler dns list --zone ${domain} --type ${record?.type || 'A'}`
  }

  if (action === 'create') {
    if (!record) throw new Error('레코드 정보가 필요합니다')

    return `wrangler dns create ${domain} "${record.name}" ${record.type} "${record.content}" --ttl ${record.ttl}`
  }

  if (action === 'update') {
    if (!record || !recordId) throw new Error('레코드 정보와 ID가 필요합니다')

    return `wrangler dns update ${domain} ${recordId} --type ${record.type} --content "${record.content}" --ttl ${record.ttl}`
  }

  if (action === 'delete') {
    if (!recordId) throw new Error('삭제할 레코드 ID가 필요합니다')

    return `wrangler dns delete ${domain} ${recordId}`
  }

  throw new Error(`지원하지 않는 액션: ${action}`)
}

/**
 * Wrangler CLI 출력에서 기존 레코드를 찾는 순수함수
 */
function parseWranglerOutput(
  output: string,
  fullDomain: string,
  recordType: string,
  dnsConfig: DNSConfig
): CloudflareRecord | null {
  const lines = output.split('\n')

  const matchingLine = lines.find(
    (line) => line.includes(fullDomain) && line.includes(recordType)
  )

  if (matchingLine) {
    const parts = matchingLine.trim().split(/\s+/)

    if (parts.length > 0) {
      return {
        id: parts[0],
        type: recordType,
        name: fullDomain,
        content: dnsConfig.recordValue,
        ttl: dnsConfig.ttl
      }
    }
  }

  return null
}

/**
 * 로그 메시지를 생성하는 순수함수
 */
function createLogMessages(dnsConfig: DNSConfig) {
  const fullDomain = getFullDomain(dnsConfig.domain, dnsConfig.subdomain)

  return {
    config: [
      '🔧 DNS 업데이트 설정:',
      `   도메인: ${fullDomain}`,
      `   레코드 타입: ${dnsConfig.recordType}`,
      `   대상: ${dnsConfig.recordValue}`,
      `   TTL: ${dnsConfig.ttl}초`
    ].join('\n'),
    wranglerStart: '🌐 Wrangler CLI를 사용하여 DNS 레코드 업데이트 중...',
    recordFound: '📝 기존 DNS 레코드 발견, 업데이트 중...',
    recordCreate: '➕ 새 DNS 레코드 생성 중...',
    recordNotFound: '🔍 기존 레코드 없음, 새로 생성합니다.',
    success: '✅ DNS 레코드 업데이트 완료!',
    complete: '🎉 DNS 업데이트가 완료되었습니다!'
  }
}

/**
 * Cloudflare DNS 레코드를 업데이트하는 클래스
 */
export class CloudflareDNSUpdater {
  private readonly dnsConfig: DNSConfig
  private readonly messages: ReturnType<typeof createLogMessages>

  constructor(dnsConfig?: DNSConfig) {
    const _config = dnsConfig || createDNSConfig()

    if (!_config) {
      throw new Error(
        '❌ DOMAIN 환경변수가 설정되지 않아 DNS 업데이트를 건너뜁니다.'
      )
    }

    this.dnsConfig = _config
    this.messages = createLogMessages(this.dnsConfig)

    console.log(this.messages.config)
  }

  /**
   * Wrangler CLI를 사용하여 DNS 레코드 업데이트
   */
  async updateDNSWithWrangler(): Promise<void> {
    try {
      console.log(this.messages.wranglerStart)

      // Wrangler 설치 확인
      this.checkWranglerInstallation()

      // 현재 DNS 레코드 조회
      const existingRecord = await this.findExistingRecordWithWrangler()
      const record = createDNSRecord(this.dnsConfig)

      if (!existingRecord) {
        console.log(this.messages.recordCreate)
        await this.executeWranglerCreate(record)

        console.log(this.messages.success)

        return
      }

      console.log(this.messages.recordFound)
      await this.executeWranglerUpdate(existingRecord.id!, record)

      console.log(this.messages.success)
    } catch (error) {
      console.error('❌ DNS 업데이트 실패:', error)
      throw error
    }
  }

  /**
   * Wrangler 설치 확인
   */
  private checkWranglerInstallation(): void {
    try {
      execSync('wrangler --version', { stdio: 'pipe' })
    } catch {
      throw new Error(
        '❌ Wrangler CLI가 설치되지 않았습니다. npm install -g wrangler 명령으로 설치해주세요.'
      )
    }
  }

  /**
   * 기존 DNS 레코드 찾기 (Wrangler CLI 사용)
   */
  private async findExistingRecordWithWrangler(): Promise<CloudflareRecord | null> {
    try {
      const command = createWranglerCommand('list', this.dnsConfig.domain, {
        type: this.dnsConfig.recordType
      } as CloudflareRecord)
      const output = execSync(command, {
        encoding: 'utf8',
        env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
      })

      const fullDomain = getFullDomain(
        this.dnsConfig.domain,
        this.dnsConfig.subdomain
      )

      return parseWranglerOutput(
        output,
        fullDomain,
        this.dnsConfig.recordType,
        this.dnsConfig
      )
    } catch {
      console.log(this.messages.recordNotFound)

      return null
    }
  }

  /**
   * DNS 레코드 생성 (Wrangler CLI 사용)
   */
  private async executeWranglerCreate(record: CloudflareRecord): Promise<void> {
    const command = createWranglerCommand(
      'create',
      this.dnsConfig.domain,
      record
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
  }

  /**
   * DNS 레코드 업데이트 (Wrangler CLI 사용)
   */
  private async executeWranglerUpdate(
    recordId: string,
    record: CloudflareRecord
  ): Promise<void> {
    const command = createWranglerCommand(
      'update',
      this.dnsConfig.domain,
      record,
      recordId
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
  }

  /**
   * Wrangler CLI를 사용하여 DNS 레코드 삭제
   */
  async deleteDNSWithWrangler(): Promise<void> {
    try {
      console.log('🗑️ Wrangler CLI를 사용하여 DNS 레코드 삭제 중...')

      // Wrangler 설치 확인
      this.checkWranglerInstallation()

      // 현재 DNS 레코드 조회
      const existingRecord = await this.findExistingRecordWithWrangler()

      if (!existingRecord) {
        console.log('ℹ️ 삭제할 DNS 레코드가 없습니다.')

        return
      }

      console.log(`🗑️ DNS 레코드 삭제 중... (ID: ${existingRecord.id})`)
      await this.executeWranglerDelete(existingRecord.id!)

      console.log('✅ DNS 레코드 삭제 완료!')
    } catch (error) {
      console.error('❌ DNS 레코드 삭제 실패:', error)
      throw error
    }
  }

  /**
   * DNS 레코드 삭제 (Wrangler CLI 사용)
   */
  private async executeWranglerDelete(recordId: string): Promise<void> {
    const command = createWranglerCommand(
      'delete',
      this.dnsConfig.domain,
      undefined,
      recordId
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
  }
}

/**
 * DNS 업데이트 실행 함수 (Wrangler CLI만 사용)
 * @param dnsConfig 선택적 DNS 설정 (없으면 환경변수에서 자동 생성)
 */
export async function updateDNS(dnsConfig?: DNSConfig): Promise<void> {
  const updater = new CloudflareDNSUpdater(dnsConfig)
  await updater.updateDNSWithWrangler()
}

/**
 * DNS 삭제 실행 함수 (Wrangler CLI만 사용)
 * @param dnsConfig 선택적 DNS 설정 (없으면 환경변수에서 자동 생성)
 */
export async function deleteDNS(dnsConfig?: DNSConfig): Promise<void> {
  try {
    const updater = new CloudflareDNSUpdater(dnsConfig)
    await updater.deleteDNSWithWrangler()
  } catch (error) {
    if (error instanceof Error && error.message.includes('DOMAIN 환경변수가 설정되지 않아')) {
      console.log('ℹ️ DOMAIN 환경변수가 설정되지 않아 DNS 삭제를 건너뜁니다.')

      return
    }
    throw error
  }
}

/**
 * 메인 실행 함수
 */
async function runMain(): Promise<void> {
  try {
    const dnsConfig = createDNSConfig()

    // DOMAIN이 없으면 DNS 업데이트를 건너뜀
    if (!dnsConfig) {
      console.log(
        'ℹ️ DOMAIN 환경변수가 설정되지 않아 DNS 업데이트를 건너뜁니다.'
      )

      return
    }

    const messages = createLogMessages(dnsConfig)

    console.log('🔧 Wrangler CLI 모드로 실행...')
    await updateDNS(dnsConfig)

    console.log(messages.complete)
  } catch (error) {
    console.error('❌ DNS 업데이트 실패:', error)
    process.exit(1)
  }
}

/**
 * 스크립트가 직접 실행될 때
 */
if (require.main === module) {
  runMain().catch((error) => {
    console.error('❌ 스크립트 실행 실패:', error)
    process.exit(1)
  })
}
EOF

    echo -e "${GREEN}스택 삭제 스크립트를 생성합니다...${NC}"
    cat > destroy.ts << 'EOF'
#!/usr/bin/env node
import { destroyStackWithDNS } from './cdk'

/**
 * DNS 레코드와 AWS 리소스를 모두 삭제하는 스크립트
 */
async function main(): Promise<void> {
  try {
    await destroyStackWithDNS()
  } catch (error) {
    console.error('❌ 전체 삭제 프로세스 실패:', error)
    process.exit(1)
  }
}

// 스크립트가 직접 실행될 때
if (require.main === module) {
  main().catch((error) => {
    console.error('❌ 스크립트 실행 실패:', error)
    process.exit(1)
  })
}
EOF

    echo -e "${GREEN}Infrastructure README.md 파일을 생성합니다...${NC}"
    cat > README.md << 'EOF'
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
EOF

    cd ../..
}


# Pure function to setup React Router web app
setup_react_router_web() {
    local package_scope=$1

    echo -e "${GREEN}React Router 웹 앱을 생성합니다...${NC}"

    # Move to apps directory and create React Router project
    cd apps
    pnpm create react-router@latest web --no-install --no-git-init

    # Move to web directory and update package.json
    cd web

    echo -e "${GREEN}package.json의 name 필드를 업데이트합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '. + {"name": ($scope + "/web")}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$package_scope/web';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}devDependencies에 scripts, eslint, prettier 패키지를 추가합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '.devDependencies += {($scope + "/scripts"): "workspace:*", ($scope + "/eslint"): "workspace:*", ($scope + "/prettier"): "workspace:*"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.devDependencies = pkg.devDependencies || {};
        pkg.devDependencies['$package_scope/scripts'] = 'workspace:*';
        pkg.devDependencies['$package_scope/eslint'] = 'workspace:*';
        pkg.devDependencies['$package_scope/prettier'] = 'workspace:*';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}npm scripts에 format 스크립트를 추가합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq '.scripts += {"format": "format-app apps/web"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.scripts = pkg.scripts || {};
        pkg.scripts.format = 'format-app apps/web';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}eslint.config.mjs 파일을 생성합니다...${NC}"
    cat > eslint.config.mjs << EOF
import defaultConfig from '$package_scope/eslint'

export default [
  ...defaultConfig,
  {
    ignores: ['build/**', 'node_modules/**', '.react-router']
  }
]
EOF

    echo -e "${GREEN}prettier.config.mjs 파일을 생성합니다...${NC}"
    cat > prettier.config.mjs << EOF
export { default } from '$package_scope/prettier'
EOF

    echo -e "${GREEN}tsconfig.json에 extends 설정을 추가합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq '. + {"extends": "../../tsconfig.json"}' tsconfig.json > tsconfig.json.tmp && mv tsconfig.json.tmp tsconfig.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const config = JSON.parse(fs.readFileSync('tsconfig.json', 'utf8'));
        config.extends = '../../tsconfig.json';
        fs.writeFileSync('tsconfig.json', JSON.stringify(config, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}의존성을 설치하고 타입 체크를 실행합니다...${NC}"
    pnpm i
    pnpm typecheck

    echo -e "${GREEN}root.tsx 파일에 FC import를 추가합니다...${NC}"
    # Add FC import to the top of root.tsx
    sed -i.bak '1i\
import type { FC } from '\''react'\''
' app/root.tsx
    rm -f app/root.tsx.bak

    echo -e "${GREEN}root.tsx 파일의 ErrorBoundary 함수를 수정합니다...${NC}"
    # Create temporary file with new ErrorBoundary code
    cat > /tmp/new_error_boundary.tsx << 'EOF'
// 오류 UI 렌더링을 위한 함수
const ErrorBoundaryUI: FC<{
  message: string
  details: string
  stack?: string
}> = ({ message, stack, details }) => {
  return (
    <main className="pt-16 p-4 container mx-auto">
      <h1>{message}</h1>
      <p>{details}</p>
      {stack && (
        <pre className="w-full p-4 overflow-x-auto">
          <code>{stack}</code>
        </pre>
      )}
    </main>
  )
}

export function ErrorBoundary({ error }: Route.ErrorBoundaryProps) {
  // 기본 오류 메시지 설정
  const defaultMessage = 'Oops!'
  const defaultDetails = 'An unexpected error occurred.'

  // 404 오류 처리
  if (isRouteErrorResponse(error) && error.status === 404) {
    return (
      <ErrorBoundaryUI
        message="404"
        details="The requested page could not be found."
      />
    )
  }

  // 기타 라우트 오류 처리
  if (isRouteErrorResponse(error)) {
    return (
      <ErrorBoundaryUI
        message="Error"
        details={error.statusText || defaultDetails}
      />
    )
  }

  // 개발 환경에서의 일반 오류 처리
  if (import.meta.env.DEV && error && error instanceof Error) {
    return (
      <ErrorBoundaryUI
        message={defaultMessage}
        details={error.message}
        stack={error.stack}
      />
    )
  }

  // 기본 오류 UI 반환
  return <ErrorBoundaryUI message={defaultMessage} details={defaultDetails} />
}
EOF

    # Replace ErrorBoundary function in root.tsx
    node -e "
    const fs = require('fs');
    const content = fs.readFileSync('app/root.tsx', 'utf8');
    const newErrorBoundary = fs.readFileSync('/tmp/new_error_boundary.tsx', 'utf8');
    
    // Remove existing ErrorBoundary function
    const result = content.replace(/export function ErrorBoundary[^}]*}(?:\s*})*/, newErrorBoundary);
    
    fs.writeFileSync('app/root.tsx', result);
    "
    
    # Clean up temporary file
    rm -f /tmp/new_error_boundary.tsx

    echo -e "${GREEN}home.tsx 파일을 수정합니다...${NC}"
    cat > app/routes/home.tsx << 'EOF'
import { Welcome } from '~/welcome/welcome'

export function meta() {
  return [
    { title: 'New React Router App' },
    { name: 'description', content: 'Welcome to React Router!' }
  ]
}

export default function Home() {
  return <Welcome />
}
EOF

    cd ../..
}

# Pure function to setup VS Code workspace settings
setup_vscode_workspace() {
    echo -e "${GREEN}.vscode 워크스페이스 설정을 생성합니다...${NC}"
    mkdir -p .vscode

    echo -e "${GREEN}.vscode/extensions.json 파일을 생성합니다...${NC}"
    cat > .vscode/extensions.json << 'EOF'
{
  "recommendations": ["dbaeumer.vscode-eslint", "esbenp.prettier-vscode"]
}
EOF

    echo -e "${GREEN}.vscode/settings.json 파일을 생성합니다...${NC}"
    cat > .vscode/settings.json << 'EOF'
{
  "explorer.compactFolders": false,
  "typescript.tsdk": "node_modules/typescript/lib",
  "prettier.prettierPath": "./node_modules/prettier",
  "prettier.configPath": "prettier.config.mjs",
  "eslint.options": {
    "overrideConfigFile": "eslint.config.mjs"
  },
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode",
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": "explicit"
  },
  "[javascript]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.formatOnSave": true,
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "local-history.browser.descending": false
}
EOF
}

# Pure function to create project README
create_project_readme() {
    echo -e "${GREEN}프로젝트 README.md 파일을 생성합니다...${NC}"
    
    cat > README.md << 'EOF'
# 주요 명령어

## 개발서버 시작
```shell
pnpm dev
```

## prettier + eslint 실행
```shell
pnpm format
```

## pnpm 카탈로그 업데이트
```shell
pnpm sync-catalog
```

## aws 인프라 업데이트
```shell
pnpm bootstrap
```

## aws 인프라 배포
```shell
pnpm deploy
```

## aws 인프라 파괴
```shell
pnpm destroy
```
EOF
}

# Pure function to create .env file template
create_env_template() {
    echo -e "${GREEN}.env 파일 템플릿을 생성합니다...${NC}"
    
    if [[ -f ".env" ]]; then
        echo -e "${YELLOW}.env 파일이 이미 존재합니다.${NC}"
        echo -e "${YELLOW}덮어쓰시겠습니까? (y/N):${NC}"
        read -r response </dev/tty
        
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}.env 파일 생성을 건너뜁니다.${NC}"
            return
        fi
    fi
    
    cat > .env << 'EOF'
# 텔레그램토큰
TELEGRAM_TOKEN=
# 텔레그램 채팅 아이디
TELEGRAM_CHAT_ID=
# 12자리 AWS 계정 아이디
AWS_ACCOUNT_ID=
# aws 리전
AWS_DEFAULT_REGION=ap-northeast-2
# 클라우드 플레어 API 토큰
CLOUDFLARE_API_TOKEN=
# 클라우드 플레어 어카운트 아이디
CLOUDFLARE_ACCOUNT_ID=
# 도메인(필수, 없으면 클라우드 플레어 DNS 레코드를 업데이트하지 않음)
DOMAIN=
# 서브도메인(옵션)
SUBDOMAIN=
# 도메인 레코드 타입(A, AAAA, CNAME 등, )
# aws lambda 와 cloudflare workers는 고정 IP가 없으므로 CNAME으로 연계 
RECORD_TYPE=CNAME
# 대상 도메인(aws lambda 또는 cloudflare workers의 도메인)
RECORD_VALUE=
# 캐시 유효시간(기본값: 5분)
TTL=300
EOF
    
    echo -e "${GREEN}.env 파일이 생성되었습니다.${NC}"
}

# Pure function to update .gitignore with .env if not present
update_gitignore_with_env() {
    echo -e "${GREEN}.gitignore에 .env 항목을 확인하고 추가합니다...${NC}"
    
    if [[ -f ".gitignore" ]]; then
        if grep -q "^\.env$" .gitignore; then
            echo -e "${BLUE}.env 항목이 이미 .gitignore에 있습니다.${NC}"
        else
            echo -e "${GREEN}.env 항목을 .gitignore에 추가합니다...${NC}"
            echo ".env" >> .gitignore
        fi
    else
        echo -e "${YELLOW}.gitignore 파일이 없습니다. .env 항목만으로 생성합니다...${NC}"
        echo ".env" > .gitignore
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}=== 프로젝트 스캐폴딩을 시작합니다 ===${NC}"

    # Check if pnpm is installed and get version
    pnpm_version=$(check_pnpm_installed)

    # Get user inputs
    inputs=$(get_project_inputs)
    project_name=$(echo "$inputs" | cut -d' ' -f1)
    package_scope=$(echo "$inputs" | cut -d' ' -f2)

    echo -e "${YELLOW}프로젝트명: $project_name${NC}"
    echo -e "${YELLOW}패키지 스코프: $package_scope${NC}"

    # Execute setup functions in order
    init_project "$project_name"
    setup_gitignore
    setup_types_node
    setup_typescript
    setup_vscode_workspace
    setup_semantic_release "$pnpm_version"
    create_aws_deployment_workflow "$pnpm_version"
    setup_package_json_private "$pnpm_version"
    setup_turborepo
    setup_husky
    create_workspace_structure "$package_scope" "$project_name"
    setup_scripts_package "$package_scope"
    setup_scripts_readme
    add_scripts_to_root_dependencies "$package_scope"
    setup_eslint_package "$package_scope"
    setup_prettier_package "$package_scope"
    create_root_config_files "$package_scope"
    setup_react_router_web "$package_scope"
    create_aws_infra_script "$package_scope"
    setup_infra_package "$package_scope" "$project_name"
    create_project_readme
    create_env_template
    update_gitignore_with_env
    setup_vscode_workspace

    echo -e "${GREEN}=== 프로젝트 스캐폴딩이 완료되었습니다! ===${NC}"
    echo -e "${BLUE}프로젝트 디렉토리: $(pwd)${NC}"
}

# Run main function
main "$@"
