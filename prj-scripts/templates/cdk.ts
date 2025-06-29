#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'
import { CdkStack } from './cdk-stack'
import * as path from 'path'
import { execSync } from 'child_process'
import { writeFileSync, readFileSync } from 'fs'
import { updateDNS, deleteDNS } from './update_dns'

/**
 * 프로젝트 루트의 package.json에서 프로젝트 이름을 가져오는 순수함수
 */
function getProjectName(): string {
  const packageJsonPath = path.join(__dirname, '../../package.json')
  const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf-8'))

  return packageJson.name || 'unknown-project'
}

const projectName = getProjectName()
// Get current git branch name
const branchName = execSync('git rev-parse --abbrev-ref HEAD', {
  encoding: 'utf-8'
}).trim()
const environment = process.env.NODE_ENV || 'development'
const lambdaEntry = path.join(__dirname, './entry/lambda.ts')
const staticAssetPath = path.join(
  __dirname,
  '../../apps/web/build/client/assets'
)

type EnvUpdateResult = {
  lines: string[]
  updated: boolean
}

/**
 * .env 파일 경로를 생성하는 순수함수
 */
function createEnvPath(): string {
  return path.join(__dirname, '../../.env')
}

/**
 * 환경변수 라인을 업데이트하는 순수함수
 */
function updateEnvLines(lines: string[], lambdaUrl: string): EnvUpdateResult {
  return lines.reduce<EnvUpdateResult>(
    (acc, line) => {
      if (line.startsWith('RECORD_VALUE=')) {
        return {
          lines: [...acc.lines, `RECORD_VALUE=${lambdaUrl}`],
          updated: true
        }
      }

      return {
        lines: [...acc.lines, line],
        updated: acc.updated
      }
    },
    { lines: [], updated: false }
  )
}

/**
 * 새로운 환경변수 라인을 추가하는 순수함수
 */
function addEnvLine(lines: string[], lambdaUrl: string): string[] {
  return [...lines, `RECORD_VALUE=${lambdaUrl}`]
}

/**
 * 로그 메시지를 생성하는 순수함수
 */
function createEnvLogMessages(lambdaUrl: string) {
  return {
    success: `✅ .env 파일의 RECORD_VALUE가 업데이트되었습니다: ${lambdaUrl}`,
    dnsStart: '\n🌐 Cloudflare DNS 업데이트를 시작합니다...',
    dnsSkip: 'ℹ️ DOMAIN이 설정되지 않아 DNS 업데이트를 건너뜁니다.',
    error: '❌ .env 파일 또는 DNS 업데이트 실패:',
    manual: '\n💡 DNS 업데이트가 실패했습니다. 수동으로 실행해주세요:',
    command: '   cd packages/infra && pnpm update-dns'
  }
}

/**
 * DNS 업데이트 에러를 확인하는 순수함수
 */
function isDomainMissingError(error: unknown): boolean {
  return (
    error instanceof Error &&
    error.message.includes('DOMAIN 환경변수가 설정되지 않아')
  )
}

/**
 * DNS 업데이트를 처리하는 순수함수
 */
async function processDNSUpdate(): Promise<void> {
  await updateDNS() // Wrangler CLI 사용
}

/**
 * DNS 업데이트를 실행하는 함수
 */
async function executeDNSUpdate(
  messages: ReturnType<typeof createEnvLogMessages>
): Promise<void> {
  console.log(messages.dnsStart)

  try {
    await processDNSUpdate()
  } catch (error) {
    if (isDomainMissingError(error)) {
      console.log(messages.dnsSkip)

      return
    }

    throw error
  }
}

/**
 * DNS 삭제를 처리하는 순수함수
 */
async function processDNSDelete(): Promise<void> {
  await deleteDNS() // Wrangler CLI 사용
}

/**
 * DNS 삭제를 실행하는 함수
 */
async function executeDNSDelete(): Promise<void> {
  console.log('\n🗑️ Cloudflare DNS 레코드 삭제를 시작합니다...')

  try {
    await processDNSDelete()
  } catch (error) {
    if (isDomainMissingError(error)) {
      console.log('ℹ️ DOMAIN이 설정되지 않아 DNS 삭제를 건너뜁니다.')

      return
    }

    console.error('❌ DNS 삭제 실패:', error)
    console.log('\n💡 DNS 레코드 삭제가 실패했습니다. 수동으로 실행해주세요:')
    console.log('   cd packages/infra && pnpm update-dns (Wrangler CLI로 수동 삭제)')
  }
}

const getUpdatedFinalLines = ({
  lambdaUrl,
  envPath
}: {
  lambdaUrl: string
  envPath: string
}) => {
  const envContent = readFileSync(envPath, 'utf-8')
  const lines = envContent.split('\n')
  const updatedResult = updateEnvLines(lines, lambdaUrl)

  if (updatedResult.updated) {
    return updatedResult.lines
  }

  return addEnvLine(updatedResult.lines, lambdaUrl)
}

/**
 * .env 파일의 RECORD_VALUE를 업데이트하고 DNS를 업데이트하는 함수
 */
async function updateEnvRecordValueAndDNS(lambdaUrl: string): Promise<void> {
  const envPath = createEnvPath()
  const messages = createEnvLogMessages(lambdaUrl)

  try {
    // 1. .env 파일 업데이트
    const finalLines = getUpdatedFinalLines({ envPath, lambdaUrl })
    writeFileSync(envPath, finalLines.join('\n'))
    console.log(messages.success)

    // 2. DNS 업데이트 실행
    await executeDNSUpdate(messages)
  } catch (error) {
    console.error(messages.error, error)
    console.log(messages.manual)
    console.log(messages.command)
  }
}

/**
 * DNS 삭제를 포함한 완전한 스택 삭제 함수
 */
export async function destroyStackWithDNS(): Promise<void> {
  console.log('🗑️ 스택 삭제 시작: DNS 레코드 및 AWS 리소스를 삭제합니다...')

  // 1. DNS 레코드 삭제 먼저 실행
  try {
    await executeDNSDelete()
  } catch (error) {
    console.warn('⚠️ DNS 삭제 중 오류가 발생했지만 스택 삭제를 계속 진행합니다:', error)
  }

  // 2. CDK 스택 삭제
  console.log('\n🔥 AWS CDK 스택 삭제 중...')
  try {
    execSync('npx cdk destroy --force', { 
      stdio: 'inherit',
      cwd: __dirname 
    })
    console.log('✅ 스택 삭제가 완료되었습니다!')
  } catch (error) {
    console.error('❌ CDK 스택 삭제 실패:', error)
    throw error
  }
}

const app = new cdk.App()
new CdkStack(app, `${projectName}-${branchName}`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT || process.env.AWS_ACCOUNT_ID,
    region:
      process.env.CDK_DEFAULT_REGION ||
      process.env.AWS_DEFAULT_REGION ||
      'ap-northeast-2'
  },
  lambdaEntry,
  staticAssetPath,
  environment,
  tags: {
    Environment: environment,
    Project: projectName
  },
  onDeploySuccess: updateEnvRecordValueAndDNS
})