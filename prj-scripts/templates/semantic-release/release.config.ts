import { GlobalConfig } from 'semantic-release'

// GitHub Actions 환경 변수로부터 저장소 URL 생성
const getRepositoryUrl = (): string => {
  // GitHub Actions 환경에서 실행 중인 경우
  if (!process.env.GITHUB_REPOSITORY) {
    throw new Error('env.GITHUB_REPOSITORY not found')
  }

  // 로컬 환경 또는 환경 변수가 없는 경우 기본값 사용
  return `${process.env.GITHUB_SERVER_URL || 'https://github.com'}/${process.env.GITHUB_REPOSITORY}`
}

const config: GlobalConfig = {
  branches: ['main'],
  repositoryUrl: getRepositoryUrl(),
  tagFormat: '${version}',
  plugins: [
    '@semantic-release/commit-analyzer', // 커밋 메시지를 분석하여 버전 결정
    '@semantic-release/release-notes-generator', // CHANGELOG.md에 들어갈 릴리스 노트를 생성
    '@semantic-release/changelog', // CHANGELOG.md 업데이트
    [
      '@semantic-release/npm',
      {
        npmPublish: false
      }
    ], // npm 배포, package.json 업데이트
    '@semantic-release/github', // GitHub Release를 생성
    [
      '@semantic-release/git', //  Git 커밋 및 푸시
      {
        assets: ['CHANGELOG.md', 'package.json', 'packages/*/package.json', 'apps/*/package.json'],
        message:
          'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}'
      }
    ]
  ]
}

export default config