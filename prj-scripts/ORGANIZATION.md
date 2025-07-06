# Template Organization

Templates are now organized into namespace directories based on their function context:

## Directory Structure

- **env/** - Environment configuration
  - `.env` - Environment variables template

- **eslint/** - ESLint package templates
  - `eslint-index.mjs` - ESLint package main file

- **aws-infra/** - AWS Infrastructure (CDK) templates
  - `cdk-stack.ts` - CDK stack definition
  - `cdk.json` - CDK configuration
  - `cdk.ts` - CDK application entry point
  - `README.md` - AWS Infrastructure README
  - `lambda.ts` - Lambda function template
  - `delete-dns.ts` - DNS record deletion script (독립 실행 가능)

- **prettier/** - Prettier package templates

- **project/** - Project-level templates
  - `README.md` - Project README template

- **projectRoot/** - Project root configuration templates
  - `README.md` - Project README template
  - `eslint.config.mjs` - Root ESLint configuration
  - `prettier.config.mjs` - Root Prettier configuration
  - `package.json` - Project package.json template
  - `pnpm-workspace.yaml` - PNPM workspace configuration
  - `turbo.json` - Turborepo configuration

- **react-router/** - React Router application templates
  - `error-boundary.tsx` - Error boundary component
  - `home.tsx` - Home route component
  - `eslint.config.mjs` - React Router app ESLint configuration
  - `prettier.config.mjs` - React Router app Prettier configuration

- **scripts/** - Utility scripts
  - `format.mjs` - Code formatting script
  - `scripts-readme.md` - Scripts package documentation
  - `sync-catalog.mjs` - Package catalog synchronization
  - `sync-versions.mjs` - Version synchronization script

- **semantic-release/** - Semantic release templates
  - `release.config.ts` - Semantic release configuration

- **typescript/** - TypeScript configuration
  - `tsconfig.json` - TypeScript configuration

- **vscode/** - VS Code workspace templates
  - `vscode-extensions.json` - Recommended extensions
  - `vscode-settings.json` - Workspace settings

- **workflows/** - GitHub Actions workflow templates
  - `deploy-rr7-lambda-s3.yml` - AWS Lambda deployment workflow
  - `update-cloudflare-dns.yml` - Cloudflare DNS update workflow
  - `notify-telegram.yml` - Telegram notification workflow
  - `notify-telegram-test.yml` - Telegram notification test workflow
  - `semantic-release.yml` - Semantic release workflow

- **workspace/** - Monorepo workspace templates
  - `pnpm-workspace.yaml` - PNPM workspace configuration
  - `turbo.json` - Turborepo configuration

## Function Mapping

Each namespace corresponds to specific functions in `prj.sh`:

- `env/` ← `create_env_template()`
- `eslint/` ← `setup_eslint_package()`
- `aws-infra/` ← `setup_aws_infra_package()`
- `prettier/` ← `setup_prettier_package()`
- `project/` ← `create_project_readme()`
- `projectRoot/` ← `setup_prettier_config()`, `setup_eslint_config()`, `setup_package_json_private()`, `create_workspace_structure()`
- `react-router/` ← `setup_react_router_web()` (includes app-specific configs)
- `scripts/` ← `setup_scripts_package()`, `setup_scripts_readme()`
- `semantic-release/` ← `setup_semantic_release()`
- `typescript/` ← `setup_typescript()`
- `vscode/` ← `setup_vscode_workspace()`
- `workflows/` ← `setup_aws_deployment_workflows()`, `setup_dns_workflows()`, `setup_telegram_workflows()`, `setup_semantic_release()`
- `workspace/` ← `create_workspace_structure()`