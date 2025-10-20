# セキュリティ詳細設計書

## 7. セキュリティ詳細

### 7.1 認証・認可

#### 認証方式

**Supabase Auth採用**

**対応認証方法**:

1. **メール/パスワード**
   - パスワード要件: 最低8文字、大小英字・数字・記号を含む
   - パスワードハッシュ: bcrypt（コスト係数10）
   - メール確認必須

2. **OAuth 2.0**
   - Google
   - GitHub
   - Microsoft（エンタープライズ向け）

3. **マジックリンク**
   - パスワードレス認証
   - メールでワンタイムリンク送信
   - 有効期限: 15分

4. **2要素認証（2FA）**
   - TOTP（Time-based One-Time Password）
   - Google Authenticator、Authy対応
   - エンタープライズプランで必須

#### 実装例

**サインアップ**:
```javascript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_KEY
);

async function signUp(email, password) {
  // パスワード強度チェック
  if (!isStrongPassword(password)) {
    throw new Error('パスワードは8文字以上で、大小英字・数字・記号を含む必要があります');
  }
  
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    options: {
      emailRedirectTo: 'https://app.example.com/auth/callback',
      data: {
        created_at: new Date().toISOString()
      }
    }
  });
  
  if (error) throw error;
  
  // メール確認待ち
  return { message: '確認メールを送信しました。メールのリンクをクリックしてください。' };
}

function isStrongPassword(password) {
  const minLength = 8;
  const hasUpperCase = /[A-Z]/.test(password);
  const hasLowerCase = /[a-z]/.test(password);
  const hasNumbers = /\d/.test(password);
  const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);
  
  return password.length >= minLength && 
         hasUpperCase && 
         hasLowerCase && 
         hasNumbers && 
         hasSpecialChar;
}
```

**ログイン**:
```javascript
async function signIn(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({
    email,
    password
  });
  
  if (error) {
    // ログイン失敗をログに記録
    await logSecurityEvent({
      type: 'login_failed',
      email,
      ip: request.ip,
      userAgent: request.headers['user-agent']
    });
    
    throw error;
  }
  
  // ログイン成功をログに記録
  await logSecurityEvent({
    type: 'login_success',
    userId: data.user.id,
    email,
    ip: request.ip
  });
  
  return data;
}
```

**OAuth認証**:
```javascript
async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: 'https://app.example.com/auth/callback',
      scopes: 'email profile'
    }
  });
  
  if (error) throw error;
  
  // ブラウザをリダイレクト
  window.location.href = data.url;
}
```

**2FA有効化**:
```javascript
async function enable2FA(userId) {
  const { data, error } = await supabase.auth.mfa.enroll({
    factorType: 'totp'
  });
  
  if (error) throw error;
  
  // QRコードを生成してユーザーに表示
  return {
    qrCode: data.totp.qr_code,
    secret: data.totp.secret,
    message: 'Google AuthenticatorでQRコードをスキャンしてください'
  };
}

async function verify2FA(code) {
  const { data, error } = await supabase.auth.mfa.verify({
    factorId: factorId,
    code: code
  });
  
  if (error) throw error;
  
  return { message: '2FAが有効化されました' };
}
```

#### 認可（アクセス制御）

**ロールベースアクセス制御（RBAC）**

**ロール定義**:

| ロール | 権限 | 対象 |
|--------|------|------|
| Owner | 全権限 | 組織の所有者 |
| Admin | 管理権限（請求以外） | 管理者 |
| Editor | 編集権限 | マーケター |
| Viewer | 閲覧のみ | アナリスト |

**権限マトリクス**:

| 機能 | Owner | Admin | Editor | Viewer |
|------|-------|-------|--------|--------|
| サイト作成・削除 | ✅ | ✅ | ❌ | ❌ |
| パーソナライゼーションルール作成 | ✅ | ✅ | ✅ | ❌ |
| A/Bテスト作成 | ✅ | ✅ | ✅ | ❌ |
| 結果閲覧 | ✅ | ✅ | ✅ | ✅ |
| チームメンバー管理 | ✅ | ✅ | ❌ | ❌ |
| 請求管理 | ✅ | ❌ | ❌ | ❌ |
| API キー管理 | ✅ | ✅ | ❌ | ❌ |

