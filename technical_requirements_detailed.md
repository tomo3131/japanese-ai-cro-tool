# 技術要件詳細定義書

## 2. 技術要件の詳細化

### 2.1 トラッキングSDKの実装方式

#### 配信方式
**CDN経由配信（推奨）**

**選定理由**:
- グローバルに分散されたエッジサーバーから配信され、低レイテンシ
- 自動キャッシング、DDoS保護
- バージョン管理が容易
- ユーザーサイトのサーバー負荷ゼロ

**採用CDN**: Cloudflare CDN

**配信URL形式**:
```
https://cdn.fibr-jp.ai/sdk/v{version}/fibr-sdk.min.js
```

**フォールバック**:
```html
<script src="https://cdn.fibr-jp.ai/sdk/v1/fibr-sdk.min.js" 
        onerror="this.onerror=null;this.src='https://cdn-backup.fibr-jp.ai/sdk/v1/fibr-sdk.min.js'">
</script>
```

#### 読み込みタイミング

**非同期読み込み（async）+ 早期実行**

**実装方法**:
```html
<!-- ページ<head>内に配置 -->
<script>
  (function() {
    var script = document.createElement('script');
    script.src = 'https://cdn.fibr-jp.ai/sdk/v1/fibr-sdk.min.js';
    script.async = true;
    script.dataset.siteId = 'YOUR_SITE_ID';
    document.head.appendChild(script);
  })();
</script>
```

**選定理由**:
- ページレンダリングをブロックしない
- パーソナライゼーションを早期に適用できる
- Core Web Vitalsに影響を与えない

**ちらつき防止（Anti-flicker）**:
```html
<style id="fibr-antiflicker">
  .fibr-loading { opacity: 0 !important; }
</style>
<script>
  setTimeout(function() {
    document.getElementById('fibr-antiflicker').remove();
  }, 3000); // 3秒後に強制表示
</script>
```

#### バージョニング

**セマンティックバージョニング（Semantic Versioning）**

**形式**: `v{MAJOR}.{MINOR}.{PATCH}`

例:
- `v1.0.0`: 初回リリース
- `v1.1.0`: 新機能追加（後方互換性あり）
- `v1.1.1`: バグ修正
- `v2.0.0`: 破壊的変更

**バージョン指定方法**:
```html
<!-- 固定バージョン（推奨本番環境） -->
<script src="https://cdn.fibr-jp.ai/sdk/v1.2.3/fibr-sdk.min.js"></script>

<!-- 最新マイナーバージョン（自動更新） -->
<script src="https://cdn.fibr-jp.ai/sdk/v1/fibr-sdk.min.js"></script>

<!-- 最新バージョン（非推奨） -->
<script src="https://cdn.fibr-jp.ai/sdk/latest/fibr-sdk.min.js"></script>
```

#### 後方互換性

**旧バージョンサポート期間**: 12ヶ月

**サポートポリシー**:
- 新バージョンリリース後、旧バージョンは12ヶ月間サポート
- サポート終了3ヶ月前に通知
- サポート終了後も配信は継続（セキュリティアップデートなし）

**移行ガイド**:
- 破壊的変更がある場合、移行ガイドを提供
- ダッシュボードで使用中のバージョンを表示
- 非推奨機能の警告をコンソールに出力

#### エラーハンドリング

**スクリプトエラー時の挙動**:

1. **読み込み失敗時**:
   - フォールバックCDNから再試行
   - 失敗した場合、デフォルトコンテンツを表示
   - エラーログをサーバーに送信

2. **実行時エラー**:
   - try-catchで全体をラップ
   - エラーをキャッチしてもページ表示は継続
   - エラー詳細をSentryに送信

**実装例**:
```javascript
window.fibrSDK = window.fibrSDK || {
  init: function(config) {
    try {
      // SDK初期化処理
    } catch (error) {
      console.error('[Fibr SDK] Initialization failed:', error);
      this.reportError(error);
      // デフォルト動作に戻る
    }
  },
  reportError: function(error) {
    // エラーレポート送信
    fetch('https://api.fibr-jp.ai/v1/errors', {
      method: 'POST',
      body: JSON.stringify({
        message: error.message,
        stack: error.stack,
        siteId: this.config.siteId,
        timestamp: Date.now()
      })
    }).catch(function() {
      // エラー送信失敗しても無視
    });
  }
};
```

