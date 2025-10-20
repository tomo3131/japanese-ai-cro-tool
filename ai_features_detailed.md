# AI機能詳細設計書

## 5. AI機能の詳細

### 5.1 LLM選定

#### 採用モデル

**プライマリ: Google Gemini 2.0 Flash**

**選定理由**:
1. **コストパフォーマンス**: GPT-4より安価（入力$0.075/1M tokens、出力$0.30/1M tokens）
2. **速度**: 高速応答（平均1-2秒）
3. **日本語性能**: 優れた日本語理解・生成能力
4. **マルチモーダル**: 画像、動画も処理可能（将来の機能拡張に対応）
5. **長文コンテキスト**: 最大100万トークン（ページ全体を解析可能）
6. **API安定性**: Google Cloudの信頼性

**セカンダリ: GPT-4.1 Mini**

**用途**: Geminiがダウンした場合のフォールバック

**コスト比較**:

| モデル | 入力（1M tokens） | 出力（1M tokens） | 速度 | 日本語 |
|--------|------------------|------------------|------|--------|
| Gemini 2.0 Flash | $0.075 | $0.30 | ⚡⚡⚡ | ⭐⭐⭐ |
| GPT-4.1 Mini | $0.15 | $0.60 | ⚡⚡ | ⭐⭐⭐ |
| GPT-4.1 | $5.00 | $15.00 | ⚡ | ⭐⭐⭐ |
| Claude 3.5 Sonnet | $3.00 | $15.00 | ⚡⚡ | ⭐⭐ |

#### API実装

**Gemini API（google-genai SDK）**:

```javascript
import { GoogleGenerativeAI } from '@google/generative-ai';

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function generateHypothesis(pageData) {
  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' });
  
  const prompt = `
あなたはCRO（コンバージョン率最適化）の専門家です。
以下のランディングページを分析し、A/Bテストの仮説を3つ提案してください。

【ページ情報】
URL: ${pageData.url}
業界: ${pageData.industry}
目標: ${pageData.goal}
現在のCVR: ${pageData.currentCVR}%

【ページコンテンツ】
${pageData.content}

【要件】
1. 各仮説には、変更箇所、期待される効果、優先度を含めてください
2. 日本の商習慣を考慮してください
3. 統計的に検証可能な仮説にしてください

JSON形式で出力してください。
`;

  const result = await model.generateContent(prompt);
  const response = await result.response;
  const text = response.text();
  
  return JSON.parse(text);
}
```

**フォールバック実装**:

```javascript
async function generateWithFallback(pageData) {
  try {
    // Geminiを試す
    return await generateHypothesis(pageData);
  } catch (error) {
    console.error('Gemini failed, falling back to GPT-4.1 Mini', error);
    
    try {
      // GPT-4.1 Miniにフォールバック
      return await generateHypothesisGPT(pageData);
    } catch (fallbackError) {
      console.error('All LLMs failed', fallbackError);
      throw new Error('AI仮説生成に失敗しました');
    }
  }
}
```

#### コスト管理

**月間コスト予測**:

**想定**:
- プロフェッショナルプラン以上のユーザー: 50社
- 1社あたり月10回の仮説生成
- 1回あたり入力10,000トークン、出力2,000トークン

**計算**:
```
入力: 50社 × 10回 × 10,000トークン = 5,000,000トークン = 5M
出力: 50社 × 10回 × 2,000トークン = 1,000,000トークン = 1M

コスト:
入力: 5M × $0.075 = $0.375
出力: 1M × $0.30 = $0.30
合計: $0.675/月 ≈ 100円/月
```

**コスト制限**:
- プランごとに月間生成回数を制限
- スタータープラン: 0回（機能なし）
- プロフェッショナルプラン: 10回/月
- エンタープライズプラン: 無制限

**実装**:
```javascript
async function checkAIQuota(organizationId, plan) {
  const usage = await getMonthlyAIUsage(organizationId);
  
  const limits = {
    starter: 0,
    professional: 10,
    enterprise: Infinity
  };
  
  if (usage >= limits[plan]) {
    throw new Error('AI仮説生成の月間上限に達しました。プランをアップグレードしてください。');
  }
  
  return true;
}
```

