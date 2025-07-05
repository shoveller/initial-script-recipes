#!/usr/bin/env node

import { execSync } from 'child_process'
import { readFileSync, writeFileSync, readdirSync, statSync } from 'fs'
import { join, dirname } from 'path'
import { fileURLToPath } from 'url'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

// 프로젝트 루트 디렉토리
const rootDir = join(__dirname, '../../')

/**
 * 프로젝트 루트의 package.json에서 pnpm 버전을 추출
 */
function getPnpmVersionFromPackageJson() {
  try {
    const packageJsonPath = join(rootDir, 'package.json')
    const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'))

    if (!packageJson.packageManager) {
      throw new Error('package.json에 packageManager 필드가 없습니다.')
    }

    // "pnpm@9.5.0" 형태에서 버전만 추출
    const match = packageJson.packageManager.match(/pnpm@(.+)/)
    if (!match) {
      throw new Error('packageManager 필드에서 pnpm 버전을 찾을 수 없습니다.')
    }

    return match[1]
  } catch (error) {
    console.error('❌ pnpm 버전 추출 실패:', error.message)
    process.exit(1)
  }
}

/**
 * 프로젝트 루트의 package.json에서 Node.js 버전을 추출
 */
function getNodeVersionFromPackageJson() {
  try {
    const packageJsonPath = join(rootDir, 'package.json')
    const packageJson = JSON.parse(readFileSync(packageJsonPath, 'utf8'))

    if (!packageJson.engines?.node) {
      throw new Error('package.json에 engines.node 필드가 없습니다.')
    }

    // ">=20.0.0" 형태에서 버전만 추출
    const match = packageJson.engines.node.match(/([0-9]+(?:\.[0-9]+)*)/)
    if (!match) {
      throw new Error('engines.node 필드에서 Node.js 버전을 찾을 수 없습니다.')
    }

    return match[1]
  } catch (error) {
    console.error('❌ Node.js 버전 추출 실패:', error.message)
    process.exit(1)
  }
}

/**
 * .github/workflows 디렉토리에서 모든 workflow 파일을 찾기
 */
function findWorkflowFiles() {
  const workflowDir = join(rootDir, '.github/workflows')
  const files = []

  try {
    const entries = readdirSync(workflowDir)

    for (const entry of entries) {
      const fullPath = join(workflowDir, entry)
      const stat = statSync(fullPath)

      if (
          stat.isFile() &&
          (entry.endsWith('.yml') || entry.endsWith('.yaml'))
      ) {
        files.push(fullPath)
      }
    }
  } catch (error) {
    console.warn(
        '⚠️  .github/workflows 디렉토리를 찾을 수 없습니다:',
        error.message
    )
  }

  return files
}

/**
 * GitHub Actions workflow 파일에서 pnpm 버전 업데이트
 */
function updatePnpmVersionInWorkflow(filePath, newVersion) {
  try {
    let content = readFileSync(filePath, 'utf8')
    let updated = false

    // "- name: Install pnpm" 다음에 오는 pnpm/action-setup의 version 찾기
    const regex =
        /(- name:\s*Install pnpm[\s\S]*?uses:\s*pnpm\/action-setup@[^\n]*\n\s*with:[\s\S]*?version:\s*['"]?)([^'"\n]+)(['"]?)/gi

    content = content.replace(
        regex,
        (match, prefix, currentVersion, suffix) => {
          if (currentVersion !== newVersion) {
            console.log(
                `  📝 ${filePath}에서 pnpm 버전 업데이트: ${currentVersion} → ${newVersion}`
            )
            updated = true
            return prefix + newVersion + suffix
          }
          return match
        }
    )

    if (updated) {
      writeFileSync(filePath, content, 'utf8')
      return true
    }

    return false
  } catch (error) {
    console.error(`❌ ${filePath} 업데이트 실패:`, error.message)
    return false
  }
}

/**
 * GitHub Actions workflow 파일에서 Node.js 버전 업데이트
 */
function updateNodeVersionInWorkflow(filePath, newVersion) {
  try {
    let content = readFileSync(filePath, 'utf8')
    let updated = false

    // "- name: Setup Node.js" 다음에 오는 actions/setup-node의 node-version 찾기
    const regex =
        /(- name:\s*Setup Node\.js[\s\S]*?uses:\s*actions\/setup-node@[^\n]*\n\s*with:[\s\S]*?node-version:\s*['"]?)([^'"\n]+)(['"]?)/gi

    content = content.replace(
        regex,
        (match, prefix, currentVersion, suffix) => {
          if (currentVersion !== newVersion) {
            console.log(
                `  📝 ${filePath}에서 Node.js 버전 업데이트: ${currentVersion} → ${newVersion}`
            )
            updated = true
            return prefix + newVersion + suffix
          }
          return match
        }
    )

    if (updated) {
      writeFileSync(filePath, content, 'utf8')
      return true
    }

    return false
  } catch (error) {
    console.error(`❌ ${filePath} 업데이트 실패:`, error.message)
    return false
  }
}

/**
 * pnpm codemod-catalog 실행
 */
function runCodemodCatalog() {
  try {
    console.log('🔄 pnpm codemod-catalog 실행 중...')
    execSync('pnpx codemod pnpm/catalog', {
      cwd: rootDir,
      stdio: 'inherit'
    })

    console.log('✅ codemod-catalog 실행 완료')
  } catch (error) {
    console.error('❌ codemod-catalog 실행 실패:', error.message)
    console.error(
        '오류 세부사항:',
        error.stderr?.toString() || '알 수 없는 오류'
    )
    process.exit(1)
  }
}

/**
 * 메인 실행 함수
 */
function main() {
  console.log('🎯 sync-catalog 스크립트 시작\n')

  // 1. pnpm codemod-catalog 실행
  runCodemodCatalog()

  // 2. package.json에서 pnpm 버전 추출
  const pnpmVersion = getPnpmVersionFromPackageJson()
  console.log(`📦 현재 pnpm 버전: ${pnpmVersion}`)

  // 3. package.json에서 Node.js 버전 추출
  const nodeVersion = getNodeVersionFromPackageJson()
  console.log(`🚀 현재 Node.js 버전: ${nodeVersion}\n`)

  // 4. GitHub Actions workflow 파일들 찾기
  const workflowFiles = findWorkflowFiles()
  console.log(`🔍 발견된 workflow 파일: ${workflowFiles.length}개\n`)

  // 5. 각 workflow 파일에서 pnpm 및 Node.js 버전 업데이트
  let totalUpdated = 0

  for (const filePath of workflowFiles) {
    console.log(`🔧 ${filePath} 처리 중...`)
    let fileUpdated = false

    if (updatePnpmVersionInWorkflow(filePath, pnpmVersion)) {
      fileUpdated = true
    }

    if (updateNodeVersionInWorkflow(filePath, nodeVersion)) {
      fileUpdated = true
    }

    if (fileUpdated) {
      totalUpdated++
    } else {
      console.log(`  ℹ️  ${filePath}는 업데이트가 필요하지 않습니다.`)
    }
  }

  console.log(`\n✨ 완료! ${totalUpdated}개 파일이 업데이트되었습니다.`)

  if (totalUpdated > 0) {
    console.log('\n💡 변경사항을 커밋하는 것을 잊지 마세요!')
  }
}

// 스크립트 실행
main()