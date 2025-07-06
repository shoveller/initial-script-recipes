#!/usr/bin/env node

const { execSync } = require('node:child_process')
const path = require('node:path')

// aws-infra 패키지 디렉토리 (절대 경로)
const awsInfraDir = path.resolve(__dirname, '..')

try {
  console.log('💥 Starting AWS infrastructure destruction...')
  console.log(`📁 Working directory: ${awsInfraDir}`)
  
  // destroy 스크립트 실행 (pnpm 사용)
  execSync('pnpm run destroy', {
    cwd: awsInfraDir,
    stdio: 'inherit'
  })
  
  console.log('✅ Infrastructure destroyed successfully!')
} catch (error) {
  console.error('❌ Destruction failed:', error.message)
  process.exit(1)
}