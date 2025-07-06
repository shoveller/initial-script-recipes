# Claude Code GitHub Issue Integration

Claude Code의 요청사항을 자동으로 GitHub 이슈로 생성하고, 진행 상황을 추적하는 자동화 시스템입니다.

## 🚀 기능

- **자동 이슈 생성**: 복잡한 작업 요청 시 자동으로 GitHub 이슈 생성
- **진행 상황 추적**: 작업 진행 상황을 이슈 코멘트로 자동 업데이트
- **완료 처리**: 작업 완료 시 이슈 자동 완료 및 닫기
- **GitHub Actions 연동**: 코드 변경 시 관련 이슈 자동 업데이트

## 📁 파일 구조

```
.claude/
├── hooks/
│   ├── github-issue-manager.js    # 이슈 생성/업데이트 스크립트
│   ├── pre-task                   # 작업 시작 시 실행되는 훅
│   ├── post-task                  # 작업 완료 시 실행되는 훅
│   └── session-state.json         # 세션 상태 저장 파일 (자동 생성)
├── README.md                      # 이 파일
└── claude-config.json             # Claude Code 설정 파일 (선택사항)
```

## 🔧 설정 방법

### 1. GitHub CLI 설치 및 인증

```bash
# GitHub CLI 설치 (macOS)
brew install gh

# GitHub CLI 인증
gh auth login
```

### 2. 필요 권한 확인

GitHub CLI가 다음 권한을 가지고 있는지 확인:
- `repo`: 리포지토리 접근
- `workflow`: GitHub Actions 워크플로우 실행

### 3. Claude Code 훅 설정

Claude Code의 설정 파일에 훅을 등록합니다:

```json
{
  "hooks": {
    "pre-task": ".claude/hooks/pre-task",
    "post-task": ".claude/hooks/post-task"
  }
}
```

## 🎯 사용 방법

### 자동 실행 (권장)

Claude Code가 자동으로 훅을 실행하여 이슈를 관리합니다:

1. 복잡한 작업 요청 시 자동으로 이슈 생성
2. 작업 진행 중 자동으로 진행 상황 업데이트
3. 작업 완료 시 자동으로 이슈 완료 처리

### 수동 실행

필요에 따라 직접 스크립트를 실행할 수 있습니다:

```bash
# 새 이슈 생성
node .claude/hooks/github-issue-manager.js start "작업 내용"

# 진행 상황 업데이트
node .claude/hooks/github-issue-manager.js update "진행 상황"

# 작업 완료 처리
node .claude/hooks/github-issue-manager.js complete "완료 요약"
```

### 훅 직접 실행

```bash
# 작업 시작 훅 실행
.claude/hooks/pre-task "새로운 기능 구현"

# 작업 완료 훅 실행
.claude/hooks/post-task success "기능 구현 완료"
```

## 🔄 GitHub Actions 연동

`.github/workflows/claude-issue-sync.yml` 파일이 다음 기능을 제공합니다:

- **자동 이슈 업데이트**: Claude Code 커밋 시 관련 이슈 자동 업데이트
- **완료 감지**: 완료 키워드가 포함된 커밋 시 이슈 자동 완료
- **변경 파일 추적**: 변경된 파일 목록을 이슈 코멘트에 추가

## 📋 이슈 생성 조건

다음 조건을 만족하는 요청에 대해 자동으로 이슈가 생성됩니다:

1. **코드 관련 키워드 포함**: 구현, 개발, 추가, 수정, 리팩토링, 버그, 기능 등
2. **복잡한 요청**: 50자 이상의 긴 요청
3. **다중 단계 작업**: 여러 단계가 포함된 요청

## 🏷️ 이슈 라벨

자동 생성된 이슈에는 `claude-code` 라벨이 자동으로 추가됩니다.

## 🔧 커스터마이징

### 이슈 생성 조건 수정

`.claude/hooks/pre-task` 파일에서 이슈 생성 조건을 수정할 수 있습니다:

```bash
# 키워드 추가/제거
if echo "$USER_REQUEST" | grep -E -i "(새로운키워드|기존키워드)" > /dev/null; then
    SHOULD_CREATE_ISSUE=true
fi
```

### 이슈 템플릿 수정

`.claude/hooks/github-issue-manager.js` 파일에서 이슈 제목과 본문 템플릿을 수정할 수 있습니다.

## 🚨 문제 해결

### 이슈 생성 실패

1. GitHub CLI 인증 상태 확인:
   ```bash
   gh auth status
   ```

2. 필요 권한 확인:
   ```bash
   gh auth refresh -h github.com -s repo,workflow
   ```

### 훅 실행 실패

1. 실행 권한 확인:
   ```bash
   chmod +x .claude/hooks/pre-task
   chmod +x .claude/hooks/post-task
   ```

2. Node.js 설치 확인:
   ```bash
   node --version
   ```

### GitHub Actions 실행 실패

1. 워크플로우 권한 확인: Settings > Actions > General > Workflow permissions
2. GITHUB_TOKEN 권한 확인: "Read and write permissions" 설정

## 📝 로그 및 디버깅

세션 상태는 `.claude/hooks/session-state.json` 파일에 저장됩니다:

```json
{
  "currentIssue": 123,
  "tasks": ["작업 내용"],
  "startTime": "2024-01-01T00:00:00.000Z",
  "repoInfo": {
    "owner": "사용자명",
    "repo": "리포지토리명"
  }
}
```

## 🤝 기여하기

이 시스템을 개선하고 싶으시다면:

1. 이슈나 버그를 GitHub 이슈로 보고해주세요
2. 개선사항이나 새로운 기능을 제안해주세요
3. 직접 코드를 수정하여 Pull Request를 보내주세요

## 📄 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다.