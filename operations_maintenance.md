# 運用・保守戦略詳細設計書

## 6. 運用・保守戦略

### 6.1 監視とアラート

#### 監視対象

**1. インフラ監視**

| 項目 | 監視内容 | しきい値 | アラート |
|------|---------|---------|---------|
| CPU使用率 | サーバーCPU使用率 | 80%以上が5分継続 | Slack通知 |
| メモリ使用率 | サーバーメモリ使用率 | 85%以上が5分継続 | Slack通知 |
| ディスク使用率 | ストレージ使用率 | 90%以上 | Slack通知 + メール |
| ネットワーク | 帯域幅使用率 | 90%以上 | Slack通知 |
| データベース接続 | 接続プール使用率 | 80%以上 | Slack通知 |

**2. アプリケーション監視**

| 項目 | 監視内容 | しきい値 | アラート |
|------|---------|---------|---------|
| レスポンスタイム | API応答時間 | 500ms以上 | Slack通知 |
| エラー率 | 5xx/4xxエラー率 | 5%以上 | Slack通知 + PagerDuty |
| スループット | リクエスト数/秒 | 通常の2倍以上 | Slack通知 |
| SDK読み込み時間 | トラッキングSDK読み込み | 1秒以上 | Slack通知 |
| データベースクエリ | スロークエリ | 1秒以上 | ログ記録 |

**3. ビジネスメトリクス監視**

| 項目 | 監視内容 | しきい値 | アラート |
|------|---------|---------|---------|
| トラッキング失敗率 | イベント送信失敗率 | 10%以上 | Slack通知 + メール |
| パーソナライゼーション配信率 | ルール配信成功率 | 95%未満 | Slack通知 |
| A/Bテスト配分精度 | トラフィック配分の偏り | ±5%以上 | Slack通知 |
| LLM API失敗率 | Gemini API失敗率 | 20%以上 | Slack通知 |
| データ処理遅延 | イベント処理遅延 | 10秒以上 | Slack通知 |

#### 監視ツール

**採用ツール**:

1. **インフラ監視**: Datadog または Grafana + Prometheus
   - サーバーメトリクス
   - データベースメトリクス
   - ネットワークメトリクス

2. **アプリケーション監視**: Sentry
   - エラートラッキング
   - パフォーマンス監視
   - リリース追跡

3. **ログ管理**: Better Stack（旧Logtail）
   - 集中ログ管理
   - ログ検索・分析
   - アラート設定

4. **アップタイム監視**: UptimeRobot
   - エンドポイント監視（1分間隔）
   - SSL証明書監視
   - ステータスページ

5. **リアルユーザーモニタリング（RUM）**: Cloudflare Web Analytics
   - Core Web Vitals
   - ページ速度
   - ユーザー体験

#### アラート設定

**実装例（Datadog）**:

```javascript
// Datadog APIでアラート設定
const datadog = require('@datadog/datadog-api-client');

async function createAlert() {
  const configuration = datadog.client.createConfiguration();
  const apiInstance = new datadog.v1.MonitorsApi(configuration);
  
  const params = {
    body: {
      name: 'API応答時間が遅い',
      type: 'metric alert',
      query: 'avg(last_5m):avg:api.response_time{env:production} > 500',
      message: `
@slack-alerts
APIの応答時間が500msを超えています。
現在の応答時間: {{value}}ms
調査してください。
      `,
      tags: ['env:production', 'team:backend'],
      priority: 2,
      options: {
        thresholds: {
          critical: 500,
          warning: 300
        },
        notify_no_data: true,
        no_data_timeframe: 10
      }
    }
  };
  
  await apiInstance.createMonitor(params);
}
```

**Slack通知の実装**:

