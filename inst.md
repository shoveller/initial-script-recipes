# 배포 프로세스 자동화
cdk 를 활용한 aws 배포 스크립트 생성을 자동화한다.
이때 aws 토큰을 함께 설정한다.
아래의 계획은 이 계획에 통합한다.

1`packages/scripts/set-github-secret.mjs` 을 생성
```js
#!/usr/bin/env node

import { execSync } from 'child_process'
import { createInterface } from 'readline'
import { writeFileSync, mkdirSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirname = dirname(fileURLToPath(import.meta.url))

/**
 * @typedef {Object} SecretConfig
 * @property {string} name - 시크릿 이름
 * @property {string} description - 시크릿 설명
 * @property {(value: string) => boolean} validate - 입력값 검증 함수
 */

/**
 * @typedef {Record<string, string>} EnvVars
 */

/**
 * 환경변수 설정 목록
 * @type {SecretConfig[]}
 */
const secrets = [
    {
        name: 'AWS_ACCOUNT_ID',
        description:
            'AWS 계정 ID (12자리 숫자) - aws sts get-caller-identity --query Account --output text',
        validate: (value) => /^\d{12}$/.test(value)
    },
    {
        name: 'AWS_DEFAULT_REGION',
        description: 'AWS 리전 (예: us-east-1, ap-northeast-2)',
        validate: (value) => /^[a-z0-9-]+$/.test(value) && value.length > 0
    }
]

/**
 * GitHub 시크릿을 설정합니다
 * @param {string} name - 시크릿 이름
 * @param {string} value - 시크릿 값
 * @returns {Promise<boolean>} 성공 여부
 */
async function setGitHubSecret(name, value) {
    try {
        execSync(`gh secret set ${name} --body "${value}"`, {
            stdio: 'inherit',
            encoding: 'utf8'
        })
        console.log(`✅ GitHub secret ${name} 설정 완료`)
        return true
    } catch (error) {
        console.error(`❌ GitHub secret ${name} 설정 실패:`, error.message)
        return false
    }
}

/**
 * 환경변수 파일을 생성합니다
 * @param {EnvVars} envVars - 환경변수 객체
 * @returns {boolean} 성공 여부
 */
function createEnvFile(envVars) {
    const webAppPath = join(__dirname, '../../apps/web')
    const envFilePath = join(webAppPath, '.env')

    const envContent = Object.entries(envVars)
        .map(([key, value]) => `${key}=${value}`)
        .join('\n')

    try {
        mkdirSync(webAppPath, { recursive: true })
        writeFileSync(envFilePath, envContent)
        console.log(`✅ .env 파일 생성: ${envFilePath}`)
        return true
    } catch (error) {
        console.error(`❌ .env 파일 생성 실패:`, error.message)
        return false
    }
}

/**
 * 사용자 입력을 위한 readline 인터페이스를 생성합니다
 * @returns {import('readline').Interface} readline 인터페이스
 */
function createReadlineInterface() {
    return createInterface({
        input: process.stdin,
        output: process.stdout
    })
}

/**
 * 사용자에게 질문하고 답변을 받습니다
 * @param {string} query - 질문 문자열
 * @returns {Promise<string>} 사용자 입력값
 */
function question(query) {
    const rl = createReadlineInterface()
    return new Promise((resolve) => {
        rl.question(query, (answer) => {
            rl.close()
            resolve(answer.trim())
        })
    })
}

/**
 * 사용자 입력을 수집하고 검증합니다
 * @param {SecretConfig} secretConfig - 시크릿 설정
 * @returns {Promise<string>} 검증된 사용자 입력값
 */
async function collectUserInput(secretConfig) {
    const value = await question(`${secretConfig.description}: `)

    if (!secretConfig.validate(value)) {
        console.error(`❌ 잘못된 형식입니다.`)
        return collectUserInput(secretConfig)
    }

    return value
}

/**
 * GitHub CLI 설치 여부를 확인합니다
 * @returns {boolean} 설치 여부
 */
function checkGitHubCLI() {
    try {
        execSync('gh --version', { stdio: 'pipe' })
        console.log('✅ GitHub CLI 설치 확인됨')
        return true
    } catch (error) {
        console.error('❌ GitHub CLI가 설치되어 있지 않습니다.')
        console.error('설치 방법: https://cli.github.com/')
        return false
    }
}

/**
 * GitHub CLI 인증 상태를 확인합니다
 * @returns {boolean} 인증 여부
 */
function checkGitHubAuth() {
    try {
        execSync('gh auth status', { stdio: 'pipe' })
        console.log('✅ GitHub CLI 인증 확인됨')
        return true
    } catch (error) {
        console.error('❌ GitHub CLI 인증이 필요합니다.')
        console.error('인증 방법: gh auth login')
        return false
    }
}

/**
 * 메인 함수 - GitHub 시크릿 설정 및 환경변수 파일 생성을 수행합니다
 * @returns {Promise<void>}
 */
async function main() {
    console.log('🔧 GitHub 시크릿 및 환경변수 설정 시작\n')

    // GitHub CLI 설치 및 인증 확인
    console.log('🔍 사전 확인 중...')
    const isGHInstalled = checkGitHubCLI()
    if (!isGHInstalled) {
        process.exit(1)
    }

    const isGHAuthenticated = checkGitHubAuth()
    if (!isGHAuthenticated) {
        process.exit(1)
    }

    console.log()

    const envVars = {}

    // 각 시크릿에 대해 사용자 입력 수집
    for (const secret of secrets) {
        console.log(`📝 ${secret.name} 설정`)
        const value = await collectUserInput(secret)
        envVars[secret.name] = value
        console.log()
    }

    // GitHub 시크릿 설정
    console.log('🔐 GitHub 시크릿 설정 중...')
    const results = await Promise.all(
        secrets.map((secret) => setGitHubSecret(secret.name, envVars[secret.name]))
    )

    // .env 파일 생성
    console.log('\n📄 .env 파일 생성 중...')
    createEnvFile(envVars)

    // 결과 요약
    const successCount = results.filter(Boolean).length
    console.log(`\n🎉 완료: ${successCount}/${secrets.length} 시크릿 설정 성공`)

    if (successCount === secrets.length) {
        console.log('✅ 모든 설정이 완료되었습니다!')
        console.log('📍 생성된 .env 파일: apps/web/.env')
    } else {
        console.log('⚠️  일부 설정이 실패했습니다. 로그를 확인해주세요.')
    }
}

// 스크립트 실행
main().catch(console.error)
```

2. `packages/scripts/package.json` 의 bin 프로퍼티에 `set-github-secret.mjs` 를 등록
```json
{
  "bin": {
    "set-github-secret": "./set-github-secret.mjs"
  }
}
```

3. `package.json` 의 script 프로퍼티에 `set-github-secret` 명령을 등록
```json
{
  "scripts": {
    "set-github-secret": "set-github-secret",
  }
}
```