# GitHub Secrets Upload Guide

이 문서는 `.env` 파일의 환경변수를 GitHub 저장소의 시크릿으로 자동 업로드하는 방법을 설명합니다.

## 개요

`upload-secrets.sh` 스크립트는 로컬의 `.env` 파일을 읽어서 유효한 환경변수들을 GitHub 저장소의 시크릿으로 자동 업로드합니다. 이를 통해 CI/CD 파이프라인에서 필요한 환경변수들을 안전하게 관리할 수 있습니다.

## 사전 요구사항

### 1. GitHub CLI 설치 및 인증

```bash
# GitHub CLI 설치 (macOS)
brew install gh

# GitHub CLI 설치 (다른 OS)
# https://cli.github.com/ 참조

# GitHub에 로그인
gh auth login
```

### 2. 필요한 권한

스크립트를 실행하기 위해서는 다음 권한이 필요합니다:
- 대상 저장소에 대한 **Admin** 권한 또는 **Maintain** 권한
- GitHub Personal Access Token에 `repo` 스코프 포함

## 사용 방법

### 기본 사용법

```bash
# 현재 디렉토리의 .env 파일을 현재 저장소에 업로드
./upload-secrets.sh

# 특정 .env 파일 업로드
./upload-secrets.sh -f .env.production

# 특정 저장소에 업로드
./upload-secrets.sh -r owner/repository-name

# 드라이 런 (실제 업로드 없이 미리보기)
./upload-secrets.sh -d

# 확인 없이 강제 업로드
./upload-secrets.sh --force
```

### 명령줄 옵션

| 옵션 | 설명 |
|------|------|
| `-f, --file FILE` | 업로드할 .env 파일 경로 지정 (기본값: .env) |
| `-r, --repo REPO` | 대상 저장소 지정 (owner/repo 형식) |
| `-d, --dry-run` | 실제 업로드 없이 미리보기만 표시 |
| `--force` | 확인 없이 강제 업로드 |
| `-h, --help` | 도움말 표시 |

## .env 파일 형식

### 지원되는 형식

```bash
# 기본 형식
API_KEY=your-api-key-here
DATABASE_URL=postgresql://user:pass@host:5432/db

# 따옴표 사용 (자동으로 제거됨)
SECRET_KEY="your-secret-key"
WEBHOOK_URL='https://example.com/webhook'

# 주석은 무시됨
# 이것은 주석입니다
DEBUG=true
```

### 시크릿 이름 규칙

GitHub 시크릿은 다음 규칙을 따라야 합니다:
- 영문 대문자, 숫자, 언더스코어(_)만 사용 가능
- `GITHUB_`로 시작할 수 없음
- 숫자로 시작할 수 없음
- 자동으로 대문자로 변환됨

**유효한 예시:**
```bash
API_KEY=value          # ✅ API_KEY
database_url=value     # ✅ DATABASE_URL (자동 대문자 변환)
SECRET_123=value       # ✅ SECRET_123
```

**유효하지 않은 예시:**
```bash
GITHUB_TOKEN=value     # ❌ GITHUB_로 시작
123_SECRET=value       # ❌ 숫자로 시작
API-KEY=value          # ❌ 하이픈 사용
```

## 실행 예시

### 1. 기본 실행

```bash
$ ./upload-secrets.sh

=== GitHub 시크릿 업로드 도구 ===
GitHub CLI 상태를 확인합니다...
✓ GitHub CLI가 설치되어 있고 인증되었습니다.
환경변수 파일을 파싱합니다: .env

=== 업로드 미리보기 ===
저장소: owner/my-project
업로드될 시크릿:
  API_KEY: ***key1
  DATABASE_URL: ***5432
  SECRET_KEY: ***ret!
총 3개의 시크릿이 업로드됩니다.

위의 시크릿들을 GitHub에 업로드하시겠습니까? (y/N): y

GitHub 시크릿 업로드를 시작합니다...
업로드 중: API_KEY
✓ API_KEY 업로드 성공
업로드 중: DATABASE_URL
✓ DATABASE_URL 업로드 성공
업로드 중: SECRET_KEY
✓ SECRET_KEY 업로드 성공

업로드 완료: 성공 3개, 실패 0개
=== GitHub 시크릿 업로드가 완료되었습니다! ===
```

