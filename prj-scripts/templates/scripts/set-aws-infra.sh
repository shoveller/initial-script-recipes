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
        echo -e "${YELLOW}packages/infra 디렉토리가 이미 존재합니다.${NC}"
        echo -e "${YELLOW}삭제하고 새로 생성하시겠습니까? (y/N):${NC}"
        read -r response </dev/tty
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${GREEN}기존 packages/infra 디렉토리를 삭제합니다...${NC}"
            rm -rf packages/infra
        else
            echo -e "${RED}작업을 취소합니다.${NC}"
            exit 1
        fi
    fi
}

# Initialize packages/infra directory
init_infra_dir() {
    echo -e "${GREEN}packages/infra 디렉토리를 생성하고 이동합니다...${NC}"
    mkdir -p packages/infra
    cd packages/infra
    
    echo -e "${GREEN}pnpm init으로 초기화합니다...${NC}"
    pnpm init
}

# Edit package.json for infra package
edit_infra_package_json() {
    local scope_name="$1"
    
    echo -e "${GREEN}package.json을 편집합니다...${NC}"
    
    if command -v jq &> /dev/null; then
        jq --arg scope "$scope_name" '. + {"name": ($scope + "/infra"), "scripts": {"bootstrap": "cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10", "deploy": "cdk deploy --hotswap --require-approval never --concurrency 10 --quiet", "destroy": "tsx destroy.ts"}}' package.json > package.json.tmp && mv package.json.tmp package.json
    else
        node -e "
        const fs = require('fs');
        const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
        pkg.name = '$scope_name/infra';
        pkg.scripts = {
            'bootstrap': 'cdk bootstrap && cdk deploy --timeout 20 --require-approval never --concurrency 10',
            'deploy': 'cdk deploy --hotswap --require-approval never --concurrency 10 --quiet',
            'destroy': 'tsx destroy.ts'
        };
        fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
        "
    fi
}

# Copy AWS infrastructure template files
copy_infra_templates() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local templates_dir="$script_dir/../infra"
    
    echo -e "${GREEN}AWS 인프라 템플릿 파일들을 복사합니다...${NC}"
    
    if [[ ! -d "$templates_dir" ]]; then
        echo -e "${RED}템플릿 디렉토리를 찾을 수 없습니다: $templates_dir${NC}"
        exit 1
    fi
    
    # Copy all template files to packages/infra
    if [[ -n "$(ls -A "$templates_dir" 2>/dev/null)" ]]; then
        cp -r "$templates_dir"/* packages/infra/
    else
        echo -e "${YELLOW}템플릿 디렉토리가 비어있습니다. 건너뜁니다.${NC}"
    fi

    echo -e "${GREEN}템플릿 파일들이 복사되었습니다.${NC}"
}

# Install dependencies
install_dependencies() {
    echo -e "${GREEN}디펜던시를 설치합니다...${NC}"
    pnpm i @react-router/architect aws-cdk aws-cdk-lib constructs esbuild tsx dotenv dotenv-cli
}

# Get scope name from user input or from root package.json
get_scope_name() {
    # Try to extract from root package.json first
    if [[ -f "../../package.json" ]]; then
        local scope_from_package=$(node -e "
            try {
                const pkg = JSON.parse(require('fs').readFileSync('../../package.json', 'utf8'));
                const name = pkg.name || '';
                const match = name.match(/^(@[^/]+)\//);
                console.log(match ? match[1] : '');
            } catch (e) {
                console.log('');
            }
        ")

        if [[ -n "$scope_from_package" ]]; then
            echo "$scope_from_package"
            return
        fi
    fi

    # Ask user for scope name if not found
    echo -e "${BLUE}스코프 이름을 입력하세요 (예: @company):${NC}" >&2
    read -r scope_name </dev/tty
    echo "$scope_name"
}

# Main execution
main() {
    echo -e "${BLUE}=== AWS 인프라 설정을 시작합니다 ===${NC}"
    
    # Move to project root if we're in packages/scripts
    if [[ $(basename "$(pwd)") == "scripts" ]]; then
        cd ../..
    fi
    
    # Get scope name
    scope_name=$(get_scope_name)
    
    if [[ -z "$scope_name" ]]; then
        echo -e "${RED}스코프 이름을 입력해야 합니다.${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}스코프 이름: $scope_name${NC}"
    
    # Execute setup functions
    check_and_remove_infra_dir
    init_infra_dir
    edit_infra_package_json "$scope_name"
    copy_infra_templates
    install_dependencies
    
    echo -e "${GREEN}=== AWS 인프라 설정이 완료되었습니다! ===${NC}"
    echo -e "${BLUE}다음 단계:${NC}"
    echo -e "${BLUE}1. .env 파일을 수정하여 AWS 계정 정보를 입력하세요${NC}"
    echo -e "${BLUE}2. pnpm bootstrap 명령으로 CDK를 배포하세요${NC}"
    echo -e "${BLUE}3. GitHub Actions 워크플로우를 사용하려면 deploy-aws-lambda.yml 파일을 복사하세요${NC}"
}

# Run main function
main "$@"