---

### 5.2 AI仮説生成

#### 仮説生成のフロー

```
1. ページデータ収集
   ↓
2. コンテキスト分析（業界、目標、現状）
   ↓
3. LLMにプロンプト送信
   ↓
4. 仮説候補を3-5個生成
   ↓
5. 各仮説に優先度スコアリング
   ↓
6. ユーザーに提示
```

#### プロンプト設計

**システムプロンプト**:
```
あなたは日本市場に精通したCRO（コンバージョン率最適化）の専門家です。
以下の原則に従って仮説を生成してください：

1. **MECE（Mutually Exclusive, Collectively Exhaustive）**: 仮説は相互に排他的で、全体を網羅する
2. **検証可能性**: 統計的に検証可能な仮説のみ提案
3. **実装可能性**: 技術的に実装可能な変更のみ提案
4. **日本の商習慣**: 税込価格、送料無料、ポイント還元などを考慮
5. **心理学的根拠**: 社会的証明、希少性、権威性などの原則を活用

出力形式はJSON配列で、以下の構造に従ってください：
[
  {
    "id": "hypothesis_1",
    "title": "仮説のタイトル",
    "description": "仮説の詳細説明",
    "change": {
      "element": "変更する要素（例: CTAボタン）",
      "from": "現在の状態",
      "to": "変更後の状態"
    },
    "rationale": "なぜこの変更が効果的か（心理学的根拠）",
    "expectedImpact": "期待される効果（例: CVR +15%）",
    "priority": "high|medium|low",
    "difficulty": "easy|medium|hard",
    "estimatedDuration": "推奨テスト期間（日数）"
  }
]
```

**ユーザープロンプト（例）**:
```
【ページ情報】
URL: https://example.com/lp/campaign
業界: EC（健康食品）
目標: 商品購入
現在のCVR: 2.3%
月間訪問者数: 50,000人

【ページコンテンツ】
見出し: 「今だけ50%OFF！健康サプリメント」
サブ見出し: 「10,000人が愛用中」
CTAボタン: 「今すぐ購入」（青色）
価格: 5,000円（税込5,500円）
送料: 全国一律500円

【課題】
- 離脱率が高い（70%）
- カート追加率は高いが、購入完了率が低い（40%）

【過去のテスト結果】
- CTAボタンを緑色に変更 → CVR +5%（統計的有意差なし）
- 送料無料キャンペーン → CVR +18%（有意差あり）

上記を踏まえ、CVRを改善するA/Bテストの仮説を3つ提案してください。
```

#### 仮説の例

**LLMの出力例**:
```json
[
  {
    "id": "hypothesis_1",
    "title": "送料無料の条件を明確化",
    "description": "「5,000円以上で送料無料」を見出し直下に大きく表示することで、送料への懸念を軽減し、購入完了率を向上させる",
    "change": {
      "element": "送料無料バナー",
      "from": "ページ下部に小さく記載",
      "to": "見出し直下に目立つバッジで表示"
    },
    "rationale": "過去のテストで送料無料が効果的だったことから、この情報をより目立たせることで、カート放棄を減らせる可能性が高い。日本の消費者は送料に敏感であり、送料無料は強力な購買動機となる。",
    "expectedImpact": "CVR +20-25%（購入完了率の改善）",
    "priority": "high",
    "difficulty": "easy",
    "estimatedDuration": 7
  },
  {
    "id": "hypothesis_2",
    "title": "社会的証明の強化",
    "description": "「10,000人が愛用中」を具体的な口コミ・評価に変更し、信頼性を向上させる",
    "change": {
      "element": "社会的証明",
      "from": "「10,000人が愛用中」（抽象的）",
      "to": "「★4.8/5.0（3,245件のレビュー）」+ 顔写真付き口コミ3件"
    },
    "rationale": "抽象的な数字よりも、具体的な評価と実際の利用者の声の方が信頼性が高い。日本の消費者は購入前に口コミを重視する傾向が強い。",
    "expectedImpact": "CVR +10-15%（信頼性向上）",
    "priority": "high",
    "difficulty": "medium",
    "estimatedDuration": 14
  },
  {
    "id": "hypothesis_3",
    "title": "緊急性の追加",
    "description": "「残り在庫わずか」「本日限定」などの緊急性を追加し、即座の購入を促す",
    "change": {
      "element": "緊急性バナー",
      "from": "なし",
      "to": "「残り在庫23個」「本日23:59まで50%OFF」をCTAボタン上に表示"
    },
    "rationale": "希少性と緊急性は強力な心理トリガーであり、「今買わなければ損をする」という感情を喚起する。ただし、過度な使用は信頼性を損なうため注意が必要。",
    "expectedImpact": "CVR +15-20%（緊急性による即決）",
    "priority": "medium",
    "difficulty": "easy",
    "estimatedDuration": 7
  }
]
```

