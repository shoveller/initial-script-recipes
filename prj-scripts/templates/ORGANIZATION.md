# Template Organization

Templates are now organized into namespace directories based on their function context:

## Directory Structure

- **aws/** - AWS-related templates
  - `deploy-aws-lambda.yml` - AWS Lambda deployment workflow

- **config/** - Configuration files for root project
  - `eslint.config.mjs` - Root ESLint configuration
  - `prettier.config.mjs` - Root Prettier configuration

- **env/** - Environment configuration
  - `.env` - Environment variables template

- **eslint/** - ESLint package templates
  - `eslint-index.mjs` - ESLint package main file

- **infra/** - Infrastructure (CDK) templates
  - `cdk-stack.ts` - CDK stack definition
  - `cdk.json` - CDK configuration
  - `cdk.ts` - CDK application entry point
  - `infrastructure-readme.md` - Infrastructure documentation
  - `lambda.ts` - Lambda function template
  - `delete-dns.ts` - DNS record deletion script (독립 실행 가능)

- **prettier/** - Prettier package templates
  - `prettier-index.mjs` - Prettier package main file

- **project/** - Project-level templates
  - `README.md` - Project README template

- **react-router/** - React Router application templates
  - `error-boundary.tsx` - Error boundary component
  - `home.tsx` - Home route component

- **scripts/** - Utility scripts
  - `format.mjs` - Code formatting script
  - `scripts-readme.md` - Scripts package documentation
  - `sync-catalog.mjs` - Package catalog synchronization
  - `sync-versions.mjs` - Version synchronization script

- **semantic-release/** - Semantic release templates
  - `release.config.ts` - Semantic release configuration
  - `semantic-release.yml` - GitHub Actions workflow

- **typescript/** - TypeScript configuration
  - `tsconfig.json` - TypeScript configuration

- **vscode/** - VS Code workspace templates
  - `vscode-extensions.json` - Recommended extensions
  - `vscode-settings.json` - Workspace settings

- **workspace/** - Monorepo workspace templates
  - `pnpm-workspace.yaml` - PNPM workspace configuration
  - `turbo.json` - Turborepo configuration

## Function Mapping

Each namespace corresponds to specific functions in `start.sh`:

- `aws/` ← `create_aws_deployment_workflow()`
- `config/` ← `setup_react_router_web()` (for app-specific configs)
- `env/` ← `create_env_template()`
- `eslint/` ← `setup_eslint_package()`
- `infra/` ← `setup_infra_package()`
- `prettier/` ← `setup_prettier_package()`
- `project/` ← `create_project_readme()`
- `react-router/` ← `setup_react_router_web()`
- `scripts/` ← `setup_scripts_package()`, `setup_scripts_readme()`
- `semantic-release/` ← `setup_semantic_release()`
- `typescript/` ← `setup_typescript()`
- `vscode/` ← `setup_vscode_workspace()`
- `workspace/` ← `create_workspace_structure()`