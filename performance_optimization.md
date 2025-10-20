# パフォーマンス最適化詳細

## 目標

- **LCP (Largest Contentful Paint)**: 2.5秒以内
- **FID (First Input Delay)**: 100ms以内
- **CLS (Cumulative Layout Shift)**: 0.1以下
- **TTI (Time to Interactive)**: 3.8秒以内
- **SDK読み込み**: 1秒以内

---

## 1. フロントエンド最適化

### 1.1 Next.js設定

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // 画像最適化
  images: {
    formats: ['image/avif', 'image/webp'],
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048, 3840],
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],
    minimumCacheTTL: 60,
    dangerouslyAllowSVG: true,
    contentDispositionType: 'attachment',
    contentSecurityPolicy: "default-src 'self'; script-src 'none'; sandbox;",
  },

  // コンパイラ最適化
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },

  // 実験的機能
  experimental: {
    optimizeCss: true,
    optimizePackageImports: ['@/components', '@/lib'],
  },

  // Webpack設定
  webpack: (config, { isServer, dev }) => {
    // 本番環境でのバンドル最適化
    if (!dev && !isServer) {
      config.optimization = {
        ...config.optimization,
        splitChunks: {
          chunks: 'all',
          cacheGroups: {
            default: false,
            vendors: false,
            
            // フレームワーク（React、Next.js）
            framework: {
              name: 'framework',
              chunks: 'all',
              test: /[\\/]node_modules[\\/](react|react-dom|next)[\\/]/,
              priority: 40,
              enforce: true,
            },
            
            // 共通ライブラリ
            commons: {
              name: 'commons',
              chunks: 'all',
              minChunks: 2,
              priority: 20,
            },
            
            // UIライブラリ
            ui: {
              name: 'ui',
              chunks: 'all',
              test: /[\\/]node_modules[\\/](@radix-ui|@headlessui)[\\/]/,
              priority: 30,
            },
            
            // その他のnode_modules
            lib: {
              test: /[\\/]node_modules[\\/]/,
              name(module) {
                const packageName = module.context.match(
                  /[\\/]node_modules[\\/](.*?)([\\/]|$)/
                )[1];
                return `npm.${packageName.replace('@', '')}`;
              },
              priority: 10,
            },
          },
        },
        minimize: true,
      };
    }

    return config;
  },

  // ヘッダー設定
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=63072000; includeSubDomains; preload',
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin',
          },
        ],
      },
      {
        source: '/static/:path*',
        headers: [
          {
            key: 'Cache-Control',
            value: 'public, max-age=31536000, immutable',
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
```

### 1.2 フォント最適化

```typescript
// app/layout.tsx
import { Noto_Sans_JP } from 'next/font/google';

const notoSansJP = Noto_Sans_JP({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  display: 'swap',
  preload: true,
  variable: '--font-noto-sans-jp',
});

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja" className={notoSansJP.variable}>
      <head>
        {/* DNS Prefetch */}
        <link rel="dns-prefetch" href="https://fonts.googleapis.com" />
        <link rel="dns-prefetch" href="https://fonts.gstatic.com" />
        
        {/* Preconnect */}
        <link rel="preconnect" href="https://fonts.googleapis.com" crossOrigin="anonymous" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
      </head>
      <body className="font-sans">{children}</body>
    </html>
  );
}
```

### 1.3 画像最適化

```typescript
// components/OptimizedImage.tsx
import Image from 'next/image';

interface OptimizedImageProps {
  src: string;
  alt: string;
  width: number;
  height: number;
  priority?: boolean;
}

export function OptimizedImage({ src, alt, width, height, priority = false }: OptimizedImageProps) {
  return (
    <Image
      src={src}
      alt={alt}
      width={width}
      height={height}
      priority={priority}
      loading={priority ? 'eager' : 'lazy'}
      placeholder="blur"
      blurDataURL="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mN8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg=="
      sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
      quality={85}
    />
  );
}
```

### 1.4 コード分割

```typescript
// 動的インポート
import dynamic from 'next/dynamic';

// 重いコンポーネントは動的インポート
const VisualEditor = dynamic(() => import('@/components/VisualEditor'), {
  loading: () => <div>読み込み中...</div>,
  ssr: false, // クライアントサイドのみ
});

const ChartComponent = dynamic(() => import('@/components/Chart'), {
  loading: () => <div>チャート読み込み中...</div>,
});

// 使用例
export default function ExperimentPage() {
  return (
    <div>
      <h1>実験詳細</h1>
      <ChartComponent data={data} />
      <VisualEditor />
    </div>
  );
}
```

### 1.5 遅延読み込み

```typescript
// components/LazySection.tsx
import { useEffect, useRef, useState } from 'react';

export function LazySection({ children }: { children: React.ReactNode }) {
  const [isVisible, setIsVisible] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setIsVisible(true);
          observer.disconnect();
        }
      },
      {
        rootMargin: '100px', // 100px手前で読み込み開始
      }
    );

    if (ref.current) {
      observer.observe(ref.current);
    }

    return () => observer.disconnect();
  }, []);

  return <div ref={ref}>{isVisible ? children : <div style={{ minHeight: '200px' }} />}</div>;
}
```

---

## 2. トラッキングSDK最適化

### 2.1 SDK読み込み

```html
<!-- 非同期読み込み -->
<script>
  (function() {
    var script = document.createElement('script');
    script.src = 'https://cdn.example.com/sdk.js';
    script.async = true;
    script.defer = true;
    
    // Anti-flicker snippet
    var antiFlicker = document.createElement('style');
    antiFlicker.id = 'cro-anti-flicker';
    antiFlicker.innerHTML = 'body { opacity: 0 !important; }';
    document.head.appendChild(antiFlicker);
    
    // 3秒後にAnti-flickerを解除
    setTimeout(function() {
      var style = document.getElementById('cro-anti-flicker');
      if (style) style.remove();
    }, 3000);
    
    script.onload = function() {
      // SDK読み込み完了
      var style = document.getElementById('cro-anti-flicker');
      if (style) style.remove();
      document.body.style.opacity = '1';
    };
    
    document.head.appendChild(script);
  })();
