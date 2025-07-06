#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# GitHub repository configuration
GITHUB_REPO_URL="https://raw.githubusercontent.com/shoveller/initial-script-recipes"
GITHUB_BRANCH="main"
TEMPLATE_CACHE_DIR="$HOME/.prj-templates"

# Create cache directory if it doesn't exist
mkdir -p "$TEMPLATE_CACHE_DIR"

# Function to check internet connectivity
check_internet_connection() {
    if command -v curl &> /dev/null; then
        curl -s --connect-timeout 5 --max-time 10 "$GITHUB_REPO_URL/$GITHUB_BRANCH/README.md" > /dev/null 2>&1
        return $?
    else
        echo -e "${RED}curl이 설치되어 있지 않습니다. curl을 설치해주세요.${NC}" >&2
        return 1
    fi
}

# Function to clear template cache
clear_template_cache() {
    echo -e "${YELLOW}템플릿 캐시를 정리합니다...${NC}"
    rm -rf "$TEMPLATE_CACHE_DIR"
    mkdir -p "$TEMPLATE_CACHE_DIR"
}

# Function to download a single template file from GitHub
download_template_file() {
    local template_file=$1
    local target_file=$2
    local github_url="$GITHUB_REPO_URL/$GITHUB_BRANCH/prj-scripts/$template_file"
    local cache_file="$TEMPLATE_CACHE_DIR/$template_file"
    
    # Create cache directory structure if needed
    local cache_dir
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir"
    
    echo -e "${BLUE}템플릿 다운로드 중: $template_file${NC}"
    
    if curl -s -f -o "$cache_file" "$github_url"; then
        echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
        cp "$cache_file" "$target_file"
        return 0
    else
        echo -e "${RED}템플릿 다운로드 실패: $template_file${NC}" >&2
        return 1
    fi
}