#### 仮説の優先度スコアリング

**スコアリング基準**:
```javascript
function calculatePriorityScore(hypothesis, pageContext) {
  let score = 0;
  
  // 期待される効果（0-40点）
  const impactMatch = hypothesis.expectedImpact.match(/\+(\d+)/);
  if (impactMatch) {
    const impact = parseInt(impactMatch[1]);
    score += Math.min(impact, 40);
  }
  
  // 実装難易度（0-20点、簡単なほど高得点）
  const difficultyScores = { easy: 20, medium: 10, hard: 5 };
  score += difficultyScores[hypothesis.difficulty] || 0;
  
  // 過去の類似テスト結果（0-20点）
  const similarTests = findSimilarTests(hypothesis, pageContext.pastTests);
  if (similarTests.some(t => t.result === 'success')) {
    score += 20;
  }
  
  // 統計的検証可能性（0-20点）
  const requiredSampleSize = calculateSampleSize(
    pageContext.currentCVR,
    hypothesis.expectedImpact
  );
  if (requiredSampleSize < pageContext.monthlyVisitors) {
    score += 20;
  } else if (requiredSampleSize < pageContext.monthlyVisitors * 2) {
    score += 10;
  }
  
  return score; // 0-100点
}
```

---

### 5.3 統計分析

#### A/Bテストの統計手法

**採用手法: ベイズ統計 + 頻度論統計のハイブリッド**

**理由**:
- ベイズ統計: リアルタイムで勝率を計算可能、直感的
- 頻度論統計: 学術的に確立、信頼区間・P値で客観的判断

#### 必要サンプルサイズの計算

**実装**:
```javascript
function calculateSampleSize(baselineCVR, mde, alpha = 0.05, power = 0.8) {
  // mde: Minimum Detectable Effect（最小検出効果）
  // alpha: 有意水準（通常5%）
  // power: 検出力（通常80%）
  
  const z_alpha = 1.96; // 95%信頼区間
  const z_beta = 0.84;  // 80%検出力
  
  const p1 = baselineCVR;
  const p2 = baselineCVR * (1 + mde);
  const p_avg = (p1 + p2) / 2;
  
  const n = Math.ceil(
    2 * Math.pow(z_alpha + z_beta, 2) * p_avg * (1 - p_avg) / Math.pow(p2 - p1, 2)
  );
  
  return n;
}

// 使用例
const sampleSize = calculateSampleSize(0.023, 0.20); // CVR 2.3%、20%改善を検出
// → 約3,800人/バリアント（合計7,600人）
```

#### 統計的有意差の判定

**Z検定（2標本比率の検定）**:

