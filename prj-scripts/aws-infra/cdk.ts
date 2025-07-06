#!/usr/bin/env node
import * as cdk from 'aws-cdk-lib'
import {CdkStack} from './cdk-stack'
import * as path from 'path'
import {execSync} from 'child_process'
import {readFileSync} from 'fs'

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
const lambdaEntry = path.join(__dirname, './lambda.ts')
const staticAssetPath = path.join(
    __dirname,
    '../../apps/web/build/client/assets'
)

// destroyStackWithDNS 함수는 ./cdk-dns-delete.ts에서 import됩니다

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