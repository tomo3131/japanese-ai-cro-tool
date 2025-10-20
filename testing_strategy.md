# テスト戦略詳細設計書

## 8. テスト戦略

### 8.1 テストピラミッド

```
        /\
       /  \
      / E2E \         10% - エンドツーエンドテスト
     /______\
    /        \
   /Integration\     20% - 統合テスト
  /____________\
 /              \
/  Unit Tests    \   70% - ユニットテスト
/________________\
```

**目標カバレッジ**:
- ユニットテスト: 80%以上
- 統合テスト: 60%以上
- E2Eテスト: 主要フロー100%

---

### 8.2 ユニットテスト

#### テストフレームワーク

**採用**: Vitest

**選定理由**:
- Viteベースで高速
- Jest互換のAPI
- TypeScript完全サポート
- ESM対応

**設定**:
```javascript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'dist/',
        '**/*.test.ts',
        '**/*.spec.ts'
      ],
      threshold: {
        lines: 80,
        functions: 80,
        branches: 75,
        statements: 80
      }
    }
  }
});
```

#### テスト例

**1. ユーティリティ関数のテスト**:

```typescript
// utils/personalization.test.ts
import { describe, it, expect } from 'vitest';
import { detectPolitenessLevel, casualToPolite } from './personalization';

describe('detectPolitenessLevel', () => {
  it('金融業界は尊敬語レベルを返す', () => {
    const context = {
      industry: 'finance',
      targetAge: 'general',
      pageType: 'product'
    };
    
    expect(detectPolitenessLevel(context)).toBe(3);
  });
  
  it('若年層向けはカジュアルレベルを返す', () => {
    const context = {
      industry: 'ec',
      targetAge: 'young',
      pageType: 'campaign'
    };
    
    expect(detectPolitenessLevel(context)).toBe(1);
  });
  
  it('デフォルトは丁寧語レベルを返す', () => {
    const context = {
      industry: 'ec',
      targetAge: 'general',
      pageType: 'product'
    };
    
    expect(detectPolitenessLevel(context)).toBe(2);
  });
});

describe('casualToPolite', () => {
  it('カジュアルな文章を丁寧語に変換する', () => {
    const input = '今すぐ始めよう。簡単だ。';
    const expected = '今すぐ始めましょう。簡単です。';
    
    expect(casualToPolite(input)).toBe(expected);
  });
  
  it('すでに丁寧語の場合は変更しない', () => {
    const input = '今すぐ始めましょう。';
    
    expect(casualToPolite(input)).toBe(input);
  });
});
```

**2. 統計関数のテスト**:

```typescript
// utils/statistics.test.ts
import { describe, it, expect } from 'vitest';
import { calculateZTest, calculateConfidenceInterval } from './statistics';

describe('calculateZTest', () => {
  it('統計的有意差がある場合、significantがtrueになる', () => {
    const controlData = {
      visitors: 5000,
      conversions: 100
    };
    
    const variantData = {
      visitors: 5000,
      conversions: 150
    };
    
    const result = calculateZTest(controlData, variantData);
    
    expect(result.significant).toBe(true);
    expect(result.p_value).toBeLessThan(0.05);
  });
  
  it('統計的有意差がない場合、significantがfalseになる', () => {
    const controlData = {
      visitors: 100,
      conversions: 10
    };
    
    const variantData = {
      visitors: 100,
      conversions: 11
    };
    
    const result = calculateZTest(controlData, variantData);
    
    expect(result.significant).toBe(false);
    expect(result.p_value).toBeGreaterThan(0.05);
  });
});

describe('calculateConfidenceInterval', () => {
  it('95%信頼区間を正しく計算する', () => {
    const result = calculateConfidenceInterval(100, 4000, 0.95);
    
    expect(result.center).toBeCloseTo(0.025, 3);
    expect(result.lower).toBeCloseTo(0.0205, 3);
    expect(result.upper).toBeCloseTo(0.0295, 3);
  });
});
```

**3. React コンポーネントのテスト**:

