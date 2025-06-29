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

    # Get script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/copy-template.sh"
    
    copy_template "tsconfig.json" "tsconfig.json"
}

# Pure function to setup semantic-release
setup_semantic_release() {
    local pnpm_version=$1

    echo -e "${GREEN}semantic-release를 설치합니다...${NC}"
    pnpm i -D semantic-release @semantic-release/commit-analyzer @semantic-release/release-notes-generator @semantic-release/changelog @semantic-release/npm @semantic-release/github @semantic-release/git

    # Get script directory
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/copy-template.sh"
    
    copy_template "release.config.ts" "release.config.ts"

    echo -e "${GREEN}GitHub Actions workflow 디렉토리를 생성합니다...${NC}"
    mkdir -p .github/workflows

    copy_template "semantic-release.yml" ".github/workflows/semantic-release.yml" "$pnpm_version"
}

# Pure function to create AWS Lambda deployment workflow
create_aws_deployment_workflow() {
    local pnpm_version=$1

    echo -e "${GREEN}AWS Lambda 배포 GitHub Actions workflow를 생성합니다...${NC}"
    copy_template "deploy-aws-lambda.yml" ".github/workflows/deploy-aws-lambda.yml" "$pnpm_version"
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
    copy_template "lambda.ts" "entry/lambda.ts" "$package_scope"

    echo -e "${GREEN}DNS 관리 파일을 생성합니다...${NC}"
    copy_template "update_dns.ts" "update_dns.ts"

    echo -e "${GREEN}스택 삭제 스크립트를 생성합니다...${NC}"
    copy_template "destroy.ts" "destroy.ts"

    echo -e "${GREEN}Infrastructure README.md 파일을 생성합니다...${NC}"
    copy_template "infrastructure-readme.md" "README.md"

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
    copy_template "eslint.config.mjs" "eslint.config.mjs" "$package_scope"

    echo -e "${GREEN}prettier.config.mjs 파일을 생성합니다...${NC}"
    copy_template "prettier.config.mjs" "prettier.config.mjs" "$package_scope"

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
    # Copy ErrorBoundary template to temporary file
    copy_template "error-boundary.tsx" "/tmp/new_error_boundary.tsx"

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
    copy_template "home.tsx" "app/routes/home.tsx"

    cd ../..
}

# Pure function to setup VS Code workspace settings
setup_vscode_workspace() {
    echo -e "${GREEN}.vscode 워크스페이스 설정을 생성합니다...${NC}"
    mkdir -p .vscode

    # Get script directory and source template helper
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    source "$script_dir/copy-template.sh"
    
    copy_template "vscode-extensions.json" ".vscode/extensions.json"
    copy_template "vscode-settings.json" ".vscode/settings.json"
}

# Pure function to create project README
create_project_readme() {
    echo -e "${GREEN}프로젝트 README.md 파일을 생성합니다...${NC}"
    
    copy_template "README.md" "README.md"
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
    
    copy_template ".env.template" ".env"
    
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
