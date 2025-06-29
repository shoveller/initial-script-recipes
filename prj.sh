#!/bin/bash

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRJ_SCRIPTS_DIR="$SCRIPT_DIR/prj-scripts"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if prj-scripts directory exists
if [[ ! -d "$PRJ_SCRIPTS_DIR" ]]; then
    echo -e "${RED}prj-scripts 디렉토리를 찾을 수 없습니다: $PRJ_SCRIPTS_DIR${NC}" >&2
    exit 1
fi

# Source the individual script functions
source "$PRJ_SCRIPTS_DIR/check-pnpm-installed.sh"
source "$PRJ_SCRIPTS_DIR/get-project-inputs.sh"
source "$PRJ_SCRIPTS_DIR/init-project.sh"

# Main execution
echo -e "${BLUE}프로젝트 초기화를 시작합니다...${NC}"

# Check pnpm installation
pnpm_version=$(check_pnpm_installed)
echo -e "${GREEN}pnpm 버전: $pnpm_version${NC}"

# Get project inputs
inputs=$(get_project_inputs)
project_name=$(echo "$inputs" | cut -d' ' -f1)
package_scope=$(echo "$inputs" | cut -d' ' -f2)

echo -e "${GREEN}프로젝트: $project_name${NC}"
echo -e "${GREEN}스코프: $package_scope${NC}"

# Initialize project
init_project "$project_name"

echo -e "${GREEN}기본 프로젝트 설정이 완료되었습니다!${NC}"
echo -e "${YELLOW}추가 설정을 위해 prj-scripts/prj.sh를 실행하세요.${NC}"

# Delegate to the full script for additional setup
exec "$PRJ_SCRIPTS_DIR/prj.sh" "$project_name" "$package_scope" "$pnpm_version"