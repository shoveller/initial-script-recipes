#!/usr/bin/env node

const { execSync } = require('node:child_process')
const path = require('node:path')

// aws-infra 패키지 디렉토리 (절대 경로)
const awsInfraDir = path.resolve(__dirname, '..')

try {
  console.log('🚀 Starting AWS deployment...')
  console.log(`📁 Working directory: ${awsInfraDir}`)
  
  // launch 스크립트 실행 (pnpm 사용)
  execSync('pnpm run launch', {
    cwd: awsInfraDir,
    stdio: 'inherit'
  })
  
  console.log('✅ Deployment completed successfully!')
} catch (error) {
  console.error('❌ Deployment failed:', error.message)
  process.exit(1)
}