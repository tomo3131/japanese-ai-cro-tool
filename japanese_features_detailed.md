# 日本語特化機能詳細設計書

## 4. 日本語特化機能の詳細

### 4.1 形態素解析エンジン

#### 採用ライブラリ

**MeCab + NEologd辞書**

**選定理由**:
- 高速（1秒あたり数万文字処理可能）
- 高精度（最新の固有名詞、ネット用語に対応）
- オープンソース（商用利用可能）
- Node.js、Pythonで利用可能

**代替案**:
- Kuromoji（JavaScript実装、ブラウザで動作）
- Janome（Pure Python、インストール簡単）
- SudachiPy（複数粒度の分割、新語対応）

**最終選定**: MeCab + NEologd（サーバーサイド）+ Kuromoji（クライアントサイド）

#### インストール・設定

**サーバーサイド（Node.js）**:
```bash
# MeCabインストール
apt-get install mecab libmecab-dev mecab-ipadic-utf8

# NEologd辞書インストール
git clone --depth 1 https://github.com/neologd/mecab-ipadic-neologd.git
cd mecab-ipadic-neologd
./bin/install-mecab-ipadic-neologd -n -y

# Node.jsバインディング
npm install mecab-async
```

**使用例**:
```javascript
const MeCab = require('mecab-async');
const mecab = new MeCab();

mecab.parse('今すぐ無料トライアルを始めましょう', (err, result) => {
  console.log(result);
  // [
  //   ['今', '名詞', '副詞可能', ...],
  //   ['すぐ', '副詞', '助詞類接続', ...],
  //   ['無料', '名詞', '形容動詞語幹', ...],
  //   ['トライアル', '名詞', '一般', ...],
  //   ['を', '助詞', '格助詞', ...],
  //   ['始め', '動詞', '自立', ...],
  //   ['ましょ', '助動詞', '', ...],
  //   ['う', '助動詞', '', ...]
  // ]
});
```

#### 形態素解析の用途

##### 1. キーワード抽出

**目的**: ページ内の重要キーワードを自動抽出

**実装**:
```javascript
function extractKeywords(text) {
  return mecab.parseSync(text)
    .filter(token => {
      const pos = token[1]; // 品詞
      // 名詞、動詞、形容詞のみ抽出
      return pos === '名詞' || pos === '動詞' || pos === '形容詞';
    })
    .map(token => token[0]) // 表層形
    .filter(word => word.length > 1) // 1文字除外
    .reduce((acc, word) => {
      acc[word] = (acc[word] || 0) + 1; // 出現回数カウント
      return acc;
    }, {});
}

// 使用例
const keywords = extractKeywords('無料トライアルで今すぐ始めましょう。簡単に始められます。');
// { '無料': 1, 'トライアル': 1, '今': 1, '始め': 2, '簡単': 1 }
```

**活用シーン**:
- パーソナライゼーションルールの自動提案
- A/Bテストの仮説生成
- ページ内容の自動分類

##### 2. 意図推定

**目的**: ユーザーの検索意図を推定

**実装**:
```javascript
const intentPatterns = {
  purchase: ['購入', '買う', '注文', 'カート', '決済'],
  inquiry: ['問い合わせ', '相談', '質問', '連絡'],
  trial: ['無料', 'トライアル', 'お試し', '体験'],
  comparison: ['比較', '違い', 'おすすめ', 'ランキング'],
  information: ['とは', '方法', 'やり方', '使い方']
};

function estimateIntent(text) {
  const tokens = mecab.parseSync(text).map(t => t[0]);
  const scores = {};
  
  for (const [intent, patterns] of Object.entries(intentPatterns)) {
    scores[intent] = patterns.filter(p => tokens.includes(p)).length;
  }
  
  // 最もスコアの高い意図を返す
  return Object.keys(scores).reduce((a, b) => 
    scores[a] > scores[b] ? a : b
  );
}

// 使用例
estimateIntent('無料トライアルの始め方');
// → 'trial'
```