**実装（Row Level Security）**:

```sql
-- Supabase RLS（Row Level Security）ポリシー

-- サイトテーブル: 自分の組織のサイトのみ閲覧可能
CREATE POLICY "Users can view their organization's sites"
ON sites FOR SELECT
USING (
  organization_id IN (
    SELECT organization_id 
    FROM organization_members 
    WHERE user_id = auth.uid()
  )
);

-- パーソナライゼーションルール: Editor以上が作成可能
CREATE POLICY "Editors can create personalization rules"
ON personalization_rules FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 
    FROM organization_members 
    WHERE user_id = auth.uid() 
    AND organization_id = personalization_rules.organization_id
    AND role IN ('owner', 'admin', 'editor')
  )
);

-- 請求情報: Ownerのみ閲覧可能
CREATE POLICY "Only owners can view billing"
ON billing FOR SELECT
USING (
  EXISTS (
    SELECT 1 
    FROM organization_members 
    WHERE user_id = auth.uid() 
    AND organization_id = billing.organization_id
    AND role = 'owner'
  )
);
```

#### セッション管理

**JWT（JSON Web Token）**:
- Supabase Authが自動発行
- 有効期限: 1時間
- リフレッシュトークン: 30日

**セッション設定**:
```javascript
// セッションの自動更新
supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'TOKEN_REFRESHED') {
    console.log('トークンが更新されました');
  }
  
  if (event === 'SIGNED_OUT') {
    // ローカルストレージをクリア
    localStorage.clear();
    window.location.href = '/login';
  }
});

// 手動でトークンをリフレッシュ
async function refreshSession() {
  const { data, error } = await supabase.auth.refreshSession();
  if (error) throw error;
  return data.session;
}
```

**セッション無効化**:
```javascript
async function signOut() {
  const { error } = await supabase.auth.signOut();
  if (error) throw error;
  
  // セキュリティログに記録
  await logSecurityEvent({
    type: 'logout',
    userId: user.id
  });
}

// 全デバイスからログアウト
async function signOutAllDevices(userId) {
  // Supabase Admin APIで全セッションを無効化
  const { error } = await supabaseAdmin.auth.admin.signOut(userId, 'global');
  if (error) throw error;
}
```

---

### 7.2 データ保護

#### 暗号化

**転送中の暗号化**:
- **TLS 1.3**: すべての通信でHTTPS必須
- **証明書**: Let's Encrypt（自動更新）
- **HSTS**: Strict-Transport-Security ヘッダー有効

**保存時の暗号化**:
- **データベース**: Supabase（AES-256で自動暗号化）
- **ストレージ**: Supabase Storage（AES-256）
- **バックアップ**: S3（サーバーサイド暗号化SSE-S3）

**機密情報の暗号化**:
```javascript
const crypto = require('crypto');

// APIキーなどの機密情報を暗号化
function encrypt(text) {
  const algorithm = 'aes-256-gcm';
  const key = Buffer.from(process.env.ENCRYPTION_KEY, 'hex'); // 32バイト
  const iv = crypto.randomBytes(16);
  
  const cipher = crypto.createCipheriv(algorithm, key, iv);
  let encrypted = cipher.update(text, 'utf8', 'hex');
  encrypted += cipher.final('hex');
  
  const authTag = cipher.getAuthTag();
  
  return {
    encrypted,
    iv: iv.toString('hex'),
    authTag: authTag.toString('hex')
  };
}

function decrypt(encrypted, iv, authTag) {
  const algorithm = 'aes-256-gcm';
  const key = Buffer.from(process.env.ENCRYPTION_KEY, 'hex');
  
  const decipher = crypto.createDecipheriv(
    algorithm, 
    key, 
    Buffer.from(iv, 'hex')
  );
  decipher.setAuthTag(Buffer.from(authTag, 'hex'));
  
  let decrypted = decipher.update(encrypted, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

// 使用例
const apiKey = 'sk_live_abc123...';
const { encrypted, iv, authTag } = encrypt(apiKey);

// データベースに保存
await supabase.from('api_keys').insert({
  organization_id: orgId,
  encrypted_key: encrypted,
  iv,
  auth_tag: authTag
});

// 取得時に復号化
const { data } = await supabase.from('api_keys')
  .select('*')
  .eq('organization_id', orgId)
  .single();

const decryptedKey = decrypt(data.encrypted_key, data.iv, data.auth_tag);
```