#### プライバシー

**ファーストパーティCookie使用**

**選定理由**:
- サードパーティCookieはブラウザで制限されている
- GDPR、個人情報保護法に準拠しやすい
- クロスドメイントラッキングは行わない

**Cookie設定**:
```javascript
// 訪問者ID（ファーストパーティCookie）
document.cookie = "fibr_visitor_id=" + visitorId + 
  "; max-age=31536000" +  // 1年間
  "; path=/" + 
  "; SameSite=Lax" +      // CSRF対策
  "; Secure";              // HTTPS必須
```

**保存データ**:
- `fibr_visitor_id`: 訪問者識別子（UUID）
- `fibr_session_id`: セッション識別子
- `fibr_experiments`: 参加中のテスト情報

**LocalStorage併用**:
- Cookieが無効な場合のフォールバック
- より大きなデータ（行動履歴など）を保存

#### パフォーマンス

**目標**:
- **スクリプトサイズ**: 30KB以下（gzip圧縮後）
- **初期化時間**: 50ms以内
- **メモリ使用量**: 5MB以内

**最適化手法**:
- Tree-shaking（未使用コードの削除）
- Code-splitting（機能ごとに分割）
- Lazy loading（必要な機能のみ読み込み）
- Brotli圧縮（gzipより高圧縮率）

**モニタリング**:
- Real User Monitoring（RUM）でパフォーマンス監視
- Core Web Vitalsへの影響を測定

---

### 2.2 パーソナライゼーションの配信方式

#### レンダリング方式

**ハイブリッド方式: エッジサイドレンダリング（ESR） + クライアントサイドレンダリング（CSR）**

##### エッジサイドレンダリング（ESR）- メイン方式

**対象**: 静的LP、商品ページ

**仕組み**:
1. ユーザーリクエストがエッジサーバー（Cloudflare Workers）に到達
2. エッジでコンテキスト分析（Cookie、UTMパラメータ、User-Agent）
3. パーソナライズルールを適用してHTMLを書き換え
4. 書き換えたHTMLをユーザーに返す

**メリット**:
- TTFBが速い（エッジで処理完結）
- SEOフレンドリー（クローラーも最適化版を取得）
- ちらつきなし

**実装技術**:
- Cloudflare Workers（エッジコンピューティング）
- HTMLRewriter API（ストリーミングHTML書き換え）

**コード例**:
```javascript
// Cloudflare Worker
addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request));
});

async function handleRequest(request) {
  const url = new URL(request.url);
  const visitorId = getCookie(request, 'fibr_visitor_id');
  
  // パーソナライゼーションルールを取得
  const rules = await getPersonalizationRules(url.pathname, visitorId);
  
  // オリジンからHTMLを取得
  const response = await fetch(request);
  
  // HTMLRewriterでパーソナライズ
  return new HTMLRewriter()
    .on('h1.hero-title', new TitleRewriter(rules.title))
    .on('img.hero-image', new ImageRewriter(rules.image))
    .on('a.cta-button', new CTARewriter(rules.cta))
    .transform(response);
}
```

##### クライアントサイドレンダリング（CSR）- フォールバック

**対象**: 動的ページ、SPA、エッジ対応できないサイト

**仕組み**:
1. ページ読み込み完了後、SDKが起動
2. コンテキスト分析
3. JavaScriptでDOMを書き換え

**メリット**:
- あらゆるサイトに対応可能
- 導入が簡単

**デメリット**:
- ちらつきのリスク
- SEOに影響（クローラーは元のコンテンツを取得）

**Anti-flicker対策**:
```css
/* 初期状態で非表示 */
[data-fibr-personalize] {
  opacity: 0;
  transition: opacity 0.3s;
}

/* パーソナライズ完了後に表示 */
[data-fibr-personalize].fibr-ready {
  opacity: 1;
}
```

#### キャッシュ戦略

**多層キャッシュ戦略**

##### 1. エッジキャッシュ（Cloudflare CDN）

**キャッシュキー**:
```
URL + セグメント識別子
例: /lp/campaign?segment=returning_visitor_tokyo
```

**キャッシュ期間**:
- 静的コンテンツ: 7日間
- パーソナライズコンテンツ: 1時間

**Vary Header**:
```
Vary: Cookie, User-Agent
```

##### 2. ブラウザキャッシュ

