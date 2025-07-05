#!/usr/bin/env node

import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function runCommand(command, cwd) {
  try {
    execSync(command, {
      cwd,
      stdio: 'inherit',
      encoding: 'utf8'
    });
  } catch (error) {
    console.error(`Error running command: ${command}`);
    process.exit(1);
  }
}

const projectRoot = path.resolve(__dirname, '../..');
const targetDir = process.argv[2];

if (!targetDir) {
  console.error('Usage: node format.mjs <app-directory>');
  process.exit(1);
}

const appPath = path.resolve(projectRoot, targetDir);

console.log(`Running format in ${appPath}`);

runCommand('tsc', appPath);
runCommand('prettier --write "**/*.{ts,tsx,cjs,mjs,json,html,css,js,jsx}" --cache --config prettier.config.mjs', appPath);
runCommand('eslint --fix --cache --cache-location ./node_modules/.cache/eslint .', appPath);

console.log('Format completed successfully!');