#### 個人情報保護

**GDPR対応**:

1. **データ最小化**: 必要最小限のデータのみ収集
2. **同意取得**: Cookie同意バナー表示
3. **アクセス権**: ユーザーが自分のデータを閲覧可能
4. **削除権**: ユーザーがデータ削除をリクエスト可能
5. **データポータビリティ**: データをエクスポート可能

**実装例**:

```javascript
// データエクスポート
async function exportUserData(userId) {
  const userData = await supabase
    .from('users')
    .select('*')
    .eq('id', userId)
    .single();
  
  const sites = await supabase
    .from('sites')
    .select('*')
    .eq('owner_id', userId);
  
  const experiments = await supabase
    .from('experiments')
    .select('*')
    .eq('created_by', userId);
  
  const exportData = {
    user: userData.data,
    sites: sites.data,
    experiments: experiments.data,
    exported_at: new Date().toISOString()
  };
  
  // JSONファイルとして提供
  return JSON.stringify(exportData, null, 2);
}

// データ削除
async function deleteUserData(userId) {
  // 30日間の猶予期間を設ける
  await supabase
    .from('users')
    .update({ 
      deletion_requested_at: new Date().toISOString(),
      status: 'pending_deletion'
    })
    .eq('id', userId);
  
  // 30日後に実際に削除（cron jobで実行）
  // await supabase.from('users').delete().eq('id', userId);
  
  return { message: '30日後にデータが完全に削除されます' };
}
```

**日本の個人情報保護法対応**:
- プライバシーポリシーの掲載
- 個人情報の利用目的の明示
- 第三者提供の同意取得（該当する場合）

---

### 7.3 脆弱性対策

#### XSS（クロスサイトスクリプティング）対策

**対策**:

1. **入力のサニタイズ**:
```javascript
import DOMPurify from 'dompurify';

function sanitizeInput(userInput) {
  return DOMPurify.sanitize(userInput, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a'],
    ALLOWED_ATTR: ['href']
  });
}

// 使用例
const userComment = '<script>alert("XSS")</script>安全なコメント';
const safe = sanitizeInput(userComment);
// → '安全なコメント'
```

2. **Content Security Policy（CSP）**:
```javascript
// Next.js の next.config.js
const securityHeaders = [
  {
    key: 'Content-Security-Policy',
    value: `
      default-src 'self';
      script-src 'self' 'unsafe-eval' 'unsafe-inline' https://cdn.example.com;
      style-src 'self' 'unsafe-inline';
      img-src 'self' data: https:;
      font-src 'self' data:;
      connect-src 'self' https://api.example.com;
      frame-ancestors 'none';
    `.replace(/\s{2,}/g, ' ').trim()
  }
];

module.exports = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders
      }
    ];
  }
};
```

3. **出力のエスケープ**:
```javascript
// React（自動エスケープ）
function UserComment({ comment }) {
  return <div>{comment}</div>; // 自動的にエスケープされる
}

// dangerouslySetInnerHTMLは避ける
// どうしても必要な場合はサニタイズ後に使用
function SafeHTML({ html }) {
  const sanitized = DOMPurify.sanitize(html);
  return <div dangerouslySetInnerHTML={{ __html: sanitized }} />;
}
```

#### CSRF（クロスサイトリクエストフォージェリ）対策

**対策**:

1. **CSRFトークン**:
```javascript
import csrf from 'csurf';

const csrfProtection = csrf({ cookie: true });

app.post('/api/experiments', csrfProtection, async (req, res) => {
  // CSRFトークンが自動検証される
  const experiment = await createExperiment(req.body);
  res.json(experiment);
});

// フロントエンドでトークンを送信
fetch('/api/experiments', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'CSRF-Token': csrfToken
  },
  body: JSON.stringify(experimentData)
});
```