**活用シーン**:
- 検索キーワードに応じたコンテンツ出し分け
- ランディングページの自動最適化

##### 3. 文章の難易度分析

**目的**: 文章の読みやすさを評価

**実装**:
```javascript
function analyzeReadability(text) {
  const tokens = mecab.parseSync(text);
  
  // 漢字の割合
  const kanjiRatio = tokens.filter(t => /[\u4e00-\u9faf]/.test(t[0])).length / tokens.length;
  
  // 平均文字数
  const avgLength = text.length / (text.match(/[。！？]/g) || []).length;
  
  // カタカナ語の割合
  const katakanaRatio = tokens.filter(t => /[\u30a0-\u30ff]/.test(t[0])).length / tokens.length;
  
  return {
    kanjiRatio,
    avgLength,
    katakanaRatio,
    difficulty: kanjiRatio > 0.3 || avgLength > 50 ? 'hard' : 'easy'
  };
}
```

**活用シーン**:
- ターゲット層に応じた文章の自動調整
- A/Bテストでの文章難易度の比較

---

### 4.2 敬語レベルの自動調整

#### 敬語レベルの定義

**3段階の敬語レベル**:

| レベル | 名称 | 特徴 | 対象 |
|--------|------|------|------|
| 1 | カジュアル | 「だ・である」調、親しみやすい | 若年層、B2C |
| 2 | 丁寧語 | 「です・ます」調、標準的 | 一般消費者、B2C |
| 3 | 尊敬語 | 「いたします」「ございます」、格式高い | 高齢層、B2B、金融 |

#### 変換ルール

**1. カジュアル → 丁寧語**

| カジュアル | 丁寧語 |
|-----------|--------|
| 〜だ | 〜です |
| 〜である | 〜です |
| 〜する | 〜します |
| 〜だった | 〜でした |
| 〜ない | 〜ません |
| 〜しよう | 〜しましょう |

**実装**:
```javascript
function casualToPolite(text) {
  const rules = [
    [/だ([。！？\n])/g, 'です$1'],
    [/である([。！？\n])/g, 'です$1'],
    [/する([。！？\n])/g, 'します$1'],
    [/だった([。！？\n])/g, 'でした$1'],
    [/ない([。！？\n])/g, 'ません$1'],
    [/しよう([。！？\n])/g, 'しましょう$1']
  ];
  
  let result = text;
  for (const [pattern, replacement] of rules) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

// 使用例
casualToPolite('今すぐ始めよう。簡単だ。');
// → '今すぐ始めましょう。簡単です。'
```

**2. 丁寧語 → 尊敬語**

| 丁寧語 | 尊敬語 |
|--------|--------|
| 〜します | 〜いたします |
| 〜です | 〜でございます |
| 〜あります | 〜ございます |
| 〜できます | 〜いただけます |
| お客様 | お客様 |

**実装**:
```javascript
function politeToHonorific(text) {
  const rules = [
    [/します([。！？\n])/g, 'いたします$1'],
    [/です([。！？\n])/g, 'でございます$1'],
    [/あります([。！？\n])/g, 'ございます$1'],
    [/できます([。！？\n])/g, 'いただけます$1'],
    [/ご利用/g, 'ご利用'],
    [/お問い合わせ/g, 'お問い合わせ']
  ];
  
  let result = text;
  for (const [pattern, replacement] of rules) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

// 使用例
politeToHonorific('無料でご利用できます。');
// → '無料でご利用いただけます。'
```

#### 自動判定

**ページコンテキストから敬語レベルを自動判定**

