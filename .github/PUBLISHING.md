# npm Trusted Publishing Setup Guide

このドキュメントでは、GitHub ReleaseをトリガーにしてOIDC Trusted Publishingを使用してnpmに自動公開するための設定手順を説明します。

## 概要

`publish.yaml`ワークフローは以下の処理を実行します：

1. **GitHubリリース作成時にトリガー** - Release published イベント
2. **バージョン確認** - タグとpackage.jsonの一致を検証
3. **パッケージビルド** - `pnpm run build`を実行
4. **npm公開** - Trusted Publishing (OIDC) で自動認証し `npm publish`を実行
5. **プロヴェナンス生成** - パッケージ由来を証明するメタデータを自動生成

## セットアップ手順

### 1. npmでTrusted Publisherを登録

**npmjs.comで以下の手順を実施してください：**

1. [npmjs.com](https://www.npmjs.com/)にログイン
2. パッケージページにアクセス: https://www.npmjs.com/package/yyjj
3. **Settings** タブを開く
4. **Publishing** セクション → **Trusted Publishers** を選択
5. **GitHub Actions** を選択し、以下を入力：
   - **Organization:** `f4ah6o`
   - **Repository:** `yyjj.mbt`
   - **Workflow file name:** `.github/workflows/publish.yaml`
6. **Save** をクリック

### 2. GitHub リポジトリ確認

ワークフロー設定は既に実装済みです。確認項目：

- ✅ `.github/workflows/publish.yaml` が存在
- ✅ `permissions.id-token: write` が設定済み
- ✅ Release トリガーが設定済み

### 3. 初めての公開テスト

まず、テスト的にリリースを作成して動作確認してください：

**GitHub上で：**

1. リポジトリの **Releases** ページを開く
2. **Create a new release** をクリック
3. **Choose a tag** → 新規タグを作成（例：`v0.1.1`）
4. **Release title:** `v0.1.1`
5. **Publish release** をクリック

**package.jsonも更新必須：**

公開前に、package.jsonのバージョンを合わせてください：

```json
{
  "version": "0.1.1"
}
```

ワークフローはバージョンの一致を確認します。

### 4. ワークフロー実行の監視

1. リポジトリの **Actions** タブを開く
2. **Publish to npm** ワークフローの実行状況を確認
3. 各ステップのログを確認

## トラブルシューティング

### ❌ "Trusted publisher not found" エラー

**原因：** npmでTrusted Publisherが正しく登録されていない

**対処：**
- npmjs.com → パッケージ設定 → Trusted Publishers を確認
- Organization, Repository, Workflow file name が正確に一致しているか確認
- 設定後、数分待ってからリトライ

### ❌ "Version mismatch" エラー

**原因：** リリースタグとpackage.jsonのバージョンが一致していない

**対処：**

```bash
# 例：v0.1.2 でリリースする場合

# 1. package.jsonを更新
{
  "version": "0.1.2"
}

# 2. コミット
git commit -am "chore: bump version to 0.1.2"

# 3. タグを作成してプッシュ
git tag v0.1.2
git push origin v0.1.2

# 4. GitHubでリリースを作成
```

### ❌ "npm publish" が失敗する

**原因：**
1. Node.js バージョンが古い（24以上が必須）
2. npm バージョンが古い（11.5.1以上が必須）
3. Trusted Publisher 設定の問題

**確認：**
```bash
node --version  # v24.0.0 以上
npm --version   # 11.5.1 以上
```

## 公開ワークフロー（本番運用）

### 新規バージョンリリースの手順

```bash
# 1. ローカルでテスト
pnpm run build
pnpm run test

# 2. package.jsonとmoon.mod.jsonをバージョンアップ
vim package.json      # "version": "0.1.1" → "0.1.2"
vim moon.mod.json     # "version": "0.1.0" → "0.1.2"

# 3. コミット
git add package.json moon.mod.json
git commit -m "chore(release): bump version to 0.1.2"

# 4. タグ作成とプッシュ
git tag v0.1.2
git push
git push origin v0.1.2

# 5. GitHubでリリースを作成
#    → ワークフローが自動的に実行される
#    → npm に自動公開される
```

## セキュリティ機能

### OIDC Trusted Publishing の利点

✅ **短命トークン** - 各公開で生成される一時的なトークン（長く保存されない）
✅ **トークン不要** - npm_token を Secret として保存する必要がない
✅ **証跡追跡可能** - GitHub Actions の実行ログと紐付け
✅ **プロヴェナンス自動生成** - パッケージ由来を証明するメタデータ

### プロヴェナンス検証

npm レジストリ上でパッケージのプロヴェナンスを検証：

```bash
npm view yyjj@0.1.2 _integrity
npm view yyjj@0.1.2 _signature
```

## リファレンス

- [npm Trusted Publishing Documentation](https://docs.npmjs.com/trusted-publishers/)
- [GitHub Actions OIDC Token Provider](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [npm CLI Publish Documentation](https://docs.npmjs.com/cli/v11/commands/npm-publish)