2. **SameSite Cookie**:
```javascript
res.cookie('session', sessionId, {
  httpOnly: true,
  secure: true,
  sameSite: 'strict', // または 'lax'
  maxAge: 3600000 // 1時間
});
```

#### SQL Injection対策

**対策**:

1. **パラメータ化クエリ**（Supabaseは自動対応）:
```javascript
// ✅ 安全（Supabaseはパラメータ化される）
const { data } = await supabase
  .from('users')
  .select('*')
  .eq('email', userInput);

// ❌ 危険（生SQLは使わない）
// const result = await db.query(`SELECT * FROM users WHERE email = '${userInput}'`);
```

2. **入力検証**:
```javascript
function validateEmail(email) {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    throw new Error('無効なメールアドレスです');
  }
  return email;
}
```

#### 認証・認可の脆弱性対策

**対策**:

1. **ブルートフォース攻撃対策**:
```javascript
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15分
  max: 5, // 5回まで
  message: 'ログイン試行回数が多すぎます。15分後に再試行してください。',
  standardHeaders: true,
  legacyHeaders: false
});

app.post('/api/auth/login', loginLimiter, async (req, res) => {
  // ログイン処理
});
```

2. **パスワードリセットの安全性**:
```javascript
async function requestPasswordReset(email) {
  // トークンを生成（暗号学的に安全な乱数）
  const resetToken = crypto.randomBytes(32).toString('hex');
  const hashedToken = crypto
    .createHash('sha256')
    .update(resetToken)
    .digest('hex');
  
  // トークンをDBに保存（有効期限1時間）
  await supabase
    .from('password_reset_tokens')
    .insert({
      email,
      token: hashedToken,
      expires_at: new Date(Date.now() + 3600000).toISOString()
    });
  
  // メールでトークンを送信
  await sendEmail({
    to: email,
    subject: 'パスワードリセット',
    body: `以下のリンクからパスワードをリセットしてください（1時間有効）：
           https://app.example.com/reset-password?token=${resetToken}`
  });
}
```

#### 依存関係の脆弱性対策

**対策**:

1. **定期的な更新**:
```bash
# 脆弱性スキャン
npm audit

# 自動修正
npm audit fix

# 依存関係の更新
npm update
```

2. **Dependabot設定**（GitHub）:
```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 10
    reviewers:
      - "security-team"
```

3. **Snyk統合**:
```bash
# Snykでスキャン
npx snyk test

# CI/CDに統合
npx snyk monitor
```

---

### 7.4 APIセキュリティ

#### API認証

**APIキー認証**:

```javascript
async function validateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'];
  
  if (!apiKey) {
    return res.status(401).json({ error: 'APIキーが必要です' });
  }
  
  // APIキーをハッシュ化して検索
  const hashedKey = crypto
    .createHash('sha256')
    .update(apiKey)
    .digest('hex');
  
  const { data, error } = await supabase
    .from('api_keys')
    .select('*, organizations(*)')
    .eq('hashed_key', hashedKey)
    .eq('status', 'active')
    .single();
  
  if (error || !data) {
    return res.status(401).json({ error: '無効なAPIキーです' });
  }
  
  // レート制限チェック
  const allowed = await checkRateLimit(data.organization_id);
  if (!allowed) {
    return res.status(429).json({ error: 'レート制限を超えました' });
  }
  
  // リクエストに組織情報を追加
  req.organization = data.organizations;
  next();
}

app.use('/api/v1/*', validateApiKey);
```

**APIキー生成**:
```javascript
async function createApiKey(organizationId, name) {
  // 暗号学的に安全なAPIキーを生成
  const apiKey = `sk_${crypto.randomBytes(32).toString('hex')}`;
  
  // ハッシュ化して保存
  const hashedKey = crypto
    .createHash('sha256')
    .update(apiKey)
    .digest('hex');
  
  await supabase.from('api_keys').insert({
    organization_id: organizationId,
    name,
    hashed_key: hashedKey,
    status: 'active',
    created_at: new Date().toISOString()
  });
  
  // 生成したAPIキーは1回だけ表示（再表示不可）
  return { 
    apiKey,
    message: 'このAPIキーは再表示できません。安全に保管してください。'
  };
}
```

#### レート制限

**実装**:
```javascript
const Redis = require('ioredis');
const redis = new Redis(process.env.REDIS_URL);