```typescript
// components/ExperimentCard.test.tsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { ExperimentCard } from './ExperimentCard';

describe('ExperimentCard', () => {
  const mockExperiment = {
    id: 'exp_123',
    name: 'CTAボタンの色テスト',
    status: 'running',
    improvement: 20.1,
    significant: true
  };
  
  it('実験名を表示する', () => {
    render(<ExperimentCard experiment={mockExperiment} />);
    
    expect(screen.getByText('CTAボタンの色テスト')).toBeInTheDocument();
  });
  
  it('改善率を表示する', () => {
    render(<ExperimentCard experiment={mockExperiment} />);
    
    expect(screen.getByText('+20.1%')).toBeInTheDocument();
  });
  
  it('統計的有意差がある場合、バッジを表示する', () => {
    render(<ExperimentCard experiment={mockExperiment} />);
    
    expect(screen.getByText('統計的有意差あり')).toBeInTheDocument();
  });
  
  it('実行中の場合、ステータスバッジを表示する', () => {
    render(<ExperimentCard experiment={mockExperiment} />);
    
    expect(screen.getByText('実行中')).toBeInTheDocument();
  });
});
```

---

### 8.3 統合テスト

#### テストフレームワーク

**採用**: Vitest + Supertest（API）

**API統合テスト例**:

```typescript
// api/experiments.test.ts
import { describe, it, expect, beforeAll, afterAll } from 'vitest';
import request from 'supertest';
import { app } from '../app';
import { createTestUser, cleanupTestData } from './test-helpers';

describe('Experiments API', () => {
  let authToken: string;
  let organizationId: string;
  
  beforeAll(async () => {
    // テストユーザーを作成
    const { token, orgId } = await createTestUser();
    authToken = token;
    organizationId = orgId;
  });
  
  afterAll(async () => {
    // テストデータをクリーンアップ
    await cleanupTestData(organizationId);
  });
  
  describe('POST /api/experiments', () => {
    it('新しい実験を作成できる', async () => {
      const experimentData = {
        name: 'CTAボタンの色テスト',
        hypothesis: '緑色のボタンは青色よりもクリック率が高い',
        urlPattern: '/lp/campaign',
        variants: [
          { name: 'コントロール', changes: {} },
          { name: 'バリアント', changes: { buttonColor: 'green' } }
        ]
      };
      
      const response = await request(app)
        .post('/api/experiments')
        .set('Authorization', `Bearer ${authToken}`)
        .send(experimentData)
        .expect(201);
      
      expect(response.body).toHaveProperty('id');
      expect(response.body.name).toBe(experimentData.name);
      expect(response.body.status).toBe('draft');
    });
    
    it('認証なしでは401エラーを返す', async () => {
      const response = await request(app)
        .post('/api/experiments')
        .send({})
        .expect(401);
      
      expect(response.body.error).toBe('認証が必要です');
    });
    
    it('必須フィールドがない場合は400エラーを返す', async () => {
      const response = await request(app)
        .post('/api/experiments')
        .set('Authorization', `Bearer ${authToken}`)
        .send({ name: 'テスト' }) // hypothesisがない
        .expect(400);
      
      expect(response.body.error).toContain('hypothesis');
    });
  });
  
  describe('GET /api/experiments/:id', () => {
    it('実験の詳細を取得できる', async () => {
      // まず実験を作成
      const createResponse = await request(app)
        .post('/api/experiments')
        .set('Authorization', `Bearer ${authToken}`)
        .send({
          name: 'テスト実験',
          hypothesis: 'テスト仮説',
          urlPattern: '/test'
        });
      
      const experimentId = createResponse.body.id;
      
      // 詳細を取得
      const response = await request(app)
        .get(`/api/experiments/${experimentId}`)
        .set('Authorization', `Bearer ${authToken}`)
        .expect(200);
      
      expect(response.body.id).toBe(experimentId);
      expect(response.body.name).toBe('テスト実験');
    });
    
    it('存在しない実験IDの場合は404エラーを返す', async () => {
      await request(app)
        .get('/api/experiments/nonexistent_id')
        .set('Authorization', `Bearer ${authToken}`)
        .expect(404);
    });
  });
});
```

**データベース統合テスト**:

```typescript
// database/experiments.test.ts
import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { createClient } from '@supabase/supabase-js';
import { createExperiment, getExperiment, updateExperiment } from './experiments';

const supabase = createClient(
  process.env.SUPABASE_TEST_URL!,
  process.env.SUPABASE_TEST_KEY!
);

describe('Experiment Database Operations', () => {
  let testOrgId: string;
  
  beforeEach(async () => {
    // テスト用組織を作成
    const { data } = await supabase
      .from('organizations')
      .insert({ name: 'Test Org' })
      .select()
      .single();
    
    testOrgId = data.id;
  });
  
  afterEach(async () => {
    // テストデータを削除
    await supabase
      .from('organizations')
      .delete()
      .eq('id', testOrgId);
  });
  
  it('実験を作成できる', async () => {
    const experiment = await createExperiment({
      organizationId: testOrgId,
      name: 'テスト実験',
      hypothesis: 'テスト仮説'
    });
    
    expect(experiment).toHaveProperty('id');
    expect(experiment.name).toBe('テスト実験');
  });
  
  it('実験を取得できる', async () => {
    const created = await createExperiment({
      organizationId: testOrgId,
      name: 'テスト実験',
      hypothesis: 'テスト仮説'
    });
    
    const fetched = await getExperiment(created.id);
    
    expect(fetched.id).toBe(created.id);
    expect(fetched.name).toBe('テスト実験');
  });
  
  it('実験を更新できる', async () => {
    const created = await createExperiment({
      organizationId: testOrgId,
      name: 'テスト実験',
      hypothesis: 'テスト仮説'
    });
    
    const updated = await updateExperiment(created.id, {
      status: 'running'
    });
    
    expect(updated.status).toBe('running');
  });
});
```

---

### 8.4 E2Eテスト

#### テストフレームワーク

**採用**: Playwright

**選定理由**:
- クロスブラウザ対応（Chrome、Firefox、Safari）
- 高速で安定
- 自動待機機能
- スクリーンショット・動画録画

**設定**:

```typescript
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html'],
    ['junit', { outputFile: 'test-results/junit.xml' }]
  ],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure'
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] }
    },
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] }
    }
  ],
  webServer: {
    command: 'pnpm dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI
  }
});
```

#### E2Eテスト例

**1. ユーザー登録〜初回ルール作成**:

```typescript
// e2e/onboarding.spec.ts
import { test, expect } from '@playwright/test';

test.describe('オンボーディング', () => {
  test('新規ユーザーが登録から初回ルール作成まで完了できる', async ({ page }) => {
    // ランディングページにアクセス
    await page.goto('/');
    
    // 無料トライアルボタンをクリック
    await page.click('text=無料トライアル開始');
    
    // サインアップフォームに入力
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'SecurePass123!');
    await page.click('button[type="submit"]');
    
    // メール確認画面が表示されることを確認
    await expect(page.locator('text=確認メールを送信しました')).toBeVisible();
    
    // テスト用: メール確認をスキップ（実際の環境ではメールのリンクをクリック）
    await page.goto('/auth/verify?token=test_token');
    
    // ウェルカム画面
    await expect(page.locator('h1:has-text("ようこそ")')).toBeVisible();
    await page.click('text=始める');
    
    // サイト登録
    await page.fill('input[name="domain"]', 'example.com');
    await page.fill('input[name="siteName"]', 'テストサイト');
    await page.click('text=次へ');
    
    // トラッキングコード設置
    await expect(page.locator('code')).toBeVisible();
    await page.click('text=コピー');
    
    // テスト用: トラッキング検証をスキップ
    await page.click('text=スキップ');
    
    // 初回ルール作成
    await page.click('text=広告経由の訪問者に特別オファーを表示');
    
    // ビジュアルエディタ
    await page.fill('textarea[name="headline"]', '特別キャンペーン実施中！');
    await page.click('text=プレビュー');
    
    // プレビューを確認
    await expect(page.locator('text=特別キャンペーン実施中！')).toBeVisible();
    
    // 公開
    await page.click('text=公開');
    
    // 完了画面
    await expect(page.locator('text=ルールを公開しました')).toBeVisible();
    
    // ダッシュボードに遷移
    await page.click('text=ダッシュボードへ');
    
    // ダッシュボードが表示されることを確認
    await expect(page.locator('h1:has-text("ダッシュボード")')).toBeVisible();
  });
});
```