```javascript
function calculateZTest(controlData, variantData) {
  const n1 = controlData.visitors;
  const n2 = variantData.visitors;
  const x1 = controlData.conversions;
  const x2 = variantData.conversions;
  
  const p1 = x1 / n1;
  const p2 = x2 / n2;
  const p_pool = (x1 + x2) / (n1 + n2);
  
  const se = Math.sqrt(p_pool * (1 - p_pool) * (1/n1 + 1/n2));
  const z = (p2 - p1) / se;
  const p_value = 2 * (1 - normalCDF(Math.abs(z)));
  
  return {
    z_score: z,
    p_value: p_value,
    significant: p_value < 0.05,
    confidence: 1 - p_value
  };
}

// 正規分布の累積分布関数
function normalCDF(z) {
  return 0.5 * (1 + erf(z / Math.sqrt(2)));
}

function erf(x) {
  // 誤差関数の近似
  const a1 =  0.254829592;
  const a2 = -0.284496736;
  const a3 =  1.421413741;
  const a4 = -1.453152027;
  const a5 =  1.061405429;
  const p  =  0.3275911;
  
  const sign = x < 0 ? -1 : 1;
  x = Math.abs(x);
  
  const t = 1.0 / (1.0 + p * x);
  const y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t * Math.exp(-x*x);
  
  return sign * y;
}
```

#### 信頼区間の計算

**Wilson Score Interval（推奨）**:

```javascript
function calculateConfidenceInterval(conversions, visitors, confidence = 0.95) {
  const z = confidence === 0.95 ? 1.96 : 2.58; // 95%または99%
  const p = conversions / visitors;
  const n = visitors;
  
  const denominator = 1 + z*z/n;
  const center = (p + z*z/(2*n)) / denominator;
  const margin = z * Math.sqrt((p*(1-p)/n + z*z/(4*n*n))) / denominator;
  
  return {
    lower: center - margin,
    upper: center + margin,
    center: p
  };
}

// 使用例
const ci = calculateConfidenceInterval(100, 4000, 0.95);
// → { lower: 0.0213, upper: 0.0287, center: 0.025 }
// → CVR 2.5% (95%CI: 2.1%-2.9%)
```

#### ベイズ統計による勝率計算

**Beta分布を使用**:

```javascript
function calculateBayesianWinProbability(controlData, variantData, simulations = 10000) {
  // Beta分布からサンプリング
  function betaSample(alpha, beta) {
    // Beta分布のサンプリング（簡易実装）
    const gamma1 = gammaRandom(alpha, 1);
    const gamma2 = gammaRandom(beta, 1);
    return gamma1 / (gamma1 + gamma2);
  }
  
  let variantWins = 0;
  
  for (let i = 0; i < simulations; i++) {
    // 事前分布: Beta(1, 1) = 一様分布
    // 事後分布: Beta(1 + conversions, 1 + failures)
    const controlSample = betaSample(
      1 + controlData.conversions,
      1 + (controlData.visitors - controlData.conversions)
    );
    
    const variantSample = betaSample(
      1 + variantData.conversions,
      1 + (variantData.visitors - variantData.conversions)
    );
    
    if (variantSample > controlSample) {
      variantWins++;
    }
  }
  
  return variantWins / simulations;
}

// 使用例
const winProb = calculateBayesianWinProbability(
  { conversions: 92, visitors: 4000 },
  { conversions: 120, visitors: 4000 }
);
// → 0.98 (98%の確率でバリアントBが優れている)
```

#### 早期停止の判定

**Sequential Testing（逐次検定）**:

```javascript
function shouldStopEarly(controlData, variantData, targetSampleSize) {
  const currentSize = Math.min(controlData.visitors, variantData.visitors);
  const progress = currentSize / targetSampleSize;
  
  // 最低20%のデータが集まるまでは判定しない
  if (progress < 0.2) {
    return { shouldStop: false, reason: 'データ不足' };
  }
  
  // ベイズ統計で勝率を計算
  const winProb = calculateBayesianWinProbability(controlData, variantData);
  
  // 95%以上の確率で勝っている場合、早期停止
  if (winProb > 0.95 || winProb < 0.05) {
    return {
      shouldStop: true,
      reason: '明確な勝者が決定',
      winner: winProb > 0.95 ? 'variant' : 'control',
      confidence: Math.max(winProb, 1 - winProb)
    };
  }
  
  // 目標サンプルサイズに達した場合
  if (progress >= 1.0) {
    const zTest = calculateZTest(controlData, variantData);
    return {
      shouldStop: true,
      reason: '目標サンプルサイズに到達',
      winner: zTest.significant ? (variantData.conversions/variantData.visitors > controlData.conversions/controlData.visitors ? 'variant' : 'control') : 'none',
      confidence: zTest.confidence
    };
  }
  
  return { shouldStop: false, reason: 'テスト継続中' };
}
```

