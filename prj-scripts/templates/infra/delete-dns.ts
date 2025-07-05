import { execSync } from 'node:child_process'
import { config } from 'dotenv'
import { join } from 'node:path'

// .env 파일에서 환경변수 로드 (프로젝트 루트에서)
config({ path: join(__dirname, '../../.env') })

type CloudflareRecord = {
  id?: string
  type: string
  name: string
  content: string
  ttl: number
}

type DNSConfig = {
  apiToken: string
  accountId: string
  domain: string
  subdomain?: string
  recordType: string
  recordValue: string
  ttl: number
}

/**
 * 환경변수에서 필요한 값을 가져오는 순수함수
 */
function getRequiredEnv(key: string): string {
  const value = process.env[key]

  if (!value) {
    throw new Error(`❌ 필수 환경변수가 설정되지 않았습니다: ${key}`)
  }

  return value
}

/**
 * 환경변수에서 DNS 설정을 구성하는 순수함수
 * DOMAIN이 없으면 null을 반환하여 DNS 삭제를 건너뛸 수 있도록 함
 */
function createDNSConfig(): DNSConfig | null {
  // DOMAIN이 없으면 DNS 삭제를 하지 않음
  const domain = process.env.DOMAIN

  if (!domain) {
    return null
  }

  return {
    apiToken: getRequiredEnv('CLOUDFLARE_API_TOKEN'),
    accountId: getRequiredEnv('CLOUDFLARE_ACCOUNT_ID'),
    domain,
    recordType: getRequiredEnv('RECORD_TYPE'),
    recordValue: getRequiredEnv('RECORD_VALUE'),
    subdomain: process.env.SUBDOMAIN, // 선택사항 - 없으면 메인 도메인 사용
    ttl: Number.parseInt(process.env.TTL || '300', 10)
  }
}

/**
 * 현재 Git 브랜치를 가져오는 순수함수
 */
function getCurrentBranch(): string {
  try {
    return execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8' }).trim()
  } catch {
    console.warn('⚠️ Git 브랜치 정보를 가져올 수 없습니다. main 브랜치로 설정합니다.')

    return 'main'
  }
}

/**
 * 브랜치와 서브도메인 정보를 기반으로 전체 도메인을 생성하는 순수함수
 *
 * 도메인 생성 규칙:
 * 1. 도메인만 있을 경우 main 브랜치 푸시: example.com
 * 2. 도메인만 있을 경우 develop 브랜치 푸시: develop.example.com
 * 3. 도메인과 서브도메인이 있을 경우 main 브랜치 푸시: sub.example.com
 * 4. 도메인과 서브도메인이 있을 경우 develop 브랜치 푸시: develop-sub.example.com
 */
function getFullDomain(domain: string, subdomain?: string): string {
  const currentBranch = getCurrentBranch()

  // main 브랜치인 경우
  if (currentBranch === 'main') {
    // 서브도메인이 있으면 서브도메인 사용, 없으면 메인 도메인 사용
    if (subdomain) {
      return `${subdomain}.${domain}`
    }

    return domain
  }

  // main이 아닌 브랜치인 경우 - 서브도메인이 있는 경우
  if (subdomain) {
    return `${currentBranch}-${subdomain}.${domain}`
  }

  // main이 아닌 브랜치인 경우 - 서브도메인이 없는 경우
  return `${currentBranch}.${domain}`
}

/**
 * Wrangler CLI 명령어를 생성하는 순수함수
 */
function createWranglerCommand(
    action: 'list' | 'delete',
    domain: string,
    record?: CloudflareRecord,
    recordId?: string
): string {
  if (action === 'list') {
    return `wrangler dns list --zone ${domain} --type ${record?.type || 'A'}`
  }

  if (action === 'delete') {
    if (!recordId) throw new Error('삭제할 레코드 ID가 필요합니다')

    return `wrangler dns delete ${domain} ${recordId}`
  }

  throw new Error(`지원하지 않는 액션: ${action}`)
}

/**
 * Wrangler CLI 출력에서 기존 레코드를 찾는 순수함수
 */
function parseWranglerOutput(
    output: string,
    fullDomain: string,
    recordType: string,
    dnsConfig: DNSConfig
): CloudflareRecord | null {
  const lines = output.split('\n')

  const matchingLine = lines.find(
      (line) => line.includes(fullDomain) && line.includes(recordType)
  )

  if (matchingLine) {
    const parts = matchingLine.trim().split(/\s+/)

    if (parts.length > 0) {
      return {
        id: parts[0],
        type: recordType,
        name: fullDomain,
        content: dnsConfig.recordValue,
        ttl: dnsConfig.ttl
      }
    }
  }

  return null
}

