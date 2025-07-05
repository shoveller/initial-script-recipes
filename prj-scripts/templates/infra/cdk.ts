#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'
import { CdkStack } from './cdk-stack'
import * as path from 'path'
import { execSync } from 'child_process'
import { readFileSync } from 'fs'
import { deleteDNS } from './delete-dns'

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






/**
 * DNS 삭제 에러를 확인하는 순수함수
 */
function isDomainMissingError(error: unknown): boolean {
  return (
    error instanceof Error &&
    error.message.includes('DOMAIN 환경변수가 설정되지 않아')
  )
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
})