---

### 5.4 AIインサイト生成

#### 実験結果の自動解釈

**プロンプト設計**:
```javascript
async function generateInsights(experimentData) {
  const prompt = `
あなたはCROアナリストです。以下のA/Bテスト結果を分析し、ビジネスインサイトを提供してください。

【実験情報】
実験名: ${experimentData.name}
仮説: ${experimentData.hypothesis}
期間: ${experimentData.duration}日間

【結果】
コントロール（A）:
- 訪問者数: ${experimentData.control.visitors}
- コンバージョン数: ${experimentData.control.conversions}
- CVR: ${experimentData.control.cvr}%

バリアント（B）:
- 訪問者数: ${experimentData.variant.visitors}
- コンバージョン数: ${experimentData.variant.conversions}
- CVR: ${experimentData.variant.cvr}%

改善率: ${experimentData.improvement}%
統計的有意性: ${experimentData.significant ? 'あり（p<0.05）' : 'なし'}
信頼度: ${experimentData.confidence}%

【セグメント別結果】
${JSON.stringify(experimentData.segmentResults, null, 2)}

【要求】
1. 結果の解釈（なぜこの結果になったか）
2. ビジネスへの影響（年間でどれくらいの売上増加が見込めるか）
3. 次のアクション（この結果を受けて何をすべきか）
4. 注意点（結果を過信しないための注意事項）

日本語で、ビジネスパーソンにわかりやすく説明してください。
`;

  const model = genAI.getGenerativeModel({ model: 'gemini-2.0-flash-exp' });
  const result = await model.generateContent(prompt);
  const response = await result.response;
  
  return response.text();
}
```

**出力例**:
```
【結果の解釈】
緑色のCTAボタンは青色よりも20.1%高いCVRを達成しました（統計的有意差あり、p=0.003）。
これは、緑色が「進む」「OK」を連想させる色であり、日本の消費者にとってアクションを促す色として
認識されているためと考えられます。

特に注目すべきは、モバイルユーザーでの改善率が28%と高かったことです。
これは、モバイルの小さな画面では、より目立つ色が重要であることを示唆しています。

【ビジネスへの影響】
現在の月間訪問者数50,000人、CVR 2.3%の場合：
- 現状の月間コンバージョン: 1,150件
- 改善後の月間コンバージョン: 1,381件（+231件）
- 1件あたりの平均購入額が5,000円の場合、月間売上+115.5万円
- 年間売上+1,386万円の増加が見込めます

【次のアクション】
1. バリアントB（緑色ボタン）を全訪問者に適用してください
2. 他のCTAボタン（「カートに追加」「お問い合わせ」など）も緑色に統一することを検討してください
3. モバイルでの効果が高かったため、モバイル専用の最適化を進めてください

【注意点】
- この結果は特定の期間・条件下でのものです。季節変動や外部要因の影響を受ける可能性があります
- 緑色が常に最適とは限りません。ブランドイメージとの整合性も考慮してください
- 継続的にモニタリングし、効果が持続しているか確認してください
```

---

### 5.5 自動学習と適用

#### 勝者の自動適用

**実装**:
```javascript
async function autoApplyWinner(experimentId) {
  const experiment = await getExperiment(experimentId);
  
  // 統計的有意差があるか確認
  const analysis = shouldStopEarly(
    experiment.controlData,
    experiment.variantData,
    experiment.targetSampleSize
  );
  
  if (!analysis.shouldStop || analysis.winner === 'none') {
    throw new Error('まだ勝者が決定していません');
  }
  
  // 勝者をパーソナライゼーションルールとして保存
  const winnerVariant = analysis.winner === 'variant' 
    ? experiment.variants[1] 
    : experiment.variants[0];
  
  const rule = {
    name: `${experiment.name}の勝者を適用`,
    status: 'active',
    urlPattern: experiment.urlPattern,
    segmentConditions: {}, // 全訪問者に適用
    contentVariations: winnerVariant.changes,
    priority: 10,
    source: 'experiment',
    experimentId: experimentId
  };
  
  await createPersonalizationRule(rule);
  
  // 実験を完了状態に
  await updateExperiment(experimentId, {
    status: 'completed',
    winnerVariantId: winnerVariant.id,
    completedAt: new Date()
  });
  
  return rule;
}
```