</script>
```

### 2.2 SDK実装（軽量化）

```typescript
// sdk/index.ts
class CROTracker {
  private queue: any[] = [];
  private initialized = false;

  constructor() {
    // イベントをキューに溜める
    this.track = this.track.bind(this);
  }

  async init(config: { siteId: string; apiKey: string }) {
    // 設定を保存
    this.config = config;
    
    // バッチ送信を開始
    this.startBatchSending();
    
    this.initialized = true;
    
    // キューに溜まったイベントを送信
    this.flushQueue();
  }

  track(eventType: string, data?: any) {
    const event = {
      eventType,
      data,
      timestamp: Date.now(),
      url: window.location.href,
      referrer: document.referrer,
    };

    if (this.initialized) {
      this.sendEvent(event);
    } else {
      this.queue.push(event);
    }
  }

  private async sendEvent(event: any) {
    // navigator.sendBeacon を使用（ページ離脱時も確実に送信）
    if (navigator.sendBeacon) {
      const blob = new Blob([JSON.stringify(event)], { type: 'application/json' });
      navigator.sendBeacon('/api/analytics/events', blob);
    } else {
      // フォールバック: fetch
      fetch('/api/analytics/events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(event),
        keepalive: true,
      });
    }
  }

  private startBatchSending() {
    // 10秒ごとにバッチ送信
    setInterval(() => {
      if (this.queue.length > 0) {
        this.flushQueue();
      }
    }, 10000);
  }

  private flushQueue() {
    while (this.queue.length > 0) {
      const event = this.queue.shift();
      this.sendEvent(event);
    }
  }
}

// グローバルに公開
window.CROTracker = new CROTracker();
```

---

## 3. API最適化

### 3.1 キャッシュ戦略

```typescript
// app/api/experiments/route.ts
import { NextRequest, NextResponse } from 'next/server';

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const siteId = searchParams.get('siteId');

  // キャッシュキーを生成
  const cacheKey = `experiments:${siteId}`;

  // Redisからキャッシュを取得
  const cached = await redis.get(cacheKey);
  if (cached) {
    return NextResponse.json(JSON.parse(cached), {
      headers: {
        'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
        'X-Cache': 'HIT',
      },
    });
  }

  // データベースから取得
  const experiments = await getExperiments(siteId);

  // Redisにキャッシュ（1時間）
  await redis.setex(cacheKey, 3600, JSON.stringify(experiments));

  return NextResponse.json(experiments, {
    headers: {
      'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=300',
      'X-Cache': 'MISS',
    },
  });
}
```

### 3.2 データベースクエリ最適化

```typescript
// lib/db/queries.ts
import { supabase } from '@/lib/supabase';

// N+1問題を回避（JOINを使用）
export async function getExperimentsWithVariants(siteId: string) {
  const { data, error } = await supabase
    .from('experiments')
    .select(`
      *,
      variants (
        id,
        name,
        is_control,
        visitors,
        conversions,
        conversion_rate
      )
    `)
    .eq('site_id', siteId)
    .eq('status', 'running')
    .order('created_at', { ascending: false });

  if (error) throw error;
  return data;
}