```javascript
const { WebClient } = require('@slack/web-api');
const slack = new WebClient(process.env.SLACK_BOT_TOKEN);

async function sendAlert(alert) {
  await slack.chat.postMessage({
    channel: '#alerts',
    text: `🚨 ${alert.title}`,
    blocks: [
      {
        type: 'header',
        text: {
          type: 'plain_text',
          text: `🚨 ${alert.title}`
        }
      },
      {
        type: 'section',
        fields: [
          {
            type: 'mrkdwn',
            text: `*レベル:*\n${alert.severity}`
          },
          {
            type: 'mrkdwn',
            text: `*時刻:*\n${new Date().toLocaleString('ja-JP')}`
          }
        ]
      },
      {
        type: 'section',
        text: {
          type: 'mrkdwn',
          text: alert.message
        }
      },
      {
        type: 'actions',
        elements: [
          {
            type: 'button',
            text: {
              type: 'plain_text',
              text: 'ダッシュボードを見る'
            },
            url: alert.dashboardUrl
          }
        ]
      }
    ]
  });
}
```

---

### 6.2 ログ管理

#### ログレベル

**5段階のログレベル**:

| レベル | 用途 | 例 |
|--------|------|-----|
| ERROR | エラー、障害 | API呼び出し失敗、データベース接続エラー |
| WARN | 警告、潜在的問題 | スロークエリ、リトライ実行 |
| INFO | 重要な情報 | ユーザーログイン、実験開始 |
| DEBUG | デバッグ情報 | 関数呼び出し、変数の値 |
| TRACE | 詳細なトレース | すべての処理ステップ |

**環境別設定**:
- **本番環境**: INFO以上
- **ステージング環境**: DEBUG以上
- **開発環境**: TRACE以上

#### ログフォーマット

**JSON形式で構造化ログ**:

```javascript
const winston = require('winston');

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: {
    service: 'japanese-ai-cro-tool',
    environment: process.env.NODE_ENV
  },
  transports: [
    new winston.transports.Console(),
    new winston.transports.File({ 
      filename: 'logs/error.log', 
      level: 'error' 
    }),
    new winston.transports.File({ 
      filename: 'logs/combined.log' 
    })
  ]
});

// 使用例
logger.info('ユーザーがログインしました', {
  userId: 'user_123',
  email: 'user@example.com',
  ip: '192.168.1.1',
  userAgent: 'Mozilla/5.0...'
});

logger.error('API呼び出しに失敗しました', {
  api: 'gemini',
  endpoint: '/v1/generateContent',
  statusCode: 500,
  error: error.message,
  stack: error.stack
});
```

**ログ出力例**:
```json
{
  "level": "error",
  "message": "API呼び出しに失敗しました",
  "timestamp": "2025-10-20T10:30:45.123Z",
  "service": "japanese-ai-cro-tool",
  "environment": "production",
  "api": "gemini",
  "endpoint": "/v1/generateContent",
  "statusCode": 500,
  "error": "Request timeout",
  "stack": "Error: Request timeout\n    at..."
}
```

#### ログ保持期間

| ログタイプ | 保持期間 | 保存先 |
|-----------|---------|--------|
| アプリケーションログ | 30日 | Better Stack |
| エラーログ | 90日 | Better Stack + S3 |
| アクセスログ | 30日 | Cloudflare |
| 監査ログ | 365日 | Supabase + S3 |
| データベースログ | 7日 | Supabase |

---

### 6.3 バックアップ戦略

#### データベースバックアップ

**Supabase自動バックアップ**:
- **頻度**: 毎日1回（深夜2時JST）
- **保持期間**: 
  - 日次バックアップ: 7日間
  - 週次バックアップ: 4週間
  - 月次バックアップ: 12ヶ月
- **バックアップ先**: Supabase内部ストレージ + S3（追加バックアップ）

**手動バックアップスクリプト**:

```bash
#!/bin/bash
# backup_database.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/database"
BACKUP_FILE="$BACKUP_DIR/backup_$DATE.sql.gz"

# PostgreSQLダンプ
pg_dump $DATABASE_URL | gzip > $BACKUP_FILE

# S3にアップロード
aws s3 cp $BACKUP_FILE s3://japanese-ai-cro-backups/database/

# 30日以上前のバックアップを削除
find $BACKUP_DIR -name "backup_*.sql.gz" -mtime +30 -delete

echo "バックアップ完了: $BACKUP_FILE"
```