/**
 * Cloudflare DNS 레코드 삭제 클래스
 */
export class CloudflareDNSDeleter {
  private readonly dnsConfig: DNSConfig

  constructor(dnsConfig?: DNSConfig) {
    const _config = dnsConfig || createDNSConfig()

    if (!_config) {
      throw new Error(
          '❌ DOMAIN 환경변수가 설정되지 않아 DNS 삭제를 건너뜁니다.'
      )
    }

    this.dnsConfig = _config

    const fullDomain = getFullDomain(this.dnsConfig.domain, this.dnsConfig.subdomain)
    console.log('🔧 DNS 삭제 설정:')
    console.log(`   도메인: ${fullDomain}`)
    console.log(`   레코드 타입: ${this.dnsConfig.recordType}`)
  }

  /**
   * Wrangler CLI를 사용하여 DNS 레코드 삭제
   */
  async deleteDNSWithWrangler(): Promise<void> {
    try {
      console.log('🗑️ Wrangler CLI를 사용하여 DNS 레코드 삭제 중...')

      // Wrangler 설치 확인
      this.checkWranglerInstallation()

      // 현재 DNS 레코드 조회
      const existingRecord = await this.findExistingRecordWithWrangler()

      if (!existingRecord) {
        console.log('ℹ️ 삭제할 DNS 레코드가 없습니다.')

        return
      }

      console.log(`🗑️ DNS 레코드 삭제 중... (ID: ${existingRecord.id})`)
      await this.executeWranglerDelete(existingRecord.id!)

      console.log('✅ DNS 레코드 삭제 완료!')
    } catch (error) {
      console.error('❌ DNS 레코드 삭제 실패:', error)
      throw error
    }
  }

  /**
   * Wrangler 설치 확인
   */
  private checkWranglerInstallation(): void {
    try {
      execSync('wrangler --version', { stdio: 'pipe' })
    } catch {
      throw new Error(
          '❌ Wrangler CLI가 설치되지 않았습니다. npm install -g wrangler 명령으로 설치해주세요.'
      )
    }
  }

  /**
   * 기존 DNS 레코드 찾기 (Wrangler CLI 사용)
   */
  private async findExistingRecordWithWrangler(): Promise<CloudflareRecord | null> {
    try {
      const command = createWranglerCommand('list', this.dnsConfig.domain, {
        type: this.dnsConfig.recordType
      } as CloudflareRecord)
      const output = execSync(command, {
        encoding: 'utf8',
        env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
      })

      const fullDomain = getFullDomain(
          this.dnsConfig.domain,
          this.dnsConfig.subdomain
      )

      return parseWranglerOutput(
          output,
          fullDomain,
          this.dnsConfig.recordType,
          this.dnsConfig
      )
    } catch {
      console.log('🔍 기존 레코드 없음.')

      return null
    }
  }

  /**
   * DNS 레코드 삭제 (Wrangler CLI 사용)
   */
  private async executeWranglerDelete(recordId: string): Promise<void> {
    const command = createWranglerCommand(
        'delete',
        this.dnsConfig.domain,
        undefined,
        recordId
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
  }
}

/**
 * DNS 삭제 실행 함수 (Wrangler CLI만 사용)
 * @param dnsConfig 선택적 DNS 설정 (없으면 환경변수에서 자동 생성)
 */
export async function deleteDNS(dnsConfig?: DNSConfig): Promise<void> {
  try {
    const deleter = new CloudflareDNSDeleter(dnsConfig)
    await deleter.deleteDNSWithWrangler()
  } catch (error) {
    if (error instanceof Error && error.message.includes('DOMAIN 환경변수가 설정되지 않아')) {
      console.log('ℹ️ DOMAIN 환경변수가 설정되지 않아 DNS 삭제를 건너뜁니다.')

      return
    }
    throw error
  }
}

/**
 * 메인 실행 함수
 */
async function runMain(): Promise<void> {
  try {
    const dnsConfig = createDNSConfig()

    // DOMAIN이 없으면 DNS 삭제를 건너뜀
    if (!dnsConfig) {
      console.log(
          'ℹ️ DOMAIN 환경변수가 설정되지 않아 DNS 삭제를 건너뜁니다.'
      )

      return
    }

    console.log('🔧 Wrangler CLI 모드로 DNS 삭제 실행...')
    await deleteDNS(dnsConfig)

    console.log('🎉 DNS 삭제가 완료되었습니다!')
  } catch (error) {
    console.error('❌ DNS 삭제 실패:', error)
    process.exit(1)
  }
}

/**
 * 스크립트가 직접 실행될 때
 */
if (require.main === module) {
  runMain().catch((error) => {
    console.error('❌ 스크립트 실행 실패:', error)
    process.exit(1)
  })
}