async function checkRateLimit(organizationId) {
  const key = `ratelimit:${organizationId}`;
  const limit = 1000; // 1時間あたり1000リクエスト
  const window = 3600; // 1時間
  
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, window);
  }
  
  if (current > limit) {
    return false;
  }
  
  return true;
}

// プラン別レート制限
const rateLimits = {
  starter: 100,      // 100リクエスト/時間
  professional: 1000, // 1,000リクエスト/時間
  enterprise: 10000   // 10,000リクエスト/時間
};
```

#### CORS設定

```javascript
const cors = require('cors');

const corsOptions = {
  origin: function (origin, callback) {
    // 許可するオリジンのリスト
    const allowedOrigins = [
      'https://app.example.com',
      'https://example.com'
    ];
    
    // 開発環境ではlocalhostを許可
    if (process.env.NODE_ENV === 'development') {
      allowedOrigins.push('http://localhost:3000');
    }
    
    if (!origin || allowedOrigins.indexOf(origin) !== -1) {
      callback(null, true);
    } else {
      callback(new Error('CORSポリシーにより拒否されました'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-API-Key']
};

app.use(cors(corsOptions));
```

---

### 7.5 セキュリティ監査

#### 定期的なセキュリティレビュー

**スケジュール**:

| 項目 | 頻度 | 担当 |
|------|------|------|
| 依存関係の脆弱性スキャン | 毎週 | 自動（Dependabot、Snyk） |
| コードレビュー | 毎PR | 開発チーム |
| ペネトレーションテスト | 四半期ごと | 外部セキュリティ会社 |
| セキュリティ監査 | 年1回 | 外部監査法人 |
| アクセスログレビュー | 毎月 | セキュリティ担当 |

#### セキュリティログ

**記録する情報**:
```javascript
async function logSecurityEvent(event) {
  await supabase.from('security_logs').insert({
    type: event.type,
    user_id: event.userId,
    organization_id: event.organizationId,
    ip_address: event.ip,
    user_agent: event.userAgent,
    details: event.details,
    severity: event.severity || 'info',
    created_at: new Date().toISOString()
  });
}

// 記録するイベント
const securityEvents = {
  login_success: 'ログイン成功',
  login_failed: 'ログイン失敗',
  logout: 'ログアウト',
  password_reset_requested: 'パスワードリセット要求',
  password_changed: 'パスワード変更',
  2fa_enabled: '2FA有効化',
  2fa_disabled: '2FA無効化',
  api_key_created: 'APIキー作成',
  api_key_deleted: 'APIキー削除',
  permission_denied: '権限拒否',
  suspicious_activity: '不審なアクティビティ'
};
```

#### 異常検知

**実装**:
```javascript
async function detectAnomalies(userId) {
  // 短時間に複数の異なるIPからのログイン
  const recentLogins = await supabase
    .from('security_logs')
    .select('ip_address')
    .eq('user_id', userId)
    .eq('type', 'login_success')
    .gte('created_at', new Date(Date.now() - 3600000).toISOString());
  
  const uniqueIPs = new Set(recentLogins.data.map(l => l.ip_address));
  
  if (uniqueIPs.size >= 3) {
    // アラート送信
    await sendSecurityAlert({
      userId,
      type: 'multiple_ip_login',
      message: '1時間以内に3つ以上の異なるIPからログインがありました',
      severity: 'high'
    });
    
    // 2FA強制
    await force2FA(userId);
  }
  
  // 深夜の大量API呼び出し
  const hour = new Date().getHours();
  if (hour >= 2 && hour <= 5) {
    const apiCalls = await getAPICallCount(userId, 3600000);
    if (apiCalls > 1000) {
      await sendSecurityAlert({
        userId,
        type: 'unusual_api_activity',
        message: '深夜に大量のAPI呼び出しが検出されました',
        severity: 'medium'
      });
    }
  }
}
```

---

### 7.6 インシデント対応

#### セキュリティインシデント対応フロー

```
1. インシデント検知
   ↓
2. 初期評価（重大度判定）
   ↓
3. 封じ込め（被害拡大防止）
   ↓
4. 根絶（原因除去）
   ↓
5. 復旧
   ↓
6. 事後分析
   ↓
7. 再発防止策の実施
```

#### インシデント重大度

| レベル | 定義 | 例 | 対応時間 |
|--------|------|-----|---------|
| Critical | データ漏洩、システム侵害 | データベース不正アクセス | 即座 |
| High | 重大な脆弱性発見 | SQLインジェクション発見 | 4時間以内 |
| Medium | 軽微な脆弱性 | XSS脆弱性 | 24時間以内 |
| Low | 潜在的リスク | 古い依存関係 | 1週間以内 |

#### データ漏洩時の対応

**手順**:

1. **即座の封じ込め**:
   - 影響を受けたシステムを隔離
   - 不正アクセスをブロック
   - 全APIキーを無効化

2. **影響範囲の特定**:
   - 漏洩したデータの種類と量を特定
   - 影響を受けたユーザー数を特定

3. **通知**:
   - 影響を受けたユーザーに72時間以内に通知（GDPR要件）
   - 個人情報保護委員会に報告（日本の法律）

4. **復旧**:
   - 脆弱性を修正
   - セキュリティパッチを適用
   - 全ユーザーにパスワードリセットを要求

5. **事後分析**:
   - インシデントレポート作成
   - 再発防止策の策定

**通知テンプレート**:
```
件名: 重要なセキュリティ通知

お客様へ

[日付]に当社のシステムにおいてセキュリティインシデントが発生し、
お客様の個人情報が影響を受けた可能性があります。

【影響を受けた情報】
- メールアドレス
- 氏名
- [その他の情報]

【影響を受けなかった情報】
- パスワード（ハッシュ化されており安全です）
- クレジットカード情報（当社は保存していません）

【お客様にお願いしたいこと】
1. パスワードを変更してください
2. 2要素認証を有効化してください
3. 不審なメールやメッセージに注意してください

【当社の対応】
1. 脆弱性を修正しました
2. セキュリティ監査を実施しています
3. 再発防止策を講じています

ご不明な点がございましたら、security@example.com までご連絡ください。

ご迷惑をおかけして誠に申し訳ございません。
```

---

## まとめ

### セキュリティの決定事項

#### 7.1 認証・認可
- **認証**: Supabase Auth（メール/パスワード、OAuth、マジックリンク、2FA）
- **認可**: RBAC（Owner、Admin、Editor、Viewer）
- **セッション**: JWT（1時間）、リフレッシュトークン（30日）

#### 7.2 データ保護
- **転送中**: TLS 1.3、HSTS
- **保存時**: AES-256（Supabase、S3）
- **機密情報**: AES-256-GCM（APIキー等）
- **GDPR**: データエクスポート、削除、同意取得

#### 7.3 脆弱性対策
- **XSS**: DOMPurify、CSP
- **CSRF**: CSRFトークン、SameSite Cookie
- **SQLインジェクション**: パラメータ化クエリ
- **ブルートフォース**: レート制限（5回/15分）
- **依存関係**: Dependabot、Snyk

#### 7.4 APIセキュリティ
- **認証**: APIキー（SHA-256ハッシュ）
- **レート制限**: プラン別（100-10,000リクエスト/時間）
- **CORS**: ホワイトリスト方式

#### 7.5 セキュリティ監査
- **脆弱性スキャン**: 毎週（自動）
- **ペネトレーションテスト**: 四半期ごと
- **セキュリティ監査**: 年1回
- **異常検知**: 複数IP、深夜API呼び出し

#### 7.6 インシデント対応
- **4段階**: Critical、High、Medium、Low
- **データ漏洩**: 72時間以内に通知
- **ポストモーテム**: 全Criticalインシデントで作成

---

次は最後の**8. テスト戦略**に進みます。