**Cache-Control**:
```
Cache-Control: public, max-age=3600, s-maxage=3600
```

##### 3. アプリケーションキャッシュ（Redis）

**キャッシュ対象**:
- パーソナライゼーションルール
- セグメント定義
- A/Bテスト設定

**キャッシュ期間**: 5分

**無効化タイミング**:
- ルール更新時に即座に無効化
- Pub/Subでエッジサーバーに通知

#### パーソナライズとキャッシュの両立

**セグメントベースキャッシング**

**仕組み**:
1. 訪問者を有限のセグメントに分類（例: 10セグメント）
2. セグメントごとにコンテンツをキャッシュ
3. 同じセグメントの訪問者は同じキャッシュを共有

**セグメント例**:
- 新規訪問者（広告経由）
- 新規訪問者（オーガニック）
- リピーター（購入履歴あり）
- リピーター（購入履歴なし）
- 地域別（東京、大阪、その他）

**キャッシュヒット率目標**: 70%以上

#### フォールバック

**パーソナライゼーション失敗時の挙動**

**3段階フォールバック**:

1. **エッジ処理失敗**:
   - オリジンサーバーから元のHTMLを返す
   - クライアントサイドSDKでリトライ

2. **クライアントサイド処理失敗**:
   - デフォルトコンテンツを表示
   - エラーログを送信

3. **タイムアウト**:
   - 3秒以内に完了しない場合、デフォルト表示
   - バックグラウンドで処理継続

**デフォルトコンテンツの定義**:
- ダッシュボードで設定
- 最も汎用的なコンテンツ（全訪問者向け）

---

### 2.3 データモデルの詳細

#### データ保持期間

| データ種別 | 保持期間 | 理由 |
|-----------|---------|------|
| 訪問者プロファイル | 365日間 | 長期的な行動分析に必要 |
| セッションデータ | 90日間 | 短期的な行動分析に十分 |
| 実験データ（進行中） | 無期限 | 実験完了まで保持 |
| 実験データ（完了） | 730日間（2年） | 過去の学習データとして活用 |
| パフォーマンスメトリクス | 180日間（6ヶ月） | トレンド分析に十分 |
| エラーログ | 30日間 | デバッグに必要な期間 |
| 監査ログ | 1095日間（3年） | コンプライアンス要件 |

#### データアーカイブ戦略

**自動アーカイブ**

**対象**:
- 完了後180日経過した実験データ
- 90日以上アクセスのない訪問者データ

**アーカイブ先**:
- AWS S3 Glacier（低コストストレージ）
- Parquet形式で圧縮保存

**アーカイブトリガー**:
- 毎日深夜2時に自動実行
- 保持期間を超えたデータを検出

**復元**:
- 必要に応じて手動で復元可能
- 復元には3-5時間かかる

#### データ削除

**論理削除 + 物理削除のハイブリッド**

##### 論理削除（Soft Delete）

**対象**: ユーザーが削除した設定、実験

**方法**:
- `deleted_at`カラムにタイムスタンプを記録
- クエリ時に`WHERE deleted_at IS NULL`で除外

**物理削除タイミング**: 30日後

##### 物理削除（Hard Delete）

**対象**:
- 保持期間を超えたデータ
- GDPR削除リクエスト対象データ

**方法**:
- データベースから完全削除
- バックアップからも削除

#### GDPR対応の削除リクエスト処理

**処理フロー**:

1. **リクエスト受付**:
   - ダッシュボードまたはメールで受付
   - 本人確認（メール認証）

2. **データ特定**:
   - 訪問者IDに紐づく全データを検索
   - 削除対象データのリストを生成

3. **削除実行**:
   - 個人を特定できるデータを即座に削除
   - 統計データは匿名化して保持

4. **完了通知**:
   - 30日以内に処理完了
   - 削除証明書を発行

**削除対象**:
- 訪問者プロファイル
- セッションデータ
- Cookie情報

**保持可能（匿名化）**:
- 集計済み統計データ
- A/Bテスト結果（個人識別情報なし）

---

### 2.4 A/Bテストのトラフィック分配

#### 分配アルゴリズム

**ハッシュベース分配（Deterministic Hashing）**

**選定理由**:
- 同じ訪問者は常に同じバリアントを見る（スティッキネス）
- サーバー間で状態を共有する必要がない
- スケーラブル

