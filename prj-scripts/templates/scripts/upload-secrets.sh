#!/bin/bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ENV_FILE=".env"
DRY_RUN=false
REPO=""
FORCE=false

# Show help information
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Upload environment variables from .env file to GitHub repository secrets"
    echo ""
    echo "Options:"
    echo "  -f, --file FILE       Specify .env file path (default: .env)"
    echo "  -r, --repo REPO       Specify repository (owner/repo format)"
    echo "  -d, --dry-run         Show what would be uploaded without actually doing it"
    echo "  --force               Skip confirmation prompts"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                    Upload .env to current repository"
    echo "  $0 -f .env.prod       Upload .env.prod to current repository"
    echo "  $0 -r owner/repo      Upload .env to specified repository"
    echo "  $0 -d                 Dry run to see what would be uploaded"
    echo ""
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--file)
                DEFAULT_ENV_FILE="$2"
                shift 2
                ;;
            -r|--repo)
                REPO="$2"
                shift 2
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                show_help
                exit 1
                ;;
        esac
    done
}

# Check if GitHub CLI is installed and authenticated
check_gh_cli() {
    echo -e "${BLUE}GitHub CLI 상태를 확인합니다...${NC}"
    
    if ! command -v gh &> /dev/null; then
        echo -e "${RED}GitHub CLI (gh)가 설치되어 있지 않습니다.${NC}" >&2
        echo -e "${YELLOW}GitHub CLI를 설치하려면 다음을 참조하세요: https://cli.github.com/${NC}" >&2
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        echo -e "${RED}GitHub CLI에 로그인되어 있지 않습니다.${NC}" >&2
        echo -e "${YELLOW}다음 명령으로 로그인하세요: gh auth login${NC}" >&2
        exit 1
    fi
    
    echo -e "${GREEN}GitHub CLI가 설치되어 있고 인증되었습니다.${NC}"
}

# Get current repository information
get_current_repo() {
    if [[ -n "$REPO" ]]; then
        echo "$REPO"
        return
    fi
    
    if git rev-parse --is-inside-work-tree &> /dev/null; then
        local origin_url
        origin_url=$(git remote get-url origin 2>/dev/null || echo "")
        
        if [[ -n "$origin_url" ]]; then
            # Extract owner/repo from various GitHub URL formats
            local repo_path
            repo_path=$(echo "$origin_url" | sed -E 's|^https://github\.com/||; s|^git@github\.com:||; s|\.git$||')
            echo "$repo_path"
            return
        fi
    fi
    
    echo ""
}