// ページネーション
export async function getExperimentsPaginated(siteId: string, page: number, limit: number) {
  const from = (page - 1) * limit;
  const to = from + limit - 1;

  const { data, error, count } = await supabase
    .from('experiments')
    .select('*', { count: 'exact' })
    .eq('site_id', siteId)
    .range(from, to)
    .order('created_at', { ascending: false });

  if (error) throw error;

  return {
    data,
    pagination: {
      page,
      limit,
      total: count || 0,
      totalPages: Math.ceil((count || 0) / limit),
    },
  };
}
```

### 3.3 並列処理

```typescript
// 複数のAPIを並列で呼び出す
export async function getDashboardData(siteId: string) {
  const [overview, experiments, rules] = await Promise.all([
    getOverviewStats(siteId),
    getActiveExperiments(siteId),
    getActiveRules(siteId),
  ]);

  return {
    overview,
    experiments,
    rules,
  };
}
```

---

## 4. Cloudflare Workers最適化

### 4.1 エッジキャッシング

```typescript
// workers/personalization.ts
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const cacheKey = new Request(url.toString(), request);
    const cache = caches.default;

    // キャッシュを確認
    let response = await cache.match(cacheKey);
    if (response) {
      return response;
    }

    // パーソナライゼーションロジック
    const visitorId = getCookie(request, 'visitor_id');
    const segment = await getVisitorSegment(visitorId);
    const rules = await getPersonalizationRules(url.pathname, segment);

    // レスポンスを生成
    response = new Response(JSON.stringify(rules), {
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'public, max-age=3600',
      },
    });

    // キャッシュに保存
    await cache.put(cacheKey, response.clone());

    return response;
  },
};
```

---

## 5. モニタリング

### 5.1 Web Vitals測定

```typescript
// app/layout.tsx
import { Analytics } from '@vercel/analytics/react';
import { SpeedInsights } from '@vercel/speed-insights/next';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>
        {children}
        <Analytics />
        <SpeedInsights />
      </body>
    </html>
  );
}
```

### 5.2 カスタムメトリクス

```typescript
// lib/performance.ts
export function measurePerformance() {
  if (typeof window === 'undefined') return;

  // LCP
  new PerformanceObserver((list) => {
    const entries = list.getEntries();
    const lastEntry = entries[entries.length - 1];
    console.log('LCP:', lastEntry.renderTime || lastEntry.loadTime);
  }).observe({ entryTypes: ['largest-contentful-paint'] });

  // FID
  new PerformanceObserver((list) => {
    const entries = list.getEntries();
    entries.forEach((entry) => {
      console.log('FID:', entry.processingStart - entry.startTime);
    });
  }).observe({ entryTypes: ['first-input'] });

  // CLS
  let clsValue = 0;
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (!(entry as any).hadRecentInput) {
        clsValue += (entry as any).value;
        console.log('CLS:', clsValue);
      }
    }
  }).observe({ entryTypes: ['layout-shift'] });
}
```

---

## 6. バンドルサイズ分析

```bash
# バンドルアナライザーのインストール
npm install --save-dev @next/bundle-analyzer

# next.config.jsに追加
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer(nextConfig);

# 実行
ANALYZE=true npm run build
```

---

## 7. パフォーマンス目標達成のチェックリスト

### フロントエンド
- [ ] Next.js App Routerを使用
- [ ] 画像をAVIF/WebP形式で配信
- [ ] フォントをサブセット化して最適化
- [ ] コード分割（dynamic import）
- [ ] 遅延読み込み（Intersection Observer）
- [ ] バンドルサイズ < 200KB（gzip後）

### API
- [ ] Redisキャッシュ（1時間）
- [ ] データベースクエリ最適化（JOIN、インデックス）
- [ ] 並列処理（Promise.all）
- [ ] ページネーション

### SDK
- [ ] 非同期読み込み
- [ ] サイズ < 30KB（gzip後）
- [ ] Anti-flickerスニペット（3秒タイムアウト）
- [ ] バッチ送信（10秒ごと）

### インフラ
- [ ] Cloudflare CDN
- [ ] エッジキャッシング（Workers）
- [ ] HTTP/2、HTTP/3
- [ ] Brotli圧縮

### モニタリング
- [ ] Vercel Analytics
- [ ] Speed Insights
- [ ] カスタムメトリクス（LCP、FID、CLS）
- [ ] バンドルアナライザー

---

## まとめ

これらの最適化により、以下の目標を達成できます：

- **LCP**: 2.5秒以内 ✅
- **FID**: 100ms以内 ✅
- **CLS**: 0.1以下 ✅
- **TTI**: 3.8秒以内 ✅
- **SDK読み込み**: 1秒以内 ✅