**判定基準**:
```javascript
function detectPolitenessLevel(pageContext) {
  const { industry, targetAge, pageType } = pageContext;
  
  // 業界別
  if (['finance', 'insurance', 'legal'].includes(industry)) {
    return 3; // 尊敬語
  }
  
  // 年齢層別
  if (targetAge === 'senior') {
    return 3; // 尊敬語
  } else if (targetAge === 'young') {
    return 1; // カジュアル
  }
  
  // ページタイプ別
  if (pageType === 'corporate') {
    return 3; // 尊敬語
  } else if (pageType === 'campaign') {
    return 1; // カジュアル
  }
  
  return 2; // デフォルトは丁寧語
}
```

#### ユーザー設定

**ダッシュボードで手動設定可能**

```javascript
// パーソナライゼーションルール設定
{
  ruleId: 'rule_001',
  segment: {
    ageGroup: 'senior'
  },
  contentVariations: {
    politenessLevel: 3, // 尊敬語
    text: {
      'h1.hero-title': {
        original: '今すぐ始めよう',
        adjusted: '今すぐ始めましょう' // 自動変換
      }
    }
  }
}
```

---

### 4.3 商習慣対応

#### 価格表示

**税込/税抜の自動変換**

**実装**:
```javascript
function convertPriceDisplay(price, taxRate = 0.1, displayType = 'tax_included') {
  const taxIncluded = Math.floor(price * (1 + taxRate));
  const taxExcluded = price;
  
  if (displayType === 'tax_included') {
    return `${taxIncluded.toLocaleString()}円（税込）`;
  } else if (displayType === 'tax_excluded') {
    return `${taxExcluded.toLocaleString()}円（税抜）`;
  } else if (displayType === 'both') {
    return `${taxIncluded.toLocaleString()}円（税込）/ ${taxExcluded.toLocaleString()}円（税抜）`;
  }
}

// 使用例
convertPriceDisplay(10000, 0.1, 'tax_included');
// → '11,000円（税込）'
```

**自動検出と変換**:
```javascript
function detectAndConvertPrices(html) {
  // 価格パターンを検出
  const pricePattern = /(\d{1,3}(,\d{3})*|\d+)円/g;
  
  return html.replace(pricePattern, (match, price) => {
    const numPrice = parseInt(price.replace(/,/g, ''));
    return convertPriceDisplay(numPrice, 0.1, 'tax_included');
  });
}

// 使用例
detectAndConvertPrices('<p>月額10000円でご利用いただけます</p>');
// → '<p>月額11,000円（税込）でご利用いただけます</p>'
```

#### 送料無料の強調

**「送料無料」の自動挿入**

**実装**:
```javascript
function emphasizeFreeShipping(html, conditions = {}) {
  const { minPurchase = 0, regions = 'all' } = conditions;
  
  let badge = '<span class="free-shipping-badge">送料無料</span>';
  
  if (minPurchase > 0) {
    badge = `<span class="free-shipping-badge">${minPurchase.toLocaleString()}円以上で送料無料</span>`;
  }
  
  if (regions !== 'all') {
    badge += `<span class="free-shipping-note">（${regions}のみ）</span>`;
  }
  
  // 価格表示の近くに挿入
  return html.replace(
    /(<span class="price">.*?<\/span>)/,
    `$1 ${badge}`
  );
}
```

**CSS**:
```css
.free-shipping-badge {
  display: inline-block;
  background-color: #10B981;
  color: white;
  padding: 4px 12px;
  border-radius: 4px;
  font-size: 14px;
  font-weight: bold;
  margin-left: 8px;
}
```

#### ポイント還元

**ポイント還元率の表示**

**実装**:
```javascript
function addPointsDisplay(price, pointRate = 0.01) {
  const points = Math.floor(price * pointRate);
  
  return `
    <div class="price-with-points">
      <span class="price">${price.toLocaleString()}円（税込）</span>
      <span class="points">+${points}ポイント還元</span>
    </div>
  `;
}

// 使用例
addPointsDisplay(10000, 0.05);
// → 10,000円（税込） +500ポイント還元
```

#### 決済方法

