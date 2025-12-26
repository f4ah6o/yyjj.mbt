#!/usr/bin/env node
import { execSync } from 'child_process';
import { readFileSync } from 'fs';
import readline from 'readline';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

async function ask(question) {
  return new Promise(resolve => {
    rl.question(question, answer => resolve(answer));
  });
}

async function main() {
  const packageJson = JSON.parse(readFileSync('package.json', 'utf8'));
  const currentVersion = packageJson.version;

  console.log(`Current version: ${currentVersion}`);
  console.log('');

  const newVersion = await ask('Enter new version (e.g., 2025.12.1): ');

  if (!newVersion) {
    console.log('❌ No version provided');
    rl.close();
    return;
  }

  console.log('');
  console.log('This will:');
  console.log(`  1. Update package.json to ${newVersion}`);
  console.log(`  2. Update moon.mod.json to ${newVersion}`);
  console.log(`  3. Create git commit`);
  console.log(`  4. Create git tag v${newVersion}`);
  console.log('');

  const confirm = await ask('Continue? (y/N): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('❌ Cancelled');
    rl.close();
    return;
  }

  try {
    // Run pnpm version
    execSync(`pnpm version ${newVersion} --no-git-tag-version`, { stdio: 'inherit' });

    // Sync moon.mod.json
    execSync('node scripts/sync-version.js', { stdio: 'inherit' });

    // Git commit and tag
    execSync(`git add package.json moon.mod.json`, { stdio: 'inherit' });
    execSync(`git commit -m "chore(release): bump version to ${newVersion}"`, { stdio: 'inherit' });
    execSync(`git tag v${newVersion}`, { stdio: 'inherit' });

    console.log('');
    console.log('✅ Release prepared!');
    console.log('');
    console.log('Next steps:');
    console.log('  1. git push');
    console.log(`  2. git push origin v${newVersion}`);
    console.log('  3. Create GitHub Release');

  } catch (error) {
    console.error('❌ Release failed:', error.message);
  }

  rl.close();
}

main();