**実装**:
```javascript
function assignVariant(visitorId, experimentId, variants) {
  // MurmurHash3を使用
  const hash = murmur3(visitorId + experimentId);
  const bucket = hash % 100; // 0-99のバケットに分配
  
  let cumulative = 0;
  for (const variant of variants) {
    cumulative += variant.trafficAllocation; // 例: 50%
    if (bucket < cumulative) {
      return variant.id;
    }
  }
  return variants[0].id; // フォールバック
}
```

**例**:
- 訪問者ID: `abc123`
- 実験ID: `exp_001`
- バリアント: A (50%), B (50%)

```
hash("abc123exp_001") % 100 = 42
→ 42 < 50 → バリアントA
```

#### スティッキネス

**セッション単位 + Cookie永続化**

**実装**:
1. 初回訪問時にバリアントを決定
2. Cookieに保存（有効期限: 実験終了まで）
3. 同じ訪問者は常に同じバリアントを見る

**Cookie例**:
```
fibr_experiments={"exp_001":"variant_a","exp_002":"variant_b"}
```

**例外**:
- Cookieが削除された場合、再度ハッシュで決定（同じ結果）
- 実験設定が変更された場合、再割り当て

#### トラフィック配分の変更

**実験中の配分変更は非推奨**

**理由**:
- 統計的信頼性が損なわれる
- Simpson's Paradox（シンプソンのパラドックス）のリスク

**やむを得ず変更する場合**:
1. 既存訪問者は元の配分を維持
2. 新規訪問者のみ新しい配分を適用
3. ダッシュボードで警告を表示

**実装**:
```javascript
// 実験設定にバージョンを持たせる
{
  experimentId: "exp_001",
  version: 2,
  variants: [
    { id: "a", trafficAllocation: 30 }, // 50% → 30%に変更
    { id: "b", trafficAllocation: 70 }  // 50% → 70%に変更
  ]
}

// 訪問者に割り当てたバージョンを記録
{
  visitorId: "abc123",
  experimentId: "exp_001",
  variant: "a",
  version: 1  // 元の配分（50/50）で割り当て
}
```

---

### 2.5 データベース設計（Supabase PostgreSQL）

#### スキーマ設計

##### 主要テーブル

**1. organizations（組織）**
```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  plan VARCHAR(50) NOT NULL, -- 'starter', 'professional', 'enterprise'
  status VARCHAR(50) DEFAULT 'active', -- 'active', 'suspended', 'cancelled'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**2. users（ユーザー）**
```sql
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  email VARCHAR(255) UNIQUE NOT NULL,
  role VARCHAR(50) NOT NULL, -- 'admin', 'editor', 'viewer'
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**3. sites（サイト）**
```sql
CREATE TABLE sites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  domain VARCHAR(255) NOT NULL,
  site_id VARCHAR(50) UNIQUE NOT NULL, -- トラッキング用ID
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**4. visitor_profiles（訪問者プロファイル）**
```sql
CREATE TABLE visitor_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  visitor_id VARCHAR(255) NOT NULL, -- Cookie/LocalStorageのID
  first_seen_at TIMESTAMPTZ DEFAULT NOW(),
  last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  total_sessions INT DEFAULT 1,
  total_pageviews INT DEFAULT 1,
  device_type VARCHAR(50), -- 'desktop', 'mobile', 'tablet'
  browser VARCHAR(100),
  os VARCHAR(100),
  country VARCHAR(2), -- ISO 3166-1 alpha-2
  city VARCHAR(255),
  utm_source VARCHAR(255),
  utm_medium VARCHAR(255),
  utm_campaign VARCHAR(255),
  referrer TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(site_id, visitor_id)
);

CREATE INDEX idx_visitor_profiles_site_visitor 
  ON visitor_profiles(site_id, visitor_id);
CREATE INDEX idx_visitor_profiles_last_seen 
  ON visitor_profiles(last_seen_at);
```

**5. personalization_rules（パーソナライゼーションルール）**
```sql
CREATE TABLE personalization_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  status VARCHAR(50) DEFAULT 'active', -- 'active', 'paused', 'archived'
  url_pattern VARCHAR(500), -- 適用するURLパターン
  segment_conditions JSONB, -- セグメント条件
  content_variations JSONB, -- コンテンツバリエーション
  priority INT DEFAULT 0, -- 優先度（高い方が優先）
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_personalization_rules_site 
  ON personalization_rules(site_id, status);