# Validate repository format
validate_repo() {
    local repo=$1
    
    if [[ ! "$repo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
        echo -e "${RED}잘못된 저장소 형식입니다. owner/repo 형식이어야 합니다.${NC}" >&2
        exit 1
    fi
}

# Check if .env file exists and is readable
check_env_file() {
    local env_file=$1
    
    if [[ ! -f "$env_file" ]]; then
        echo -e "${RED}환경변수 파일을 찾을 수 없습니다: $env_file${NC}" >&2
        exit 1
    fi
    
    if [[ ! -r "$env_file" ]]; then
        echo -e "${RED}환경변수 파일을 읽을 수 없습니다: $env_file${NC}" >&2
        exit 1
    fi
}

# Validate secret name according to GitHub requirements
validate_secret_name() {
    local name=$1
    
    # GitHub secret name requirements:
    # - Can only contain alphanumeric characters and underscores
    # - Cannot start with GITHUB_
    # - Cannot start with a number
    # - Must be uppercase
    
    if [[ ! "$name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        return 1
    fi
    
    if [[ "$name" =~ ^GITHUB_ ]]; then
        return 1
    fi
    
    return 0
}

# Parse .env file and extract valid environment variables
parse_env_file() {
    local env_file=$1
    local -A env_vars
    
    echo -e "${BLUE}환경변수 파일을 파싱합니다: $env_file${NC}"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        
        # Extract key=value pairs
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            
            # Convert key to uppercase for GitHub secrets
            key=$(echo "$key" | tr '[:lower:]' '[:upper:]')
            
            # Remove surrounding quotes from value if present
            value=$(echo "$value" | sed -E 's/^"(.*)"$/\1/; s/^'\''(.*)'\''$/\1/')
            
            if validate_secret_name "$key"; then
                env_vars["$key"]="$value"
            else
                echo -e "${YELLOW}유효하지 않은 시크릿 이름을 건너뜁니다: $key${NC}"
            fi
        fi
    done < "$env_file"
    
    # Return associative array as serialized string
    for key in "${!env_vars[@]}"; do
        printf "%s=%s\n" "$key" "${env_vars[$key]}"
    done
}

# Show what will be uploaded
show_upload_preview() {
    local env_data=$1
    local repo=$2
    
    echo -e "${BLUE}=== 업로드 미리보기 ===${NC}"
    echo -e "${BLUE}저장소: $repo${NC}"
    echo -e "${BLUE}업로드될 시크릿:${NC}"
    
    local count=0
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        echo -e "  ${GREEN}$key${NC}: ***${value: -4}"
        ((count++))
    done <<< "$env_data"
    
    echo -e "${BLUE}총 $count개의 시크릿이 업로드됩니다.${NC}"
    echo ""
}

# Upload secrets to GitHub repository
upload_secrets() {
    local env_data=$1
    local repo=$2
    local dry_run=$3
    
    if [[ "$dry_run" == "true" ]]; then
        echo -e "${YELLOW}[DRY RUN] 실제 업로드는 수행되지 않습니다.${NC}"
        return 0
    fi
    
    local success_count=0
    local error_count=0
    
    echo -e "${GREEN}GitHub 시크릿 업로드를 시작합니다...${NC}"
    
    while IFS='=' read -r key value; do
        [[ -z "$key" ]] && continue
        
        echo -e "${BLUE}업로드 중: $key${NC}"
        
        if echo "$value" | gh secret set "$key" --repo "$repo" 2>/dev/null; then
            echo -e "${GREEN}✓ $key 업로드 성공${NC}"
            ((success_count++))
        else
            echo -e "${RED}✗ $key 업로드 실패${NC}"
            ((error_count++))
        fi
    done <<< "$env_data"
    
    echo ""
    echo -e "${GREEN}업로드 완료: 성공 $success_count개, 실패 $error_count개${NC}"
    
    if [[ $error_count -gt 0 ]]; then
        echo -e "${YELLOW}일부 시크릿 업로드에 실패했습니다. 권한을 확인해주세요.${NC}"
        return 1
    fi
    
    return 0
}

# Confirm upload with user
confirm_upload() {
    local force=$1
    
    if [[ "$force" == "true" ]]; then
        return 0
    fi
    
    echo -e "${YELLOW}위의 시크릿들을 GitHub에 업로드하시겠습니까? (y/N):${NC}"
    read -r response </dev/tty
    
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}업로드를 취소했습니다.${NC}"
        exit 0
    fi
}

# Main execution function
main() {
    echo -e "${BLUE}=== GitHub 시크릿 업로드 도구 ===${NC}"
    
    # Parse command line arguments
    parse_args "$@"
    
    # Check prerequisites
    check_gh_cli
    
    # Validate and get repository
    local repo
    repo=$(get_current_repo)
    
    if [[ -z "$repo" ]]; then
        echo -e "${RED}저장소를 찾을 수 없습니다. -r 옵션으로 저장소를 지정하거나 Git 저장소 내에서 실행하세요.${NC}" >&2
        exit 1
    fi
    
    validate_repo "$repo"
    
    # Check environment file
    check_env_file "$DEFAULT_ENV_FILE"
    
    # Parse environment variables
    local env_data
    env_data=$(parse_env_file "$DEFAULT_ENV_FILE")
    
    if [[ -z "$env_data" ]]; then
        echo -e "${YELLOW}업로드할 유효한 환경변수가 없습니다.${NC}"
        exit 0
    fi
    
    # Show preview
    show_upload_preview "$env_data" "$repo"
    
    # Confirm upload (unless dry run or force)
    if [[ "$DRY_RUN" != "true" ]]; then
        confirm_upload "$FORCE"
    fi
    
    # Upload secrets
    upload_secrets "$env_data" "$repo" "$DRY_RUN"
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo -e "${GREEN}=== GitHub 시크릿 업로드가 완료되었습니다! ===${NC}"
    fi
}

# Run main function
main "$@"