**日本で一般的な決済方法の表示**

**対応決済方法**:
```javascript
const paymentMethods = {
  credit_card: { name: 'クレジットカード', icon: '💳' },
  convenience_store: { name: 'コンビニ決済', icon: '🏪' },
  bank_transfer: { name: '銀行振込', icon: '🏦' },
  cash_on_delivery: { name: '代金引換', icon: '📦' },
  carrier_billing: { name: 'キャリア決済', icon: '📱' },
  paypay: { name: 'PayPay', icon: '💰' },
  rakuten_pay: { name: '楽天ペイ', icon: '🛒' },
  line_pay: { name: 'LINE Pay', icon: '💚' }
};

function displayPaymentMethods(enabledMethods) {
  return `
    <div class="payment-methods">
      <h3>お支払い方法</h3>
      <ul>
        ${enabledMethods.map(method => `
          <li>
            <span class="icon">${paymentMethods[method].icon}</span>
            <span class="name">${paymentMethods[method].name}</span>
          </li>
        `).join('')}
      </ul>
    </div>
  `;
}
```

#### 配送オプション

**日本の配送習慣に対応**

**実装**:
```javascript
const deliveryOptions = [
  { id: 'standard', name: '通常配送', days: '3-5日', price: 500 },
  { id: 'express', name: '速達', days: '1-2日', price: 1000 },
  { id: 'same_day', name: '当日配送', days: '当日', price: 1500 },
  { id: 'time_specified', name: '時間指定', days: '3-5日', price: 700 },
  { id: 'pickup', name: '店舗受取', days: '翌日〜', price: 0 }
];

function displayDeliveryOptions(options) {
  return `
    <div class="delivery-options">
      <h3>配送方法</h3>
      ${options.map(opt => `
        <label class="delivery-option">
          <input type="radio" name="delivery" value="${opt.id}">
          <div class="option-details">
            <span class="name">${opt.name}</span>
            <span class="days">${opt.days}</span>
            <span class="price">${opt.price === 0 ? '無料' : opt.price + '円'}</span>
          </div>
        </label>
      `).join('')}
    </div>
  `;
}
```

#### 年号表示

**西暦と和暦の併記**

**実装**:
```javascript
function convertToJapaneseEra(date) {
  const year = date.getFullYear();
  const month = date.getMonth() + 1;
  const day = date.getDate();
  
  let era, eraYear;
  
  if (year >= 2019 && (year > 2019 || month >= 5)) {
    era = '令和';
    eraYear = year - 2018;
  } else if (year >= 1989) {
    era = '平成';
    eraYear = year - 1988;
  } else {
    era = '昭和';
    eraYear = year - 1925;
  }
  
  return `${year}年（${era}${eraYear}年）${month}月${day}日`;
}

// 使用例
convertToJapaneseEra(new Date('2025-10-20'));
// → '2025年（令和7年）10月20日'
```

---

### 4.4 日本語表示崩れ検知

#### 検知対象

**1. 文字化け**
- 文字コードの不一致
- 絵文字の表示崩れ

**2. 改行・折り返し**
- 英単語の途中で改行
- 禁則処理の違反

**3. フォント**
- 日本語フォントが適用されていない
- 文字が豆腐（□）になっている

#### 実装

**文字化け検知**:
```javascript
function detectMojibake(text) {
  // 文字化けパターン
  const mojibakePatterns = [
    /[�]/g,  // 置換文字
    /[\u0000-\u001F]/g,  // 制御文字
    /[�]/g  // 不明な文字
  ];
  
  for (const pattern of mojibakePatterns) {
    if (pattern.test(text)) {
      return {
        detected: true,
        type: 'mojibake',
        message: '文字化けが検出されました'
      };
    }
  }
  
  return { detected: false };
}
```