**cron設定**:
```cron
0 2 * * * /scripts/backup_database.sh
```

#### ファイルバックアップ

**Supabase Storageのバックアップ**:
- レポートファイル、画像などのアセット
- S3にミラーリング（1日1回）

```javascript
// Supabase Storage → S3同期
const { createClient } = require('@supabase/supabase-js');
const AWS = require('aws-sdk');

async function syncStorageToS3() {
  const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_KEY
  );
  
  const s3 = new AWS.S3();
  
  // Supabaseから全ファイル取得
  const { data: files } = await supabase.storage
    .from('reports')
    .list();
  
  for (const file of files) {
    // ファイルをダウンロード
    const { data: fileData } = await supabase.storage
      .from('reports')
      .download(file.name);
    
    // S3にアップロード
    await s3.putObject({
      Bucket: 'japanese-ai-cro-backups',
      Key: `storage/reports/${file.name}`,
      Body: fileData
    }).promise();
  }
  
  console.log(`${files.length}ファイルを同期しました`);
}
```

#### 復元手順

**データベース復元**:

```bash
#!/bin/bash
# restore_database.sh

BACKUP_FILE=$1

if [ -z "$BACKUP_FILE" ]; then
  echo "使用方法: ./restore_database.sh <backup_file>"
  exit 1
fi

# バックアップファイルを解凍して復元
gunzip -c $BACKUP_FILE | psql $DATABASE_URL

echo "復元完了"
```

**復元テスト**:
- 月1回、ステージング環境で復元テストを実施
- 復元時間を記録（目標: 10分以内）

---

### 6.4 デプロイ戦略

#### CI/CD パイプライン

**GitHub Actions**:

```yaml
# .github/workflows/deploy.yml
name: Deploy to Production

on:
  push:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '22'
      
      - name: Install dependencies
        run: pnpm install
      
      - name: Run tests
        run: pnpm test
      
      - name: Run linter
        run: pnpm lint
      
      - name: Type check
        run: pnpm type-check

  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build application
        run: pnpm build
      
      - name: Upload build artifacts
        uses: actions/upload-artifact@v3
        with:
          name: build
          path: dist/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Download build artifacts
        uses: actions/download-artifact@v3
        with:
          name: build
      
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
      
      - name: Notify Slack
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: 'デプロイが完了しました'
          webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

#### デプロイフロー

**ブランチ戦略（Git Flow）**:

```
main (本番環境)
  ↑
  merge
  ↑
develop (ステージング環境)
  ↑
  merge
  ↑
