#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// 루트 package.json에서 버전 읽기
const rootPackagePath = path.join(__dirname, '..', '..', 'package.json');
const rootPackage = JSON.parse(fs.readFileSync(rootPackagePath, 'utf8'));
const rootVersion = rootPackage.version;

console.log(`Syncing all packages to version: ${rootVersion}`);

// packages 디렉토리의 모든 서브패키지 찾기
const packagesDir = path.join(__dirname, '..');
const packages = fs.readdirSync(packagesDir);

packages.forEach(packageName => {
  const packagePath = path.join(packagesDir, packageName, 'package.json');

  if (fs.existsSync(packagePath) && packageName !== 'scripts') {
    const packageJson = JSON.parse(fs.readFileSync(packagePath, 'utf8'));
    const oldVersion = packageJson.version;
    packageJson.version = rootVersion;

    fs.writeFileSync(packagePath, JSON.stringify(packageJson, null, 2) + '\n');
    console.log(`Updated ${packageJson.name}: ${oldVersion} → ${rootVersion}`);
  }
});

console.log('Version sync completed!');