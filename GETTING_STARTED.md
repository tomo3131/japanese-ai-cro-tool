# 開発開始ガイド

## 🎉 おめでとうございます！

**Japanese AI CRO Tool**の要件定義が完了しました。このガイドに従って、スムーズに開発を開始できます。

---

## 📋 要件定義の完成度

### ✅ 完了した項目（100%）

1. **ビジネス要件**
   - ターゲット顧客: LP特化、100万PV以上
   - 価格設定: 3プラン（98,000円〜398,000円）
   - KPI: MRR、チャーン率、NPS

2. **技術要件**
   - トラッキングSDK: 実装方式、Anti-flicker
   - パーソナライゼーション配信: ESR + CSRハイブリッド
   - データモデル: 完全なPostgreSQLスキーマ
   - A/Bテスト分配: MurmurHash3

3. **UI/UX設計**
   - 35画面の詳細設計
   - ワイヤーフレーム
   - デザインシステム

4. **日本語特化機能**
   - 形態素解析: MeCab + NEologd
   - 敬語レベル: 3段階
   - 商習慣対応: 8項目

5. **AI機能**
   - LLM: Gemini 2.0 Flash
   - 仮説生成: JSON出力形式
   - 統計分析: 頻度論+ベイズ

6. **運用・保守戦略**
   - 監視: 15項目
   - ログ管理: 5段階
   - バックアップ: 自動化

7. **セキュリティ**
   - 認証: Supabase Auth + 2FA
   - 暗号化: TLS 1.3、AES-256
   - RLS: Row Level Security

8. **テスト戦略**
   - テストピラミッド: 70/20/10
   - カバレッジ: 80%
   - E2E: Playwright

9. **データベーススキーマ**
   - 完全なSQL定義
   - インデックス設計
   - RLSポリシー

10. **API仕様**
    - OpenAPI 3.0仕様書
    - 全エンドポイント定義

11. **エラーハンドリング**
    - エラーコード体系
    - ユーザー向けメッセージ

12. **パフォーマンス最適化**
    - Next.js設定
    - 画像・フォント最適化
    - キャッシュ戦略

---

## 🚀 開発開始前の準備（推奨: 1週間）

### ステップ1: 開発環境のセットアップ（2日）

#### 1.1 リポジトリのクローン

```bash
git clone https://github.com/tomo3131/japanese-ai-cro-tool.git
cd japanese-ai-cro-tool
```

#### 1.2 Node.jsとパッケージマネージャーのインストール

```bash
# Node.js 20.x をインストール
nvm install 20
nvm use 20

# pnpmをインストール
npm install -g pnpm
```

#### 1.3 依存関係のインストール

```bash
# プロジェクト初期化
pnpm init

# Next.js + TypeScript
pnpm add next@latest react@latest react-dom@latest
pnpm add -D typescript @types/react @types/node

# Tailwind CSS
pnpm add -D tailwindcss postcss autoprefixer
npx tailwindcss init -p

# Supabase
pnpm add @supabase/supabase-js @supabase/auth-helpers-nextjs

# フォーム・バリデーション
pnpm add react-hook-form zod @hookform/resolvers

# UI コンポーネント
pnpm add @radix-ui/react-dialog @radix-ui/react-dropdown-menu @radix-ui/react-select
pnpm add lucide-react

# 日本語処理
pnpm add kuromoji

# AI
pnpm add @google/generative-ai

# 開発ツール
pnpm add -D eslint prettier eslint-config-next @typescript-eslint/parser @typescript-eslint/eslint-plugin
pnpm add -D vitest @vitejs/plugin-react jsdom @testing-library/react @testing-library/jest-dom
pnpm add -D playwright @playwright/test
```

#### 1.4 環境変数の設定

```bash
# .env.local を作成
cp .env.example .env.local

# 以下の環境変数を設定
# NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
# NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
# SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
# GEMINI_API_KEY=your_gemini_api_key
# REDIS_URL=your_redis_url
```

#### 1.5 ESLint・Prettierの設定

```bash
# .eslintrc.json を作成
cat > .eslintrc.json << 'EOF'
{
  "extends": ["next/core-web-vitals", "prettier"],
  "rules": {
    "@typescript-eslint/no-unused-vars": "error",
    "@typescript-eslint/no-explicit-any": "warn"
  }
}
EOF

# .prettierrc を作成
cat > .prettierrc << 'EOF'
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "printWidth": 100
}
EOF
```

---

### ステップ2: Supabaseプロジェクトのセットアップ（1日）

#### 2.1 Supabaseプロジェクトの作成

1. https://supabase.com にアクセス
2. 「New Project」をクリック
3. プロジェクト名: `japanese-ai-cro-tool`
4. データベースパスワードを設定
5. リージョン: `Northeast Asia (Tokyo)`

#### 2.2 データベーススキーマの適用

```bash
# Supabase CLIをインストール
npm install -g supabase

# ログイン
supabase login

# プロジェクトにリンク
supabase link --project-ref your_project_ref

# スキーマを適用
supabase db push --db-url "postgresql://postgres:[password]@db.[project-ref].supabase.co:5432/postgres" < database/schema.sql
```

または、Supabase Studioから手動で実行：
1. https://app.supabase.com/project/[your-project]/sql/new
2. `database/schema.sql` の内容をコピー&ペースト
3. 「Run」をクリック

#### 2.3 Row Level Security (RLS)の確認

Supabase Studioで各テーブルのRLSが有効になっていることを確認。

---

### ステップ3: CI/CDパイプラインの構築（1日）