feature/* (機能開発)
```

**デプロイ手順**:

1. **開発**: `feature/*` ブランチで開発
2. **プルリクエスト**: `develop` ブランチにPR作成
3. **コードレビュー**: 2名以上の承認が必要
4. **自動テスト**: GitHub Actionsで自動テスト
5. **ステージングデプロイ**: `develop` にマージ後、自動デプロイ
6. **QAテスト**: ステージング環境でQAチームがテスト
7. **本番デプロイ**: `main` にマージ後、自動デプロイ
8. **スモークテスト**: デプロイ後、主要機能の動作確認

#### ブルー・グリーンデプロイメント

**Vercelの自動対応**:
- Vercelは自動的にブルー・グリーンデプロイメントを実施
- 新バージョンをデプロイ後、トラフィックを切り替え
- 問題があれば即座にロールバック可能

**ロールバック手順**:

```bash
# Vercel CLIでロールバック
vercel rollback <deployment-url>

# または、GitHubで前のコミットにrevert
git revert HEAD
git push origin main
```

---

### 6.5 スケーリング戦略

#### 水平スケーリング

**自動スケーリング設定**:

**Vercel（フロントエンド・API）**:
- 自動スケーリング（無制限）
- リージョン: Tokyo（アジア太平洋）
- CDN: グローバル

**Supabase（データベース）**:
- 接続プーリング: PgBouncer（最大1,000接続）
- Read Replica: 読み取り専用レプリカ（必要に応じて追加）

**Cloudflare Workers（エッジ処理）**:
- 自動スケーリング
- 世界中のエッジロケーションで実行

#### 垂直スケーリング

**データベース**:

| プラン | vCPU | RAM | ストレージ | 接続数 | 月額 |
|--------|------|-----|-----------|--------|------|
| Free | 共有 | 500MB | 500MB | 60 | $0 |
| Pro | 2 | 8GB | 50GB | 200 | $25 |
| Team | 4 | 16GB | 100GB | 400 | $599 |
| Enterprise | カスタム | カスタム | カスタム | カスタム | 要相談 |

**スケーリングトリガー**:
- CPU使用率 > 70%が1時間継続
- メモリ使用率 > 80%が1時間継続
- 接続数 > 80%が30分継続

#### キャッシュ戦略

**多層キャッシュ**:

1. **CDNキャッシュ（Cloudflare）**:
   - 静的アセット: 1年
   - APIレスポンス: 1時間
   - パーソナライゼーションルール: 5分

2. **アプリケーションキャッシュ（Redis）**:
   - セッション: 24時間
   - ユーザープロファイル: 1時間
   - 実験設定: 5分

3. **データベースキャッシュ（PostgreSQL）**:
   - クエリ結果キャッシュ: 自動

**実装例**:

```javascript
const Redis = require('ioredis');
const redis = new Redis(process.env.REDIS_URL);

async function getCachedOrFetch(key, fetchFn, ttl = 3600) {
  // キャッシュから取得を試みる
  const cached = await redis.get(key);
  if (cached) {
    return JSON.parse(cached);
  }
  
  // キャッシュになければ、データを取得
  const data = await fetchFn();
  
  // キャッシュに保存
  await redis.setex(key, ttl, JSON.stringify(data));
  
  return data;
}

// 使用例
const userProfile = await getCachedOrFetch(
  `user:${userId}`,
  () => fetchUserFromDB(userId),
  3600 // 1時間
);
```

---

### 6.6 インシデント対応

#### インシデントレベル

| レベル | 定義 | 対応時間 | 担当 |
|--------|------|---------|------|
| P0 (Critical) | サービス全体停止 | 15分以内 | 全エンジニア |
| P1 (High) | 主要機能停止 | 1時間以内 | オンコールエンジニア |
| P2 (Medium) | 一部機能に影響 | 4時間以内 | 担当チーム |
| P3 (Low) | 軽微な問題 | 1営業日以内 | 担当チーム |

#### オンコール体制

**ローテーション**:
- 1週間交代
- プライマリ + セカンダリ（バックアップ）
- PagerDutyで自動通知

**オンコール報酬**:
- 平日夜間・休日: 時給+50%
- 実際の対応時間に応じて支払い

#### インシデント対応フロー

```
1. インシデント検知
   ↓
2. レベル判定（P0-P3）
   ↓
3. 担当者にアラート
   ↓
4. 初期対応（15分以内）
   ↓
5. 原因調査
   ↓
6. 修正・復旧
   ↓
7. 動作確認
   ↓
8. ポストモーテム作成
   ↓
9. 再発防止策の実施
```

#### ポストモーテムテンプレート

```markdown
# インシデントレポート

## 概要
- **発生日時**: 2025-10-20 14:30 JST
- **検知日時**: 2025-10-20 14:32 JST
- **復旧日時**: 2025-10-20 15:15 JST
- **影響時間**: 45分
- **レベル**: P1
- **影響範囲**: 全ユーザー、パーソナライゼーション機能

## 何が起きたか
Cloudflare Workersのデプロイ時にエラーが発生し、パーソナライゼーション機能が停止した。

## 影響
- 影響を受けたユーザー数: 約5,000人
- 失われたコンバージョン: 推定23件
- 金額的損失: 約115,000円

## タイムライン
- 14:30 - 新バージョンをデプロイ
- 14:32 - アラート発生（エラー率急増）
- 14:35 - オンコールエンジニアが対応開始
- 14:40 - 原因特定（環境変数の設定ミス）
- 14:50 - 修正版をデプロイ
- 15:00 - 動作確認
- 15:15 - 完全復旧を確認

## 根本原因
デプロイスクリプトで環境変数の設定が漏れていた。

## 解決策
環境変数を修正し、再デプロイした。

## 再発防止策
1. デプロイ前チェックリストに環境変数確認を追加
2. ステージング環境でのテストを必須化
3. カナリアデプロイメントの導入（10% → 50% → 100%）
4. 環境変数の自動検証スクリプトを作成

## 学んだこと
- デプロイ前の確認が不十分だった
- ステージング環境でのテストが形骸化していた
- ロールバック手順が明確でなかった
```

---

### 6.7 ドキュメント管理

#### ドキュメントの種類

**1. 技術ドキュメント**:
- アーキテクチャ設計書
- API仕様書（OpenAPI/Swagger）
- データベーススキーマ
- デプロイ手順書

**2. 運用ドキュメント**:
- 監視・アラート設定
- インシデント対応手順
- バックアップ・復元手順
- オンコール手順

**3. ユーザードキュメント**:
- ユーザーガイド
- チュートリアル動画
- FAQ
- API利用ガイド

#### ドキュメント管理ツール

**採用**: Notion

**構成**:
```
Japanese AI CRO Tool
├── 📚 技術ドキュメント
│   ├── アーキテクチャ
│   ├── API仕様
│   ├── データベース
│   └── デプロイ
├── 🛠️ 運用ドキュメント
│   ├── 監視・アラート
│   ├── インシデント対応
│   ├── バックアップ
│   └── オンコール
├── 👥 ユーザードキュメント
│   ├── ユーザーガイド
│   ├── チュートリアル
│   ├── FAQ
│   └── API利用ガイド
└── 📝 議事録・決定事項
    ├── 週次ミーティング
    ├── 技術的意思決定
    └── ポストモーテム
```

#### ドキュメント更新ルール

- **技術ドキュメント**: コード変更時に必ず更新
- **運用ドキュメント**: インシデント後に見直し
- **ユーザードキュメント**: 機能リリース時に更新
- **レビュー**: 四半期ごとに全ドキュメントをレビュー

---

## まとめ

### 運用・保守戦略の決定事項

#### 6.1 監視とアラート
- **監視ツール**: Datadog/Grafana、Sentry、Better Stack、UptimeRobot
- **監視対象**: インフラ、アプリケーション、ビジネスメトリクス
- **アラート**: Slack通知、PagerDuty（重大時）

#### 6.2 ログ管理
- **ログレベル**: ERROR、WARN、INFO、DEBUG、TRACE
- **フォーマット**: JSON構造化ログ
- **保持期間**: 30日（通常）、90日（エラー）、365日（監査）

#### 6.3 バックアップ
- **データベース**: 毎日自動バックアップ、S3に保存
- **保持期間**: 日次7日、週次4週、月次12ヶ月
- **復元テスト**: 月1回実施

#### 6.4 デプロイ
- **CI/CD**: GitHub Actions
- **ブランチ戦略**: Git Flow
- **デプロイ方式**: ブルー・グリーンデプロイメント
- **ロールバック**: 即座に可能

#### 6.5 スケーリング
- **水平**: 自動スケーリング（Vercel、Cloudflare Workers）
- **垂直**: CPU/メモリ使用率に応じてプラン変更
- **キャッシュ**: CDN、Redis、PostgreSQL（3層）

#### 6.6 インシデント対応
- **レベル**: P0-P3（4段階）
- **オンコール**: 1週間ローテーション
- **ポストモーテム**: 全P0/P1インシデントで作成

#### 6.7 ドキュメント
- **管理**: Notion
- **種類**: 技術、運用、ユーザー
- **更新**: コード変更時、四半期レビュー

---

次は**7. セキュリティ詳細**に進みます。