**禁則処理違反検知**:
```javascript
function detectLineBreakViolations(html) {
  const violations = [];
  
  // 行頭禁則文字
  const gyotoKinsoku = ['、', '。', '）', '」', '』', '！', '？', 'ー'];
  
  // 行末禁則文字
  const gyomatsuKinsoku = ['（', '「', '『'];
  
  // HTMLをパース
  const lines = html.split('<br>');
  
  lines.forEach((line, index) => {
    // 行頭チェック
    if (gyotoKinsoku.some(char => line.trim().startsWith(char))) {
      violations.push({
        line: index + 1,
        type: 'gyoto_kinsoku',
        char: line.trim()[0]
      });
    }
    
    // 行末チェック
    if (gyomatsuKinsoku.some(char => line.trim().endsWith(char))) {
      violations.push({
        line: index + 1,
        type: 'gyomatsu_kinsoku',
        char: line.trim().slice(-1)
      });
    }
  });
  
  return violations;
}
```

**フォント検証**:
```javascript
// クライアントサイドで実行
function detectFontIssues() {
  const testText = 'あいうえお漢字';
  const canvas = document.createElement('canvas');
  const ctx = canvas.getContext('2d');
  
  // 日本語フォントで描画
  ctx.font = '16px "Noto Sans JP", sans-serif';
  const width1 = ctx.measureText(testText).width;
  
  // フォールバックフォントで描画
  ctx.font = '16px sans-serif';
  const width2 = ctx.measureText(testText).width;
  
  // 幅が大きく異なる場合、日本語フォントが適用されていない
  if (Math.abs(width1 - width2) > 10) {
    return {
      detected: true,
      type: 'font_not_applied',
      message: '日本語フォントが正しく適用されていません'
    };
  }
  
  return { detected: false };
}
```

#### 自動修正

**禁則処理の自動修正**:
```javascript
function applyKinsokuShori(html) {
  // CSSで禁則処理を適用
  return `
    <style>
      .kinsoku-applied {
        word-break: keep-all;
        overflow-wrap: break-word;
        line-break: strict;
      }
    </style>
    <div class="kinsoku-applied">
      ${html}
    </div>
  `;
}
```

---

### 4.5 日本の広告プラットフォーム統合

#### 対応プラットフォーム

**1. Google広告**
- 既に対応済み（グローバル）

**2. Yahoo!広告**
- Yahoo! Search Ads
- Yahoo! Display Ads (YDA)

**3. LINE広告**
- LINE Ads Platform

**4. 楽天広告**
- 楽天市場広告
- Rakuten Marketing

**5. Facebook/Instagram広告**
- Meta広告（日本向け最適化）

#### Yahoo!広告連携

**実装**:
```javascript
// Yahoo!広告のUTMパラメータ検出
function detectYahooAds(urlParams) {
  const source = urlParams.get('utm_source');
  const medium = urlParams.get('utm_medium');
  
  if (source === 'yahoo' || medium === 'cpc') {
    return {
      platform: 'yahoo_ads',
      campaign: urlParams.get('utm_campaign'),
      adGroup: urlParams.get('utm_content'),
      keyword: urlParams.get('utm_term')
    };
  }
  
  return null;
}

// Yahoo!広告専用のパーソナライゼーション
function personalizeForYahooAds(adData) {
  return {
    headline: `${adData.keyword}をお探しですか？`,
    cta: '今すぐ詳細を見る',
    urgency: '期間限定キャンペーン実施中'
  };
}
```

#### LINE広告連携

**実装**:
```javascript
// LINE広告のパラメータ検出
function detectLineAds(urlParams) {
  const source = urlParams.get('utm_source');
  
  if (source === 'line' || source === 'line_ads') {
    return {
      platform: 'line_ads',
      campaign: urlParams.get('utm_campaign'),
      creative: urlParams.get('utm_content')
    };
  }
  
  return null;
}

// LINE広告専用のパーソナライゼーション
function personalizeForLineAds(adData) {
  return {
    headline: 'LINEをご覧いただきありがとうございます',
    cta: 'LINE友だち追加で特典GET',
    social_proof: 'すでに10万人が利用中'
  };
}
```

