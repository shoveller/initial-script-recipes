#!/bin/bash

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