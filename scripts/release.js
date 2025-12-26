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

function runCommand(cmd, description) {
  try {
    console.log(`\n▸ ${description}`);
    execSync(cmd, { stdio: 'inherit' });
    return true;
  } catch (error) {
    console.error(`❌ ${description} failed:`, error.message);
    return false;
  }
}

async function main() {
  const packageJson = JSON.parse(readFileSync('package.json', 'utf8'));
  const currentVersion = packageJson.version;

  console.log(`\n📦 Current version: ${currentVersion}`);
  console.log('');

  const newVersion = await ask('Enter new version (e.g., 2025.12.1): ');

  if (!newVersion) {
    console.log('❌ No version provided');
    rl.close();
    return;
  }

  console.log('');
  console.log('Release plan:');
  console.log(`  1. Update package.json to ${newVersion}`);
  console.log(`  2. Update moon.mod.json to ${newVersion}`);
  console.log(`  3. Create git commit and tag v${newVersion}`);
  console.log(`  4. Push to GitHub (commit & tag)`);
  console.log(`  5. Create GitHub Release (triggers Actions)`);
  console.log(`  6. GitHub Actions publishes to npm`);
  console.log('');

  const confirm = await ask('Continue? (y/N): ');

  if (confirm.toLowerCase() !== 'y') {
    console.log('❌ Cancelled');
    rl.close();
    return;
  }

  try {
    // 1. Update package.json
    if (!runCommand(`pnpm version ${newVersion} --no-git-tag-version`, 'Updating package.json')) {
      throw new Error('Failed to update package.json');
    }

    // 2. Sync moon.mod.json
    if (!runCommand('node scripts/sync-version.js', 'Syncing moon.mod.json')) {
      throw new Error('Failed to sync moon.mod.json');
    }

    // 3. Git commit and tag
    if (!runCommand(
      `git add package.json moon.mod.json && git commit -m "chore(release): bump version to ${newVersion}"`,
      'Creating git commit'
    )) {
      throw new Error('Failed to create git commit');
    }

    if (!runCommand(`git tag v${newVersion}`, 'Creating git tag v' + newVersion)) {
      throw new Error('Failed to create git tag');
    }

    // 4. Push to GitHub
    if (!runCommand('git push', 'Pushing to GitHub')) {
      throw new Error('Failed to push commits');
    }

    if (!runCommand(`git push origin v${newVersion}`, 'Pushing git tag')) {
      throw new Error('Failed to push git tag');
    }

    // 5. Create GitHub Release
    const releaseCreated = runCommand(
      `gh release create v${newVersion} --generate-notes`,
      'Creating GitHub Release'
    );

    if (!releaseCreated) {
      console.log('');
      console.log('⚠️  GitHub Release creation failed (gh CLI might not be installed)');
      console.log(`    Please create release manually: https://github.com/f4ah6o/yyjj.mbt/releases/new?tag=v${newVersion}`);
      console.log('');
      console.log('    Once the release is published, GitHub Actions will automatically run.');
      rl.close();
      return;
    }

    console.log('');
    console.log('✅ Release complete!');
    console.log('');
    console.log('What happens next:');
    console.log(`  • GitHub Actions (publish.yaml) triggers on release published event`);
    console.log(`  • Package builds and tests run`);
    console.log(`  • npm publishes to registry with OIDC (Trusted Publishing)`);
    console.log(`  • Provenance attestation automatically generated`);
    console.log('');
    console.log(`Release URL: https://github.com/f4ah6o/yyjj.mbt/releases/tag/v${newVersion}`);
    console.log(`npm package: https://www.npmjs.com/package/yyjj/v/${newVersion}`);

  } catch (error) {
    console.error('\n❌ Release failed:', error.message);
    console.log('\nRollback suggestions:');
    console.log(`  git tag -d v${newVersion}  # Delete local tag`);
    console.log(`  git reset --soft HEAD~1     # Undo last commit`);
  }

  rl.close();
}

main();