#### 学習データの蓄積

**実装**:
```javascript
// 完了した実験から学習データを抽出
async function extractLearnings(experimentId) {
  const experiment = await getExperiment(experimentId);
  const analysis = await analyzeExperiment(experimentId);
  
  const learning = {
    experimentId,
    hypothesis: experiment.hypothesis,
    changeType: classifyChange(experiment.variants[1].changes),
    industry: experiment.site.industry,
    result: analysis.winner === 'variant' ? 'success' : 'failure',
    improvement: analysis.improvement,
    confidence: analysis.confidence,
    segmentInsights: extractSegmentInsights(analysis.segmentResults),
    createdAt: new Date()
  };
  
  await saveLearning(learning);
  
  return learning;
}

// 変更タイプの分類
function classifyChange(changes) {
  const types = [];
  
  if (changes.color) types.push('color');
  if (changes.text) types.push('copy');
  if (changes.image) types.push('image');
  if (changes.layout) types.push('layout');
  if (changes.cta) types.push('cta');
  
  return types;
}
```

#### 類似実験の推薦

**実装**:
```javascript
async function recommendSimilarExperiments(siteId) {
  const site = await getSite(siteId);
  const pastExperiments = await getCompletedExperiments(siteId);
  
  // 同じ業界の成功事例を取得
  const industrySuccesses = await getLearnings({
    industry: site.industry,
    result: 'success',
    confidence: { $gt: 0.95 }
  });
  
  // まだ実施していない変更タイプを抽出
  const testedTypes = pastExperiments.flatMap(e => 
    classifyChange(e.variants[1].changes)
  );
  
  const recommendations = industrySuccesses
    .filter(learning => 
      !learning.changeType.some(type => testedTypes.includes(type))
    )
    .sort((a, b) => b.improvement - a.improvement)
    .slice(0, 5);
  
  return recommendations.map(rec => ({
    hypothesis: rec.hypothesis,
    expectedImprovement: rec.improvement,
    confidence: rec.confidence,
    source: 'industry_best_practice'
  }));
}
```

---

## まとめ

### AI機能の決定事項

#### 5.1 LLM選定
- **プライマリ**: Google Gemini 2.0 Flash
- **セカンダリ**: GPT-4.1 Mini（フォールバック）
- **コスト**: 月間約100円（50社、月10回/社）
- **制限**: プロ10回/月、エンタープライズ無制限

#### 5.2 AI仮説生成
- **出力**: 3-5個の仮説（JSON形式）
- **内容**: 変更箇所、期待効果、優先度、実装難易度
- **スコアリング**: 期待効果、実装難易度、過去実績、検証可能性
- **プロンプト**: システムプロンプト + ユーザープロンプト

#### 5.3 統計分析
- **手法**: ベイズ統計 + 頻度論統計のハイブリッド
- **サンプルサイズ**: Z検定で計算（α=0.05、β=0.2）
- **有意差判定**: Z検定（p<0.05）
- **信頼区間**: Wilson Score Interval
- **勝率**: ベイズ統計（Beta分布）
- **早期停止**: 95%以上の勝率で早期停止

#### 5.4 AIインサイト
- **内容**: 結果解釈、ビジネス影響、次のアクション、注意点
- **出力**: 日本語、ビジネスパーソン向け

#### 5.5 自動学習
- **勝者の自動適用**: パーソナライゼーションルールとして保存
- **学習データ蓄積**: 変更タイプ、業界、結果、改善率
- **類似実験推薦**: 同業界の成功事例から推薦

---

次は**6. 運用・保守、セキュリティ、テスト戦略**の詳細化に進みますか？
それとも、ここまでの要件定義をGitHubに反映して、開発準備を完了させますか？