```

**6. experiments（実験）**
```sql
CREATE TABLE experiments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  name VARCHAR(255) NOT NULL,
  hypothesis TEXT,
  status VARCHAR(50) DEFAULT 'draft', -- 'draft', 'running', 'paused', 'completed'
  type VARCHAR(50) NOT NULL, -- 'ab_test', 'multivariate', 'redirect'
  url_pattern VARCHAR(500),
  traffic_allocation INT DEFAULT 100, -- 参加率（%）
  variants JSONB NOT NULL, -- バリアント定義
  start_date TIMESTAMPTZ,
  end_date TIMESTAMPTZ,
  winner_variant_id VARCHAR(50),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_experiments_site_status 
  ON experiments(site_id, status);
```

**7. experiment_events（実験イベント）**
```sql
CREATE TABLE experiment_events (
  id BIGSERIAL PRIMARY KEY,
  experiment_id UUID REFERENCES experiments(id) ON DELETE CASCADE,
  visitor_id VARCHAR(255) NOT NULL,
  variant_id VARCHAR(50) NOT NULL,
  event_type VARCHAR(50) NOT NULL, -- 'impression', 'conversion'
  event_value DECIMAL(10, 2), -- コンバージョン金額など
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB
);

CREATE INDEX idx_experiment_events_experiment 
  ON experiment_events(experiment_id, timestamp);
CREATE INDEX idx_experiment_events_visitor 
  ON experiment_events(visitor_id, experiment_id);
```

**8. performance_metrics（パフォーマンスメトリクス）**
```sql
CREATE TABLE performance_metrics (
  id BIGSERIAL PRIMARY KEY,
  site_id UUID REFERENCES sites(id) ON DELETE CASCADE,
  url VARCHAR(500),
  metric_type VARCHAR(50) NOT NULL, -- 'lcp', 'fid', 'cls', 'ttfb'
  metric_value DECIMAL(10, 2) NOT NULL,
  device_type VARCHAR(50),
  timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- TimescaleDB拡張を使用（時系列データ最適化）
SELECT create_hypertable('performance_metrics', 'timestamp');

CREATE INDEX idx_performance_metrics_site_time 
  ON performance_metrics(site_id, timestamp DESC);
```

#### Row Level Security（RLS）

**Supabase Authと連携したセキュリティ**

```sql
-- organizationsテーブル
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own organization"
  ON organizations FOR SELECT
  USING (id IN (
    SELECT organization_id FROM users WHERE id = auth.uid()
  ));

-- sitesテーブル
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view sites in their organization"
  ON sites FOR SELECT
  USING (organization_id IN (
    SELECT organization_id FROM users WHERE id = auth.uid()
  ));

CREATE POLICY "Admins can insert sites"
  ON sites FOR INSERT
  WITH CHECK (
    organization_id IN (
      SELECT organization_id FROM users 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
```

---

## まとめ

### 技術要件の決定事項

#### 2.1 トラッキングSDK
- **配信**: CDN経由（Cloudflare）
- **読み込み**: 非同期（async）、<head>内
- **バージョニング**: セマンティックバージョニング
- **後方互換性**: 12ヶ月サポート
- **プライバシー**: ファーストパーティCookie
- **サイズ**: 30KB以下（gzip圧縮後）

#### 2.2 パーソナライゼーション配信
- **方式**: エッジサイドレンダリング（ESR）+ クライアントサイド（CSR）
- **キャッシュ**: 多層キャッシュ（エッジ、ブラウザ、Redis）
- **キャッシュヒット率目標**: 70%以上
- **フォールバック**: 3段階（エッジ→クライアント→デフォルト）

#### 2.3 データモデル
- **保持期間**: 訪問者365日、実験730日、メトリクス180日
- **削除**: 論理削除 + 物理削除
- **GDPR対応**: 30日以内に削除完了

#### 2.4 A/Bテスト
- **分配**: ハッシュベース（MurmurHash3）
- **スティッキネス**: Cookie永続化
- **配分変更**: 実験中は非推奨

#### 2.5 データベース
- **DB**: Supabase PostgreSQL + TimescaleDB
- **セキュリティ**: Row Level Security（RLS）
- **スケーラビリティ**: パーティショニング、インデックス最適化

---

次は**3. UI/UX設計**（画面一覧、ワイヤーフレーム、ユーザーフロー）に進みますか？

