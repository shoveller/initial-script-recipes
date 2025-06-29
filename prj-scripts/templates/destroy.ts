#!/usr/bin/env node
import { destroyStackWithDNS } from './cdk'

/**
 * DNS 레코드와 AWS 리소스를 모두 삭제하는 스크립트
 */
async function main(): Promise<void> {
  try {
    await destroyStackWithDNS()
  } catch (error) {
    console.error('❌ 전체 삭제 프로세스 실패:', error)
    process.exit(1)
  }
}

// 스크립트가 직접 실행될 때
if (require.main === module) {
  main().catch((error) => {
    console.error('❌ 스크립트 실행 실패:', error)
    process.exit(1)
  })
}