# Function to download template file with variable substitution
download_template_with_vars() {
    local template_file=$1
    local target_file=$2
    shift 2
    
    local github_url="$GITHUB_REPO_URL/$GITHUB_BRANCH/prj-scripts/$template_file"
    local cache_file="$TEMPLATE_CACHE_DIR/$template_file"
    
    # Create cache directory structure if needed
    local cache_dir
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir"
    
    echo -e "${BLUE}템플릿 다운로드 중: $template_file${NC}"
    
    if curl -s -f -o "$cache_file" "$github_url"; then
        echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
        
        # Start with the template content
        local temp_content
        temp_content=$(cat "$cache_file")
        
        # Apply each variable substitution
        while [[ $# -gt 0 ]]; do
            local var_name=$1
            local var_value=$2
            shift 2
            
            # Use sed to replace the variable placeholder
            temp_content=$(echo "$temp_content" | sed -e "s/\$$var_name/$var_value/g" -e "s/{{$var_name}}/$var_value/g")
        done
        
        # Write the final content to the target file
        echo "$temp_content" > "$target_file"
        return 0
    else
        echo -e "${RED}템플릿 다운로드 실패: $template_file${NC}" >&2
        return 1
    fi
}

# Function to get template with variable substitution (GitHub-based)
copy_template() {
    local template_file=$1
    local target_file=$2
    local substitution_value=${3:-""}
    
    # Try GitHub download first, fallback to local if offline
    if check_internet_connection; then
        if [[ -n "$substitution_value" ]]; then
            # Use download function with variable substitution
            if download_template_with_vars "$template_file" "$target_file" "pnpm_version" "$substitution_value" "package_scope" "$substitution_value" "PACKAGE_SCOPE" "$substitution_value"; then
                return 0
            fi
        else
            # Use simple download function
            if download_template_file "$template_file" "$target_file"; then
                return 0
            fi
        fi
    fi
    
    # Fallback to local template if GitHub download fails
    echo -e "${YELLOW}GitHub 다운로드 실패, 로컬 템플릿 사용을 시도합니다...${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/prj-scripts/$template_file"
    
    if [[ -f "$template_path" ]]; then
        echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
        if [[ -n "$substitution_value" ]]; then
            sed -e "s/\$pnpm_version/$substitution_value/g" -e "s/\$package_scope/$substitution_value/g" -e "s/{{PACKAGE_SCOPE}}/$substitution_value/g" "$template_path" > "$target_file"
        else
            cp "$template_path" "$target_file"
        fi
    else
        echo -e "${RED}템플릿 파일을 찾을 수 없습니다: $template_file${NC}" >&2
        echo -e "${RED}GitHub 연결과 로컬 파일 모두 사용할 수 없습니다.${NC}" >&2
        exit 1
    fi
}

# Function to get template with multiple variable substitutions (GitHub-based)
copy_template_with_vars() {
    local template_file=$1
    local target_file=$2
    shift 2
    
    # Try GitHub download first, fallback to local if offline
    if check_internet_connection; then
        if download_template_with_vars "$template_file" "$target_file" "$@"; then
            return 0
        fi
    fi
    
    # Fallback to local template if GitHub download fails
    echo -e "${YELLOW}GitHub 다운로드 실패, 로컬 템플릿 사용을 시도합니다...${NC}"
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/prj-scripts/$template_file"
    
    if [[ -f "$template_path" ]]; then
        echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
        
        # Start with the template content
        local temp_content
        temp_content=$(cat "$template_path")
        
        # Apply each variable substitution
        while [[ $# -gt 0 ]]; do
            local var_name=$1
            local var_value=$2
            shift 2
            
            # Use sed to replace the variable placeholder
            temp_content=$(echo "$temp_content" | sed "s/\$$var_name/$var_value/g")
        done
        
        # Write the final content to the target file
        echo "$temp_content" > "$target_file"
    else
        echo -e "${RED}템플릿 파일을 찾을 수 없습니다: $template_file${NC}" >&2
        echo -e "${RED}GitHub 연결과 로컬 파일 모두 사용할 수 없습니다.${NC}" >&2
        exit 1
    fi
}

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
    copy_template "gitignore/.gitignore" ".gitignore"
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
    
    copy_template "typescript/tsconfig.json" "tsconfig.json"
}

# Pure function to setup semantic-release
setup_semantic_release() {
    local pnpm_version=$1

    echo -e "${GREEN}semantic-release를 설치합니다...${NC}"
    pnpm i -D semantic-release @semantic-release/commit-analyzer @semantic-release/release-notes-generator @semantic-release/changelog @semantic-release/npm @semantic-release/github @semantic-release/git
    
    copy_template "semantic-release/release.config.ts" "release.config.ts"

    echo -e "${GREEN}GitHub Actions workflow 디렉토리를 생성합니다...${NC}"
    mkdir -p .github/workflows

    # Get Node.js version dynamically
    local node_version
    node_version=$(node -v 2>/dev/null | grep -o '[0-9]\+' | head -1)
    
    if [[ -z "$node_version" ]]; then
        echo -e "${RED}Node.js 버전을 확인할 수 없습니다.${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}Node.js 버전 $node_version을 감지했습니다.${NC}"

    copy_template_with_vars "semantic-release/semantic-release.yml" ".github/workflows/semantic-release.yml" \
        "pnpm_version" "$pnpm_version" \
        "node_version" "$node_version"
}

# Pure function to setup AWS deployment workflows
setup_aws_deployment_workflows() {
    echo -e "${GREEN}AWS 배포 워크플로우를 설정합니다...${NC}"
    
    # Ensure .github/workflows directory exists
    mkdir -p .github/workflows
    
    echo -e "${GREEN}deploy-rr7-lambda-s3.yml 워크플로우를 복사합니다...${NC}"
    copy_template "aws-actions/deploy-rr7-lambda-s3.yml" ".github/workflows/deploy-rr7-lambda-s3.yml"
}

# Pure function to setup DNS workflows
setup_dns_workflows() {
    echo -e "${GREEN}DNS 워크플로우를 설정합니다...${NC}"
    
    # Ensure .github/workflows directory exists
    mkdir -p .github/workflows
    
    echo -e "${GREEN}update-cloudflare-dns.yml 워크플로우를 복사합니다...${NC}"
    copy_template "cf-actions/update-cloudflare-dns.yml" ".github/workflows/update-cloudflare-dns.yml"
}

# Pure function to setup AWS infra package
setup_aws_infra_package() {
    local package_scope=$1
    
    echo -e "${GREEN}AWS 인프라 패키지를 설정합니다...${NC}"
    mkdir -p packages/aws-infra
    cd packages/aws-infra
    
    echo -e "${GREEN}package.json 템플릿을 복사합니다...${NC}"
    copy_template_with_vars "aws-infra/package.json" "package.json" \
        "package_scope" "$package_scope"
    
    echo -e "${GREEN}AWS CDK 의존성을 설치합니다...${NC}"
    pnpm i @react-router/architect aws-cdk aws-cdk-lib constructs esbuild tsx dotenv dotenv-cli
    
    echo -e "${GREEN}인프라 템플릿 파일들을 다운로드합니다...${NC}"
    
    # Download each aws-infra template file (excluding package.json as it's already copied)
    copy_template "aws-infra/cdk.ts" "cdk.ts"
    copy_template "aws-infra/cdk.json" "cdk.json"
    copy_template "aws-infra/cdk-stack.ts" "cdk-stack.ts"
    copy_template "aws-infra/delete-dns.ts" "delete-dns.ts"
    copy_template "aws-infra/README.md" "README.md"
    
    # Use copy_template_with_vars for lambda.ts to handle package_scope substitution
    copy_template_with_vars "aws-infra/lambda.ts" "lambda.ts" \
        "package_scope" "$package_scope"
    
    echo -e "${GREEN}AWS 인프라 템플릿 파일들이 다운로드되었습니다.${NC}"
    
    cd ../..
}


# Pure function to setup package.json private field and scripts
setup_package_json_private() {
    local pnpm_version=$1
    local project_name=$2

    echo -e "${GREEN}package.json에 private: true, packageManager, scripts를 설정합니다...${NC}"
    
    copy_template_with_vars "projectRoot/package.json" "package.json" \
        "pnpm_version" "$pnpm_version" \
        "project_name" "$project_name"
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
    cat > .husky/pre-commit << 'EOF'
pnpm format
EOF

    echo -e "${GREEN}pre-push 훅을 설정합니다...${NC}"
    copy_template "husky/pre-push" ".husky/pre-push"
    chmod +x .husky/pre-push

    echo -e "${GREEN}pre-push 훅 설명서를 복사합니다...${NC}"
    copy_template "husky/pre-push.md" ".husky/pre-push.md"
}

# Pure function to create workspace structure with complete turbo config
create_workspace_structure() {
    local package_scope=$1
    local project_name=$2

    echo -e "${GREEN}워크스페이스 구조를 생성합니다...${NC}"
    mkdir -p apps packages

    echo -e "${GREEN}pnpm-workspace.yaml을 생성합니다...${NC}"
    copy_template "projectRoot/pnpm-workspace.yaml" "pnpm-workspace.yaml"

    echo -e "${GREEN}turbo.json을 생성합니다...${NC}"
    copy_template "projectRoot/turbo.json" "turbo.json" "$package_scope"
}

# Pure function to create sync-catalog script
create_sync_catalog_script() {
    echo -e "${GREEN}sync-catalog.mjs 파일을 생성합니다...${NC}"
    copy_template "scripts/sync-catalog.mjs" "sync-catalog.mjs"
}

# Pure function to setup scripts package README
setup_scripts_readme() {
    echo -e "${GREEN}scripts 패키지 README.md 파일을 생성합니다...${NC}"
    copy_template "scripts/scripts-readme.md" "packages/scripts/README.md"
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
        pkg.devDependencies[\"$package_scope/scripts\"] = 'workspace:*';
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
        pkg.name = \"$package_scope/scripts\";
        pkg.private = true;
        pkg.main = 'index.js';
        pkg.scripts = { 'version': 'node sync-versions.mjs' };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}sync-versions.mjs 파일을 생성합니다...${NC}"
    copy_template "scripts/sync-versions.mjs" "sync-versions.mjs"

    echo -e "${GREEN}format.mjs 파일을 생성합니다...${NC}"
    copy_template "scripts/format.mjs" "format.mjs"

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
        pkg.name = \"$package_scope/scripts\";
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

# Pure function to setup ESLint configuration
setup_eslint_config() {
    echo -e "${GREEN}프로젝트 루트 ESLint 설정을 생성합니다...${NC}"
    
    echo -e "${GREEN}ESLint 의존성을 설치합니다...${NC}"
    pnpm i -D @eslint/js eslint globals typescript-eslint eslint-plugin-unused-imports @typescript-eslint/eslint-plugin @typescript-eslint/parser

    echo -e "${GREEN}ESLint 설정 파일을 생성합니다...${NC}"
    copy_template "projectRoot/eslint.config.mjs" "eslint.config.mjs"
}

# Pure function to setup Prettier configuration
setup_prettier_config() {
    echo -e "${GREEN}프로젝트 루트 Prettier 설정을 생성합니다...${NC}"
    
    echo -e "${GREEN}Prettier 의존성을 설치합니다...${NC}"
    pnpm i -D prettier prettier-plugin-classnames prettier-plugin-css-order @ianvs/prettier-plugin-sort-imports

    echo -e "${GREEN}Prettier 설정 파일을 생성합니다...${NC}"
    copy_template "projectRoot/prettier.config.mjs" "prettier.config.mjs"
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
        pkg.name = \"$package_scope/prettier\";
        pkg.private = true;
        pkg.main = 'index.mjs';
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}Prettier 의존성을 설치합니다...${NC}"
    pnpm i prettier prettier-plugin-classnames prettier-plugin-css-order @ianvs/prettier-plugin-sort-imports

    echo -e "${GREEN}Prettier 설정 파일을 생성합니다...${NC}"
    # Note: Prettier configuration is now handled by setup_prettier_config()

    cd ../..
}

# Pure function to create root config files (deprecated - moved to individual setup functions)
create_root_config_files() {
    local package_scope=$1

    echo -e "${GREEN}루트 설정 파일을 생성합니다...${NC}"
    # Note: Root config files are now created by individual setup functions
    # - prettier.config.mjs: setup_prettier_config()
}

# Pure function to create scripts and documentation
create_scripts_and_docs() {
    local package_scope=$1

    echo -e "${GREEN}스크립트와 문서 파일들을 생성합니다...${NC}"
    


    echo -e "${GREEN}HOW_TO_GET_TOKENS.md 문서를 생성합니다...${NC}"
    copy_template "scripts/HOW_TO_GET_TOKENS.md" "packages/scripts/HOW_TO_GET_TOKENS.md"
}

# Pure function to setup telegram workflows
setup_telegram_workflows() {
    echo -e "${GREEN}Telegram 워크플로우를 설정합니다...${NC}"
    
    # Download telegram workflow template files
    copy_template "telegram/notify-telegram.yml" ".github/workflows/notify-telegram.yml"
    copy_template "telegram/notify-telegram-test.yml" ".github/workflows/notify-telegram-test.yml"
    
    echo -e "${GREEN}Telegram 워크플로우 파일들이 다운로드되었습니다.${NC}"
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
        pkg.name = \"$package_scope/web\";
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi

    echo -e "${GREEN}devDependencies에 scripts, prettier 패키지를 추가합니다...${NC}"
    if command -v jq &> /dev/null; then
        jq --arg scope "$package_scope" '.devDependencies += {($scope + "/scripts"): "workspace:*", ($scope + "/prettier"): "workspace:*"}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        # Fallback: Use Node.js for safe JSON manipulation
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.devDependencies = pkg.devDependencies || {};
        pkg.devDependencies[\"$package_scope/scripts\"] = 'workspace:*';
        pkg.devDependencies[\"$package_scope/prettier\"] = 'workspace:*';
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
    copy_template "react-router/eslint.config.mjs" "eslint.config.mjs" "$package_scope"

    echo -e "${GREEN}prettier.config.mjs 파일을 생성합니다...${NC}"
    copy_template "react-router/prettier.config.mjs" "prettier.config.mjs" "$package_scope"

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
    copy_template "react-router/error-boundary.tsx" "/tmp/new_error_boundary.tsx"

    # Replace ErrorBoundary function in root.tsx
    node -e "
    const fs = require('fs');
    const content = fs.readFileSync('app/root.tsx', 'utf8');
    const newErrorBoundary = fs.readFileSync('/tmp/new_error_boundary.tsx', 'utf8');
    
    // Find and replace the entire ErrorBoundary function
    // This regex matches from 'export function ErrorBoundary' to the closing brace of the function
    const result = content.replace(/export function ErrorBoundary\([^)]*\)[^{]*\{[\s\S]*?\n\}/, newErrorBoundary);
    
    fs.writeFileSync('app/root.tsx', result);
    "
    
    # Clean up temporary file
    rm -f /tmp/new_error_boundary.tsx

    echo -e "${GREEN}home.tsx 파일을 수정합니다...${NC}"
    copy_template "react-router/home.tsx" "app/routes/home.tsx"

    cd ../..
}

# Pure function to setup VS Code workspace settings
setup_vscode_workspace() {
    echo -e "${GREEN}.vscode 워크스페이스 설정을 생성합니다...${NC}"
    mkdir -p .vscode
    
    copy_template "vscode/vscode-extensions.json" ".vscode/extensions.json"
    copy_template "vscode/vscode-settings.json" ".vscode/settings.json"
}

# Pure function to create project README
create_project_readme() {
    echo -e "${GREEN}프로젝트 README.md 파일을 생성합니다...${NC}"
    
    copy_template "projectRoot/README.md" "README.md"
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
    
    copy_template "env/.env" ".env"
    echo -e "${GREEN}.env 파일이 생성되었습니다.${NC}"

    copy_template "env/.env.var" ".env.var"
    echo -e "${GREEN}.env.var 파일이 생성되었습니다.${NC}"
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
    setup_aws_deployment_workflows
    setup_dns_workflows
    setup_telegram_workflows
    setup_package_json_private "$pnpm_version" "$project_name"
    setup_turborepo
    setup_husky
    create_workspace_structure "$package_scope" "$project_name"
    setup_scripts_package "$package_scope"
    setup_scripts_readme
    add_scripts_to_root_dependencies "$package_scope"
    setup_eslint_config
    setup_prettier_config
    setup_prettier_package "$package_scope"
    setup_aws_infra_package "$package_scope"
    setup_react_router_web "$package_scope"
    create_scripts_and_docs "$package_scope"
    create_project_readme
    create_env_template
    update_gitignore_with_env
    setup_vscode_workspace

    echo -e "${GREEN}=== 프로젝트 스캐폴딩이 완료되었습니다! ===${NC}"
    echo -e "${BLUE}cd $(pwd)${NC}"
}

# Run main function
main "$@"