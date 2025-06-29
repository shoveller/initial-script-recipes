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
 * DOMAIN이 없으면 null을 반환하여 DNS 업데이트를 건너뛸 수 있도록 함
 */
function createDNSConfig(): DNSConfig | null {
  // DOMAIN이 없으면 DNS 업데이트를 하지 않음
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
 * 전체 도메인을 생성하는 순수함수
 */
function getFullDomain(domain: string, subdomain?: string): string {
  if (subdomain) {
    return `${subdomain}.${domain}`
  }

  return domain
}

/**
 * DNS 레코드 객체를 생성하는 순수함수
 */
function createDNSRecord(dnsConfig: DNSConfig): CloudflareRecord {
  return {
    type: dnsConfig.recordType,
    name: getFullDomain(dnsConfig.domain, dnsConfig.subdomain),
    content: dnsConfig.recordValue,
    ttl: dnsConfig.ttl
  }
}

/**
 * Wrangler CLI 명령어를 생성하는 순수함수
 */
function createWranglerCommand(
  action: 'create' | 'update' | 'list' | 'delete',
  domain: string,
  record?: CloudflareRecord,
  recordId?: string
): string {
  if (action === 'list') {
    return `wrangler dns list --zone ${domain} --type ${record?.type || 'A'}`
  }

  if (action === 'create') {
    if (!record) throw new Error('레코드 정보가 필요합니다')

    return `wrangler dns create ${domain} "${record.name}" ${record.type} "${record.content}" --ttl ${record.ttl}`
  }

  if (action === 'update') {
    if (!record || !recordId) throw new Error('레코드 정보와 ID가 필요합니다')

    return `wrangler dns update ${domain} ${recordId} --type ${record.type} --content "${record.content}" --ttl ${record.ttl}`
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
 * 로그 메시지를 생성하는 순수함수
 */
function createLogMessages(dnsConfig: DNSConfig) {
  const fullDomain = getFullDomain(dnsConfig.domain, dnsConfig.subdomain)

  return {
    config: [
      '🔧 DNS 업데이트 설정:',
      `   도메인: ${fullDomain}`,
      `   레코드 타입: ${dnsConfig.recordType}`,
      `   대상: ${dnsConfig.recordValue}`,
      `   TTL: ${dnsConfig.ttl}초`
    ].join('\n'),
    wranglerStart: '🌐 Wrangler CLI를 사용하여 DNS 레코드 업데이트 중...',
    recordFound: '📝 기존 DNS 레코드 발견, 업데이트 중...',
    recordCreate: '➕ 새 DNS 레코드 생성 중...',
    recordNotFound: '🔍 기존 레코드 없음, 새로 생성합니다.',
    success: '✅ DNS 레코드 업데이트 완료!',
    complete: '🎉 DNS 업데이트가 완료되었습니다!'
  }
}

/**
 * Cloudflare DNS 레코드를 업데이트하는 클래스
 */
export class CloudflareDNSUpdater {
  private readonly dnsConfig: DNSConfig
  private readonly messages: ReturnType<typeof createLogMessages>

  constructor(dnsConfig?: DNSConfig) {
    const _config = dnsConfig || createDNSConfig()

    if (!_config) {
      throw new Error(
        '❌ DOMAIN 환경변수가 설정되지 않아 DNS 업데이트를 건너뜁니다.'
      )
    }

    this.dnsConfig = _config
    this.messages = createLogMessages(this.dnsConfig)

    console.log(this.messages.config)
  }

  /**
   * Wrangler CLI를 사용하여 DNS 레코드 업데이트
   */
  async updateDNSWithWrangler(): Promise<void> {
    try {
      console.log(this.messages.wranglerStart)

      // Wrangler 설치 확인
      this.checkWranglerInstallation()

      // 현재 DNS 레코드 조회
      const existingRecord = await this.findExistingRecordWithWrangler()
      const record = createDNSRecord(this.dnsConfig)

      if (!existingRecord) {
        console.log(this.messages.recordCreate)
        await this.executeWranglerCreate(record)

        console.log(this.messages.success)

        return
      }

      console.log(this.messages.recordFound)
      await this.executeWranglerUpdate(existingRecord.id!, record)

      console.log(this.messages.success)
    } catch (error) {
      console.error('❌ DNS 업데이트 실패:', error)
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
      console.log(this.messages.recordNotFound)

      return null
    }
  }

  /**
   * DNS 레코드 생성 (Wrangler CLI 사용)
   */
  private async executeWranglerCreate(record: CloudflareRecord): Promise<void> {
    const command = createWranglerCommand(
      'create',
      this.dnsConfig.domain,
      record
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
  }

  /**
   * DNS 레코드 업데이트 (Wrangler CLI 사용)
   */
  private async executeWranglerUpdate(
    recordId: string,
    record: CloudflareRecord
  ): Promise<void> {
    const command = createWranglerCommand(
      'update',
      this.dnsConfig.domain,
      record,
      recordId
    )

    execSync(command, {
      stdio: 'inherit',
      env: { ...process.env, CLOUDFLARE_API_TOKEN: this.dnsConfig.apiToken }
    })
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
 * DNS 업데이트 실행 함수 (Wrangler CLI만 사용)
 * @param dnsConfig 선택적 DNS 설정 (없으면 환경변수에서 자동 생성)
 */
export async function updateDNS(dnsConfig?: DNSConfig): Promise<void> {
  const updater = new CloudflareDNSUpdater(dnsConfig)
  await updater.updateDNSWithWrangler()
}

/**
 * DNS 삭제 실행 함수 (Wrangler CLI만 사용)
 * @param dnsConfig 선택적 DNS 설정 (없으면 환경변수에서 자동 생성)
 */
export async function deleteDNS(dnsConfig?: DNSConfig): Promise<void> {
  try {
    const updater = new CloudflareDNSUpdater(dnsConfig)
    await updater.deleteDNSWithWrangler()
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

    // DOMAIN이 없으면 DNS 업데이트를 건너뜀
    if (!dnsConfig) {
      console.log(
        'ℹ️ DOMAIN 환경변수가 설정되지 않아 DNS 업데이트를 건너뜁니다.'
      )

      return
    }

    const messages = createLogMessages(dnsConfig)

    console.log('🔧 Wrangler CLI 모드로 실행...')
    await updateDNS(dnsConfig)

    console.log(messages.complete)
  } catch (error) {
    console.error('❌ DNS 업데이트 실패:', error)
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