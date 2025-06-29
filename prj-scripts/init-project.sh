#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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