#### 3.1 GitHub Actionsの設定

```yaml
# .github/workflows/ci.yml を作成
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '20'
      
      - name: Install pnpm
        uses: pnpm/action-setup@v2
        with:
          version: 8
      
      - name: Install dependencies
        run: pnpm install
      
      - name: Lint
        run: pnpm lint
      
      - name: Type check
        run: pnpm tsc --noEmit
      
      - name: Unit tests
        run: pnpm test
      
      - name: Build
        run: pnpm build
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage-final.json
```

#### 3.2 Vercelへのデプロイ設定

1. https://vercel.com にアクセス
2. GitHubリポジトリを連携
3. 環境変数を設定
4. 自動デプロイを有効化

---

### ステップ4: 開発ドキュメントの整備（1日）

#### 4.1 README.mdの更新

プロジェクトの概要、セットアップ手順、開発ガイドを記載。

#### 4.2 コントリビューションガイドの確認

`CONTRIBUTING.md` を確認し、チームメンバーと共有。

#### 4.3 Notionワークスペースの作成

技術ドキュメント、議事録、決定事項を管理。

---

## 📅 開発スケジュール（MVP: 3ヶ月）

### フェーズ1: 基盤構築（4週間）

#### Week 1-2: プロジェクト初期設定
- [ ] Next.js + TypeScriptプロジェクト作成
- [ ] Supabase接続確認
- [ ] 認証機能実装（Supabase Auth）
- [ ] 基本的なレイアウト・ナビゲーション

#### Week 3-4: サイト管理
- [ ] サイト一覧・作成・編集・削除
- [ ] トラッキングID発行
- [ ] トラッキングSDKの基本実装

---

### フェーズ2: コア機能（6週間）

#### Week 5-6: パーソナライゼーション（凛）
- [ ] ルール作成UI
- [ ] 条件設定（UTM、デバイス、国）
- [ ] 変更内容設定
- [ ] エッジ配信（Cloudflare Workers）

#### Week 7-8: A/Bテスト（匠）
- [ ] 実験作成UI
- [ ] バリアント設定
- [ ] トラフィック分配
- [ ] 統計分析（頻度論+ベイズ）

#### Week 9-10: ダッシュボード・分析
- [ ] ホームダッシュボード
- [ ] KPI表示
- [ ] チャート・グラフ
- [ ] リアルタイム更新

---

### フェーズ3: AI機能（2週間）

#### Week 11-12: AI仮説生成
- [ ] Gemini API統合
- [ ] 仮説生成ロジック
- [ ] AIインサイト生成
- [ ] 学習データ蓄積

---

### フェーズ4: 日本語特化・最終調整（2週間）

#### Week 13: 日本語特化機能
- [ ] 形態素解析（MeCab/Kuromoji）
- [ ] 敬語レベル調整
- [ ] 商習慣対応
- [ ] 広告プラットフォーム統合

#### Week 14: 最終調整・テスト
- [ ] E2Eテスト
- [ ] パフォーマンス最適化
- [ ] セキュリティ監査
- [ ] ドキュメント整備

---

## 👥 推奨チーム構成

### 最小構成（3-4名）

1. **フルスタックエンジニア（リード）**
   - Next.js、TypeScript、Supabase経験
   - アーキテクチャ設計
   - コードレビュー

2. **フロントエンドエンジニア**
   - React、Tailwind CSS
   - UI/UXデザイン実装
   - パフォーマンス最適化

3. **バックエンドエンジニア**
   - PostgreSQL、Redis
   - API設計・実装
   - Cloudflare Workers

4. **QAエンジニア（兼任可）**
   - テスト設計・実装
   - E2Eテスト（Playwright）
   - セキュリティテスト

---

## 🎯 開発開始のチェックリスト

### 環境
- [ ] Node.js 20.x インストール
- [ ] pnpm インストール
- [ ] Git設定完了
- [ ] エディタ（VS Code推奨）セットアップ

### Supabase
- [ ] プロジェクト作成
- [ ] データベーススキーマ適用
- [ ] RLS有効化確認
- [ ] 環境変数設定

### CI/CD
- [ ] GitHub Actions設定
- [ ] Vercel連携
- [ ] 自動テスト実行確認

### ドキュメント
- [ ] README.md確認
- [ ] CONTRIBUTING.md確認
- [ ] 要件定義書レビュー
- [ ] Notionワークスペース作成

### チーム
- [ ] チームメンバー招待
- [ ] キックオフミーティング
- [ ] スプリント計画
- [ ] コミュニケーションツール設定（Slack等）

---

## 📚 参考リソース

### ドキュメント
- [Next.js Documentation](https://nextjs.org/docs)
- [Supabase Documentation](https://supabase.com/docs)
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [Gemini API Documentation](https://ai.google.dev/docs)

### チュートリアル
- [Next.js + Supabase Tutorial](https://supabase.com/docs/guides/getting-started/tutorials/with-nextjs)
- [TypeScript Best Practices](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)

### コミュニティ
- [Next.js Discord](https://nextjs.org/discord)
- [Supabase Discord](https://discord.supabase.com/)

---

## 🎊 次のステップ

1. **今すぐ**: このガイドに従って環境をセットアップ
2. **1週間後**: Issue #1（プロジェクト初期設定）から開発開始
3. **3ヶ月後**: MVP完成、ベータテスト開始

**成功を祈っています！** 🚀

---

## 💬 サポート

質問や問題が発生した場合：
1. GitHub Issuesで質問
2. ドキュメントを確認
3. チームメンバーに相談

**Happy Coding!** 💻

