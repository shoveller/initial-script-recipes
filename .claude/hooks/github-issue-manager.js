#!/usr/bin/env node

/**
 * Claude Code GitHub Issue Manager
 * 
 * Claude Code 세션의 요청사항을 자동으로 GitHub 이슈로 생성하고,
 * 진행 상황을 이슈 코멘트로 업데이트하는 스크립트
 */

import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// 상태 파일 경로
const STATE_FILE = join(__dirname, 'session-state.json');

/**
 * 현재 Git 리포지토리 정보 가져오기
 */
function getRepoInfo() {
  try {
    const remoteUrl = execSync('git config --get remote.origin.url', { encoding: 'utf8' }).trim();
    const match = remoteUrl.match(/github\.com[:/]([^/]+)\/([^/.]+)/);
    
    if (!match) {
      throw new Error('GitHub 리포지토리 정보를 찾을 수 없습니다.');
    }
    
    return {
      owner: match[1],
      repo: match[2]
    };
  } catch (error) {
    console.error('리포지토리 정보 가져오기 실패:', error.message);
    return null;
  }
}

/**
 * 세션 상태 로드
 */
function loadSessionState() {
  if (existsSync(STATE_FILE)) {
    try {
      return JSON.parse(readFileSync(STATE_FILE, 'utf8'));
    } catch (error) {
      console.error('세션 상태 로드 실패:', error.message);
    }
  }
  return {
    currentIssue: null,
    tasks: [],
    startTime: null
  };
}

/**
 * 세션 상태 저장
 */
function saveSessionState(state) {
  try {
    writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
  } catch (error) {
    console.error('세션 상태 저장 실패:', error.message);
  }
}

/**
 * 사용자 요청에서 이슈 제목과 본문 생성
 */
function generateIssueContent(userRequest) {
  const title = `[Claude Code] ${userRequest.substring(0, 50)}${userRequest.length > 50 ? '...' : ''}`;
  
  const body = `## 📋 요청사항
${userRequest}

## 🕐 시작 시간
${new Date().toLocaleString('ko-KR')}

## 📝 진행 상황
- [ ] 작업 시작됨

---
*이 이슈는 Claude Code에 의해 자동으로 생성되었습니다.*`;

  return { title, body };
}

/**
 * GitHub 이슈 생성
 */
function createIssue(title, body) {
  try {
    const result = execSync(`gh issue create --title "${title}" --body "${body}" --label "claude-code"`, {
      encoding: 'utf8',
      cwd: process.cwd()
    });
    
    // 이슈 URL에서 이슈 번호 추출
    const match = result.match(/\/issues\/(\d+)/);
    if (match) {
      return parseInt(match[1]);
    }
    
    throw new Error('이슈 번호를 추출할 수 없습니다.');
  } catch (error) {
    console.error('이슈 생성 실패:', error.message);
    return null;
  }
}

/**
 * 이슈에 코멘트 추가
 */
function addIssueComment(issueNumber, comment) {
  try {
    execSync(`gh issue comment ${issueNumber} --body "${comment}"`, {
      cwd: process.cwd()
    });
    return true;
  } catch (error) {
    console.error('이슈 코멘트 추가 실패:', error.message);
    return false;
  }
}

/**
 * 이슈 상태 업데이트 (완료 시 닫기)
 */
function closeIssue(issueNumber, comment) {
  try {
    if (comment) {
      addIssueComment(issueNumber, comment);
    }
    
    execSync(`gh issue close ${issueNumber}`, {
      cwd: process.cwd()
    });
    return true;
  } catch (error) {
    console.error('이슈 닫기 실패:', error.message);
    return false;
  }
}

/**
 * 새 작업 시작
 */
function startTask(userRequest) {
  const repoInfo = getRepoInfo();
  if (!repoInfo) {
    console.error('GitHub 리포지토리 정보를 찾을 수 없습니다.');
    return;
  }
  
  const { title, body } = generateIssueContent(userRequest);
  const issueNumber = createIssue(title, body);
  
  if (issueNumber) {
    const state = {
      currentIssue: issueNumber,
      tasks: [userRequest],
      startTime: new Date().toISOString(),
      repoInfo
    };
    
    saveSessionState(state);
    console.log(`✅ 이슈 #${issueNumber} 생성 완료`);
    console.log(`📋 제목: ${title}`);
  }
}

/**
 * 작업 진행 상황 업데이트
 */
function updateProgress(message) {
  const state = loadSessionState();
  
  if (!state.currentIssue) {
    console.log('진행 중인 이슈가 없습니다.');
    return;
  }
  
  const timestamp = new Date().toLocaleString('ko-KR');
  const comment = `## 📝 진행 상황 업데이트
**시간**: ${timestamp}

${message}`;
  
  if (addIssueComment(state.currentIssue, comment)) {
    console.log(`✅ 이슈 #${state.currentIssue}에 진행 상황 업데이트 완료`);
  }
}

/**
 * 작업 완료
 */
function completeTask(summary) {
  const state = loadSessionState();
  
  if (!state.currentIssue) {
    console.log('완료할 이슈가 없습니다.');
    return;
  }
  
  const endTime = new Date().toLocaleString('ko-KR');
  const duration = state.startTime ? 
    Math.round((new Date() - new Date(state.startTime)) / 1000 / 60) : 
    '알 수 없음';
  
  const finalComment = `## ✅ 작업 완료
**완료 시간**: ${endTime}
**소요 시간**: ${duration}분

### 📋 완료 요약
${summary}

---
*작업이 완료되어 이슈를 닫습니다.*`;
  
  if (closeIssue(state.currentIssue, finalComment)) {
    console.log(`✅ 이슈 #${state.currentIssue} 완료 및 닫기 완료`);
    
    // 세션 상태 초기화
    saveSessionState({
      currentIssue: null,
      tasks: [],
      startTime: null
    });
  }
}

// CLI 인터페이스
const command = process.argv[2];
const message = process.argv.slice(3).join(' ');

switch (command) {
  case 'start':
    if (!message) {
      console.error('사용법: node github-issue-manager.js start "작업 내용"');
      process.exit(1);
    }
    startTask(message);
    break;
    
  case 'update':
    if (!message) {
      console.error('사용법: node github-issue-manager.js update "진행 상황"');
      process.exit(1);
    }
    updateProgress(message);
    break;
    
  case 'complete':
    if (!message) {
      console.error('사용법: node github-issue-manager.js complete "완료 요약"');
      process.exit(1);
    }
    completeTask(message);
    break;
    
  default:
    console.log(`사용법:
  node github-issue-manager.js start "작업 내용"     - 새 이슈 생성
  node github-issue-manager.js update "진행 상황"    - 진행 상황 업데이트
  node github-issue-manager.js complete "완료 요약"  - 작업 완료 및 이슈 닫기`);
    break;
}