---

### 4.6 日本語キーワード意図推定

#### 意図カテゴリ

**日本語特有の検索意図**:

| カテゴリ | キーワード例 | 意図 |
|---------|-------------|------|
| 情報収集 | 「〜とは」「〜方法」「〜やり方」 | 情報を求めている |
| 比較検討 | 「〜比較」「〜おすすめ」「〜ランキング」 | 複数の選択肢を比較 |
| 購入意向 | 「〜購入」「〜買う」「〜通販」 | 購入を検討中 |
| 口コミ | 「〜口コミ」「〜評判」「〜レビュー」 | 他者の意見を求めている |
| トラブル | 「〜できない」「〜エラー」「〜解決」 | 問題を抱えている |

#### 実装

```javascript
const intentKeywords = {
  information: ['とは', '方法', 'やり方', '使い方', '意味', '仕組み'],
  comparison: ['比較', 'おすすめ', 'ランキング', '違い', 'どっち'],
  purchase: ['購入', '買う', '通販', '価格', '最安値', '激安'],
  review: ['口コミ', '評判', 'レビュー', '感想', '体験談'],
  trouble: ['できない', 'エラー', '解決', '対処法', '原因']
};

function estimateSearchIntent(keyword) {
  for (const [intent, patterns] of Object.entries(intentKeywords)) {
    if (patterns.some(pattern => keyword.includes(pattern))) {
      return intent;
    }
  }
  return 'general';
}

// 意図別のコンテンツ最適化
function optimizeContentByIntent(intent) {
  const strategies = {
    information: {
      headline: '【完全ガイド】',
      content: '詳しい説明、図解、ステップバイステップ',
      cta: '詳細を見る'
    },
    comparison: {
      headline: '【徹底比較】',
      content: '比較表、メリット・デメリット',
      cta: 'ランキングを見る'
    },
    purchase: {
      headline: '【最安値】',
      content: '価格、送料無料、ポイント還元',
      cta: '今すぐ購入'
    },
    review: {
      headline: '【利用者の声】',
      content: '口コミ、評価、体験談',
      cta: 'レビューを見る'
    },
    trouble: {
      headline: '【解決方法】',
      content: 'トラブルシューティング、FAQ',
      cta: 'サポートに問い合わせ'
    }
  };
  
  return strategies[intent] || strategies.information;
}
```

---

## まとめ

### 日本語特化機能の決定事項

#### 4.1 形態素解析
- **エンジン**: MeCab + NEologd（サーバー）、Kuromoji（クライアント）
- **用途**: キーワード抽出、意図推定、難易度分析

#### 4.2 敬語調整
- **3段階**: カジュアル、丁寧語、尊敬語
- **自動判定**: 業界、年齢層、ページタイプから判定
- **変換ルール**: 正規表現ベース、MeCabで品詞解析

#### 4.3 商習慣対応
- **価格表示**: 税込/税抜自動変換
- **送料無料**: 自動強調表示
- **ポイント還元**: 還元率表示
- **決済方法**: 日本の主要8種対応
- **配送**: 時間指定、店舗受取対応
- **年号**: 西暦+和暦併記

#### 4.4 表示崩れ検知
- **文字化け**: 自動検出
- **禁則処理**: 違反検出と自動修正
- **フォント**: Canvas APIで検証

#### 4.5 広告連携
- **対応**: Google、Yahoo!、LINE、楽天、Meta
- **パーソナライゼーション**: プラットフォーム別最適化

#### 4.6 意図推定
- **5カテゴリ**: 情報収集、比較検討、購入意向、口コミ、トラブル
- **最適化**: 意図別コンテンツ戦略

---

次は**5. AI機能の詳細**（LLM選定、仮説生成、統計分析）に進みますか？