### 2. 드라이 런 실행

```bash
$ ./upload-secrets.sh -d

=== GitHub 시크릿 업로드 도구 ===
GitHub CLI 상태를 확인합니다...
✓ GitHub CLI가 설치되어 있고 인증되었습니다.
환경변수 파일을 파싱합니다: .env

=== 업로드 미리보기 ===
저장소: owner/my-project
업로드될 시크릿:
  API_KEY: ***key1
  DATABASE_URL: ***5432
총 2개의 시크릿이 업로드됩니다.

[DRY RUN] 실제 업로드는 수행되지 않습니다.
```

## 보안 고려사항

### 1. .env 파일 보안

- `.env` 파일은 절대 Git 저장소에 커밋하지 마세요
- `.gitignore`에 `.env` 파일을 추가하세요
- 민감한 정보는 반드시 시크릿으로 관리하세요

### 2. GitHub 시크릿 보안

- 업로드된 시크릿은 GitHub에서 암호화되어 저장됩니다
- 시크릿 값은 GitHub UI에서 볼 수 없습니다 (수정만 가능)
- 필요한 최소한의 권한만 부여하세요

### 3. 권한 관리

- Personal Access Token은 필요한 최소 스코프만 포함하세요
- 토큰을 정기적으로 갱신하세요
- 사용하지 않는 토큰은 즉시 삭제하세요

## 문제 해결

### 일반적인 오류

#### 1. GitHub CLI 인증 오류
```bash
Error: GitHub CLI에 로그인되어 있지 않습니다.
```
**해결방법:** `gh auth login` 명령으로 다시 로그인하세요.

#### 2. 권한 오류
```bash
Error: ✗ API_KEY 업로드 실패
```
**해결방법:** 
- 저장소에 대한 Admin 또는 Maintain 권한이 있는지 확인하세요
- Personal Access Token에 `repo` 스코프가 포함되어 있는지 확인하세요

#### 3. 저장소를 찾을 수 없음
```bash
Error: 저장소를 찾을 수 없습니다.
```
**해결방법:**
- Git 저장소 내에서 실행하거나 `-r` 옵션으로 저장소를 지정하세요
- 저장소 이름이 `owner/repository` 형식인지 확인하세요

### 디버깅 팁

1. **드라이 런 사용**: 먼저 `-d` 옵션으로 드라이 런을 실행해보세요
2. **권한 확인**: `gh repo view owner/repo` 명령으로 저장소 접근 권한을 확인하세요
3. **환경변수 검증**: `.env` 파일에 유효한 형식의 환경변수가 있는지 확인하세요

## 통합 사용법

### 1. 배포 워크플로우에서 사용

```bash
# 배포 전 시크릿 업데이트
./upload-secrets.sh -f .env.production --force
```

### 2. 개발 환경 설정

```bash
# 개발용 시크릿 업로드
./upload-secrets.sh -f .env.development -r owner/dev-repo
```

### 3. CI/CD 파이프라인에서 사용

```yaml
# GitHub Actions 예시
- name: Upload secrets
  run: |
    chmod +x ./scripts/upload-secrets.sh
    ./scripts/upload-secrets.sh --force
```

## 관련 문서

- [HOW_TO_GET_TOKENS.md](./HOW_TO_GET_TOKENS.md) - 각종 토큰 획득 방법
- [GitHub CLI 문서](https://cli.github.com/manual/)
- [GitHub Secrets 가이드](https://docs.github.com/en/actions/security-guides/encrypted-secrets)