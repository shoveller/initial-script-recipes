#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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