**2. A/Bテスト作成〜結果確認**:

```typescript
// e2e/ab-test.spec.ts
import { test, expect } from '@playwright/test';

test.describe('A/Bテスト', () => {
  test.beforeEach(async ({ page }) => {
    // ログイン
    await page.goto('/login');
    await page.fill('input[name="email"]', 'test@example.com');
    await page.fill('input[name="password"]', 'SecurePass123!');
    await page.click('button[type="submit"]');
    
    // ダッシュボードに遷移
    await expect(page).toHaveURL('/dashboard');
  });
  
  test('A/Bテストを作成して実行できる', async ({ page }) => {
    // A/Bテストページに移動
    await page.click('text=A/Bテスト');
    
    // 新規実験作成
    await page.click('text=新規実験作成');
    
    // ステップ1: 基本設定
    await page.fill('input[name="name"]', 'CTAボタンの色テスト');
    await page.fill('textarea[name="hypothesis"]', '緑色のボタンは青色よりもクリック率が高い');
    await page.fill('input[name="url"]', 'https://example.com/lp/campaign');
    await page.click('text=次へ');
    
    // ステップ2: バリアント設定
    await page.click('text=バリアントBを編集');
    await page.click('button.cta-button'); // CTAボタンを選択
    await page.click('text=色を変更');
    await page.click('div[data-color="green"]'); // 緑色を選択
    await page.click('text=次へ');
    
    // ステップ3: トラフィック設定
    await page.fill('input[name="trafficAllocation"]', '50'); // 50/50
    await page.click('text=次へ');
    
    // ステップ4: プレビュー
    await expect(page.locator('text=コントロール')).toBeVisible();
    await expect(page.locator('text=バリアント')).toBeVisible();
    await page.click('text=次へ');
    
    // ステップ5: 確認
    await page.click('text=実験を開始');
    
    // 実験詳細ページに遷移
    await expect(page.locator('h1:has-text("CTAボタンの色テスト")')).toBeVisible();
    await expect(page.locator('text=実行中')).toBeVisible();
  });
  
  test('実験結果を確認できる', async ({ page }) => {
    // テスト用: 完了した実験を作成
    // （実際の環境では、データを投入して統計的有意差に達するまで待つ）
    
    // 実験一覧に移動
    await page.goto('/experiments');
    
    // 完了した実験をクリック
    await page.click('text=CTAボタンの色テスト');
    
    // 結果サマリーを確認
    await expect(page.locator('text=改善率')).toBeVisible();
    await expect(page.locator('text=+20.1%')).toBeVisible();
    await expect(page.locator('text=統計的有意差あり')).toBeVisible();
    
    // グラフが表示されることを確認
    await expect(page.locator('canvas')).toBeVisible();
    
    // 勝者を適用
    await page.click('text=勝者を適用');
    
    // 確認ダイアログ
    await page.click('text=適用する');
    
    // 成功メッセージ
    await expect(page.locator('text=バリアントBを全訪問者に適用しました')).toBeVisible();
  });
});
```

**3. パフォーマンステスト**:

```typescript
// e2e/performance.spec.ts
import { test, expect } from '@playwright/test';

test.describe('パフォーマンス', () => {
  test('ダッシュボードのCore Web Vitalsが基準を満たす', async ({ page }) => {
    await page.goto('/dashboard');
    
    // Performance APIからメトリクスを取得
    const metrics = await page.evaluate(() => {
      const navigation = performance.getEntriesByType('navigation')[0] as PerformanceNavigationTiming;
      const paint = performance.getEntriesByType('paint');
      
      return {
        // Largest Contentful Paint
        lcp: paint.find(entry => entry.name === 'largest-contentful-paint')?.startTime || 0,
        // First Input Delay（実際の測定は困難なので、TTIで代用）
        tti: navigation.domInteractive - navigation.fetchStart,
        // Cumulative Layout Shift（簡易版）
        cls: 0 // 実際の測定には専用ライブラリが必要
      };
    });
    
    // LCP: 2.5秒以内
    expect(metrics.lcp).toBeLessThan(2500);
    
    // TTI: 3.8秒以内
    expect(metrics.tti).toBeLessThan(3800);
  });
  
  test('SDKの読み込み時間が1秒以内', async ({ page }) => {
    // SDKを含むページにアクセス
    await page.goto('https://example.com/lp/campaign');
    
    // SDKの読み込み時間を測定
    const sdkLoadTime = await page.evaluate(() => {
      const sdkEntry = performance.getEntriesByName('https://cdn.example.com/sdk.js')[0];
      return sdkEntry ? sdkEntry.duration : 0;
    });
    
    expect(sdkLoadTime).toBeLessThan(1000);
  });
});
```

