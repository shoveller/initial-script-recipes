#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to copy template with variable substitution
copy_template() {
    local template_file=$1
    local target_file=$2
    local pnpm_version=${3:-""}
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/templates/$template_file"
    
    if [[ ! -f "$template_path" ]]; then
        echo -e "${RED}템플릿 파일을 찾을 수 없습니다: $template_path${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
    
    if [[ -n "$pnpm_version" ]]; then
        # Replace pnpm version placeholder
        sed "s/\$pnpm_version/$pnpm_version/g" "$template_path" > "$target_file"
    else
        cp "$template_path" "$target_file"
    fi
}