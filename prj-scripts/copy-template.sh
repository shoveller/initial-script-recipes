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
    local substitution_value=${3:-""}
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/templates/$template_file"
    
    if [[ ! -f "$template_path" ]]; then
        echo -e "${RED}템플릿 파일을 찾을 수 없습니다: $template_path${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}$target_file 파일을 생성합니다...${NC}"
    
    if [[ -n "$substitution_value" ]]; then
        # Replace both pnpm version and package scope placeholders with the provided value
        # This allows flexibility - pass pnpm version for pnpm placeholders, package scope for package scope placeholders
        # Also handle {{PACKAGE_SCOPE}} format for turbo.json and similar templates
        sed -e "s/\$pnpm_version/$substitution_value/g" -e "s/\$package_scope/$substitution_value/g" -e "s/{{PACKAGE_SCOPE}}/$substitution_value/g" "$template_path" > "$target_file"
    else
        cp "$template_path" "$target_file"
    fi
}

# Function to copy template with multiple variable substitutions
copy_template_with_vars() {
    local template_file=$1
    local target_file=$2
    shift 2
    
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local template_path="$script_dir/templates/$template_file"
    
    if [[ ! -f "$template_path" ]]; then
        echo -e "${RED}템플릿 파일을 찾을 수 없습니다: $template_path${NC}" >&2
        exit 1
    fi
    
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
}