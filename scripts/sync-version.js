#!/usr/bin/env node
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const rootDir = join(__dirname, '..');

// Read package.json
const packagePath = join(rootDir, 'package.json');
const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));
const version = packageJson.version;

// Read moon.mod.json
const moonModPath = join(rootDir, 'moon.mod.json');
const moonModJson = JSON.parse(readFileSync(moonModPath, 'utf8'));

// Update version
moonModJson.version = version;

// Write back
writeFileSync(moonModPath, JSON.stringify(moonModJson, null, 2) + '\n');

console.log(`✅ Synced version to ${version}`);
console.log(`   - package.json: ${version}`);
console.log(`   - moon.mod.json: ${version}`);