---

### 8.5 ビジュアルリグレッションテスト

#### ツール

**採用**: Playwright + Percy

**設定**:

```typescript
// e2e/visual.spec.ts
import { test } from '@playwright/test';
import percySnapshot from '@percy/playwright';

test.describe('ビジュアルリグレッション', () => {
  test('ダッシュボードのスクリーンショット', async ({ page }) => {
    await page.goto('/dashboard');
    await percySnapshot(page, 'Dashboard');
  });
  
  test('実験作成フォームのスクリーンショット', async ({ page }) => {
    await page.goto('/experiments/new');
    await percySnapshot(page, 'Experiment Creation Form');
  });
  
  test('モバイル版ダッシュボードのスクリーンショット', async ({ page }) => {
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/dashboard');
    await percySnapshot(page, 'Dashboard - Mobile');
  });
});
```

---

### 8.6 負荷テスト

#### ツール

**採用**: k6

**テストシナリオ**:

```javascript
// load-tests/api-load.js
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

const errorRate = new Rate('errors');

export const options = {
  stages: [
    { duration: '2m', target: 100 },  // 2分かけて100ユーザーまで増加
    { duration: '5m', target: 100 },  // 5分間100ユーザーを維持
    { duration: '2m', target: 200 },  // 2分かけて200ユーザーまで増加
    { duration: '5m', target: 200 },  // 5分間200ユーザーを維持
    { duration: '2m', target: 0 },    // 2分かけて0ユーザーまで減少
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95%のリクエストが500ms以内
    errors: ['rate<0.1'],              // エラー率10%未満
  },
};

const BASE_URL = 'https://api.example.com';
const API_KEY = __ENV.API_KEY;

export default function () {
  // 実験一覧を取得
  const listResponse = http.get(`${BASE_URL}/api/experiments`, {
    headers: {
      'X-API-Key': API_KEY,
    },
  });
  
  check(listResponse, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  }) || errorRate.add(1);
  
  sleep(1);
  
  // 実験詳細を取得
  if (listResponse.json().length > 0) {
    const experimentId = listResponse.json()[0].id;
    
    const detailResponse = http.get(`${BASE_URL}/api/experiments/${experimentId}`, {
      headers: {
        'X-API-Key': API_KEY,
      },
    });
    
    check(detailResponse, {
      'status is 200': (r) => r.status === 200,
      'response time < 300ms': (r) => r.timings.duration < 300,
    }) || errorRate.add(1);
  }
  
  sleep(1);
}
```

**実行**:
```bash
k6 run load-tests/api-load.js
```

**スパイクテスト**:

```javascript
// load-tests/spike-test.js
export const options = {
  stages: [
    { duration: '10s', target: 100 },   // 通常負荷
    { duration: '1m', target: 100 },
    { duration: '10s', target: 1000 },  // 急激にスパイク
    { duration: '3m', target: 1000 },
    { duration: '10s', target: 100 },   // 通常に戻る
    { duration: '3m', target: 100 },
    { duration: '10s', target: 0 },
  ],
};
```

---

### 8.7 セキュリティテスト

#### ツール

**採用**: OWASP ZAP

**自動スキャン**:

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  schedule:
    - cron: '0 2 * * 0' # 毎週日曜日2時
  workflow_dispatch:

jobs:
  zap_scan:
    runs-on: ubuntu-latest
    steps:
      - name: ZAP Scan
        uses: zaproxy/action-full-scan@v0.4.0
        with:
          target: 'https://staging.example.com'
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
```

**手動ペネトレーションテスト**:
- 四半期ごとに外部セキュリティ会社に依頼
- OWASP Top 10の脆弱性を重点的にテスト

---

### 8.8 テスト自動化

#### CI/CDパイプライン

```yaml
# .github/workflows/test.yml
name: Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]

jobs:
  unit-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '22'
      
      - name: Install dependencies
        run: pnpm install
      
      - name: Run unit tests
        run: pnpm test:unit --coverage
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/coverage-final.json

  integration-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '22'
      
      - name: Install dependencies
        run: pnpm install
      
      - name: Run integration tests
        run: pnpm test:integration
        env:
          DATABASE_URL: postgresql://postgres:postgres@localhost:5432/test

  e2e-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '22'
      
      - name: Install dependencies
        run: pnpm install
      
      - name: Install Playwright
        run: pnpm exec playwright install --with-deps
      
      - name: Run E2E tests
        run: pnpm test:e2e
      
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: playwright-report
          path: playwright-report/
```

---

### 8.9 テストデータ管理

#### テストデータ生成

```typescript
// test-helpers/factories.ts
import { faker } from '@faker-js/faker/locale/ja';

export function createTestUser() {
  return {
    email: faker.internet.email(),
    password: 'SecurePass123!',
    name: faker.person.fullName(),
  };
}

export function createTestOrganization() {
  return {
    name: faker.company.name(),
    plan: 'professional',
  };
}

export function createTestExperiment() {
  return {
    name: faker.lorem.sentence(),
    hypothesis: faker.lorem.paragraph(),
    urlPattern: faker.internet.url(),
    variants: [
      { name: 'コントロール', changes: {} },
      { name: 'バリアント', changes: { buttonColor: 'green' } },
    ],
  };
}
```

#### テストデータクリーンアップ

```typescript
// test-helpers/cleanup.ts
export async function cleanupTestData(organizationId: string) {
  // 実験を削除
  await supabase
    .from('experiments')
    .delete()
    .eq('organization_id', organizationId);
  
  // サイトを削除
  await supabase
    .from('sites')
    .delete()
    .eq('organization_id', organizationId);
  
  // 組織を削除
  await supabase
    .from('organizations')
    .delete()
    .eq('id', organizationId);
}
```

---

## まとめ

### テスト戦略の決定事項

#### 8.1 テストピラミッド
- **ユニットテスト**: 70%、カバレッジ80%以上
- **統合テスト**: 20%、カバレッジ60%以上
- **E2Eテスト**: 10%、主要フロー100%

#### 8.2 ユニットテスト
- **フレームワーク**: Vitest
- **対象**: ユーティリティ関数、統計関数、Reactコンポーネント
- **カバレッジ目標**: 80%

#### 8.3 統合テスト
- **フレームワーク**: Vitest + Supertest
- **対象**: API、データベース操作
- **カバレッジ目標**: 60%

#### 8.4 E2Eテスト
- **フレームワーク**: Playwright
- **対象**: オンボーディング、A/Bテスト作成、結果確認
- **ブラウザ**: Chrome、Firefox、Safari、Mobile Chrome

#### 8.5 ビジュアルリグレッション
- **ツール**: Playwright + Percy
- **対象**: ダッシュボード、フォーム、モバイル版

#### 8.6 負荷テスト
- **ツール**: k6
- **シナリオ**: 通常負荷、スパイク
- **基準**: 95%のリクエストが500ms以内、エラー率10%未満

#### 8.7 セキュリティテスト
- **ツール**: OWASP ZAP
- **頻度**: 毎週自動スキャン、四半期ごとにペネトレーションテスト

#### 8.8 テスト自動化
- **CI/CD**: GitHub Actions
- **実行タイミング**: PR作成時、main/developへのpush時
- **カバレッジ**: Codecovで追跡

#### 8.9 テストデータ
- **生成**: Faker.js（日本語ロケール）
- **クリーンアップ**: 各テスト後に自動削除

---

これで全ての要件定義が完了しました！

