/**
 * エラーハンドリング体系
 * 
 * すべてのエラーは一貫した形式で処理され、ユーザーに適切なメッセージが表示されます。
 */

// ============================================================
// エラーコード定義
// ============================================================

export const ErrorCodes = {
  // ============================================================
  // 認証エラー (1000-1999)
  // ============================================================
  UNAUTHORIZED: {
    code: 1000,
    message: '認証が必要です',
    userMessage: 'ログインしてください',
  },
  INVALID_CREDENTIALS: {
    code: 1001,
    message: 'メールアドレスまたはパスワードが正しくありません',
    userMessage: 'メールアドレスまたはパスワードが正しくありません',
  },
  TOKEN_EXPIRED: {
    code: 1002,
    message: 'セッションの有効期限が切れました',
    userMessage: 'セッションの有効期限が切れました。再度ログインしてください',
  },
  TOKEN_INVALID: {
    code: 1003,
    message: 'トークンが無効です',
    userMessage: '認証に失敗しました。再度ログインしてください',
  },
  EMAIL_NOT_VERIFIED: {
    code: 1004,
    message: 'メールアドレスが確認されていません',
    userMessage: 'メールアドレスを確認してください。確認メールを再送しますか？',
  },
  PASSWORD_TOO_WEAK: {
    code: 1005,
    message: 'パスワードが弱すぎます',
    userMessage: 'パスワードは8文字以上で、大小英字・数字・記号を含む必要があります',
  },
  TWO_FACTOR_REQUIRED: {
    code: 1006,
    message: '2要素認証が必要です',
    userMessage: '2要素認証コードを入力してください',
  },
  TWO_FACTOR_INVALID: {
    code: 1007,
    message: '2要素認証コードが無効です',
    userMessage: '2要素認証コードが正しくありません',
  },

  // ============================================================
  // 認可エラー (2000-2999)
  // ============================================================
  FORBIDDEN: {
    code: 2000,
    message: 'この操作を実行する権限がありません',
    userMessage: 'この操作を実行する権限がありません',
  },
  INSUFFICIENT_PLAN: {
    code: 2001,
    message: 'プランのアップグレードが必要です',
    userMessage: 'この機能はプロフェッショナルプラン以上で利用可能です',
  },
  ORGANIZATION_SUSPENDED: {
    code: 2002,
    message: '組織が停止されています',
    userMessage: 'アカウントが停止されています。サポートにお問い合わせください',
  },
  TRIAL_EXPIRED: {
    code: 2003,
    message: 'トライアル期間が終了しました',
    userMessage: 'トライアル期間が終了しました。プランをアップグレードしてください',
  },
  QUOTA_EXCEEDED: {
    code: 2004,
    message: '利用制限を超えました',
    userMessage: 'プランの利用制限を超えました。プランをアップグレードしてください',
  },

  // ============================================================
  // バリデーションエラー (3000-3999)
  // ============================================================
  VALIDATION_ERROR: {
    code: 3000,
    message: '入力内容に誤りがあります',
    userMessage: '入力内容に誤りがあります',
  },
  REQUIRED_FIELD: {
    code: 3001,
    message: '必須項目が入力されていません',
    userMessage: '必須項目が入力されていません',
  },
  INVALID_FORMAT: {
    code: 3002,
    message: '入力形式が正しくありません',
    userMessage: '入力形式が正しくありません',
  },
  INVALID_EMAIL: {
    code: 3003,
    message: '有効なメールアドレスを入力してください',
    userMessage: '有効なメールアドレスを入力してください',
  },
  INVALID_URL: {
    code: 3004,
    message: '有効なURLを入力してください',
    userMessage: '有効なURLを入力してください',
  },
  INVALID_DATE: {
    code: 3005,
    message: '有効な日付を入力してください',
    userMessage: '有効な日付を入力してください',
  },
  VALUE_TOO_LONG: {
    code: 3006,
    message: '入力値が長すぎます',
    userMessage: '入力値が長すぎます',
  },
  VALUE_TOO_SHORT: {
    code: 3007,
    message: '入力値が短すぎます',
    userMessage: '入力値が短すぎます',
  },
  VALUE_OUT_OF_RANGE: {
    code: 3008,
    message: '入力値が範囲外です',
    userMessage: '入力値が範囲外です',
  },

  // ============================================================
  // リソースエラー (4000-4999)
  // ============================================================
  NOT_FOUND: {
    code: 4000,
    message: '指定されたリソースが見つかりません',
    userMessage: '指定されたリソースが見つかりません',
  },
  ALREADY_EXISTS: {
    code: 4001,
    message: 'すでに存在します',
    userMessage: 'すでに存在します',
  },
  DUPLICATE_EMAIL: {
    code: 4002,
    message: 'このメールアドレスは既に登録されています',
    userMessage: 'このメールアドレスは既に登録されています',
  },
  DUPLICATE_DOMAIN: {
    code: 4003,
    message: 'このドメインは既に登録されています',
    userMessage: 'このドメインは既に登録されています',
  },
  RESOURCE_IN_USE: {
    code: 4004,
    message: 'このリソースは使用中のため削除できません',
    userMessage: 'このリソースは使用中のため削除できません',
  },
  EXPERIMENT_RUNNING: {
    code: 4005,
    message: '実験が実行中です',
    userMessage: '実験が実行中のため、この操作はできません',
  },

  // ============================================================
  // レート制限エラー (5000-5999)
  // ============================================================
  RATE_LIMIT_EXCEEDED: {
    code: 5000,
    message: 'リクエスト数が上限に達しました',
    userMessage: 'リクエスト数が上限に達しました。しばらくしてから再試行してください',
  },
  TOO_MANY_REQUESTS: {
    code: 5001,
    message: 'リクエストが多すぎます',
    userMessage: 'リクエストが多すぎます。しばらくしてから再試行してください',
  },
  LOGIN_ATTEMPTS_EXCEEDED: {
    code: 5002,
    message: 'ログイン試行回数が多すぎます',
    userMessage: 'ログイン試行回数が多すぎます。15分後に再試行してください',
  },

  // ============================================================
  // サーバーエラー (9000-9999)
  // ============================================================
  INTERNAL_ERROR: {
    code: 9000,
    message: 'サーバーエラーが発生しました',
    userMessage: 'サーバーエラーが発生しました。しばらくしてから再試行してください',
  },
  DATABASE_ERROR: {
    code: 9001,
    message: 'データベースエラーが発生しました',
    userMessage: 'データベースエラーが発生しました。しばらくしてから再試行してください',
  },
  EXTERNAL_API_ERROR: {
    code: 9002,
    message: '外部APIとの通信に失敗しました',
    userMessage: '外部サービスとの通信に失敗しました。しばらくしてから再試行してください',
  },
  LLM_API_ERROR: {
    code: 9003,
    message: 'AI APIとの通信に失敗しました',
    userMessage: 'AI機能が一時的に利用できません。しばらくしてから再試行してください',
  },
  FILE_UPLOAD_ERROR: {
    code: 9004,
    message: 'ファイルのアップロードに失敗しました',
    userMessage: 'ファイルのアップロードに失敗しました。もう一度お試しください',
  },
  PAYMENT_ERROR: {
    code: 9005,
    message: '決済処理に失敗しました',
    userMessage: '決済処理に失敗しました。カード情報を確認してください',
  },
} as const;

// ============================================================
// カスタムエラークラス
// ============================================================

export class AppError extends Error {
  public readonly code: number;
  public readonly userMessage: string;
  public readonly details?: any;
  public readonly statusCode: number;

  constructor(
    errorCode: typeof ErrorCodes[keyof typeof ErrorCodes],
    details?: any,
    statusCode?: number
  ) {
    super(errorCode.message);
    this.name = 'AppError';
    this.code = errorCode.code;
    this.userMessage = errorCode.userMessage;
    this.details = details;
    
    // HTTPステータスコードを自動決定
    this.statusCode = statusCode || this.getStatusCodeFromErrorCode(errorCode.code);
    
    // スタックトレースをキャプチャ
    Error.captureStackTrace(this, this.constructor);
  }

  private getStatusCodeFromErrorCode(code: number): number {
    if (code >= 1000 && code < 2000) return 401; // 認証エラー
    if (code >= 2000 && code < 3000) return 403; // 認可エラー
    if (code >= 3000 && code < 4000) return 400; // バリデーションエラー
    if (code >= 4000 && code < 5000) {
      if (code === 4000) return 404; // Not Found
      return 409; // Conflict
    }
    if (code >= 5000 && code < 6000) return 429; // レート制限
    return 500; // サーバーエラー
  }

  toJSON() {
    return {
      error: this.name,
      code: this.code,
      message: this.userMessage,
      details: this.details,
    };
  }
}

// ============================================================
// エラーハンドラー
// ============================================================

export function handleError(error: unknown): {
  statusCode: number;
  body: any;
} {
  // AppErrorの場合
  if (error instanceof AppError) {
    return {
      statusCode: error.statusCode,
      body: error.toJSON(),
    };
  }

  // Supabaseエラーの場合
  if (isSupabaseError(error)) {
    return handleSupabaseError(error);
  }

  // Zodバリデーションエラーの場合
  if (isZodError(error)) {
    return handleZodError(error);
  }

  // その他のエラー
  console.error('Unexpected error:', error);
  
  return {
    statusCode: 500,
    body: {
      error: 'InternalError',
      code: 9000,
      message: 'サーバーエラーが発生しました。しばらくしてから再試行してください',
    },
  };
}

// Supabaseエラーの判定
function isSupabaseError(error: any): boolean {
  return error && typeof error === 'object' && 'code' in error && 'message' in error;
}

// Supabaseエラーのハンドリング
function handleSupabaseError(error: any): { statusCode: number; body: any } {
  // 認証エラー
  if (error.code === 'PGRST301') {
    return {
      statusCode: 401,
      body: new AppError(ErrorCodes.UNAUTHORIZED).toJSON(),
    };
  }

  // ユニーク制約違反
  if (error.code === '23505') {
    return {
      statusCode: 409,
      body: new AppError(ErrorCodes.ALREADY_EXISTS).toJSON(),
    };
  }

  // 外部キー制約違反
  if (error.code === '23503') {
    return {
      statusCode: 400,
      body: new AppError(ErrorCodes.VALIDATION_ERROR, {
        message: '関連するリソースが見つかりません',
      }).toJSON(),
    };
  }

  // その他のデータベースエラー
  return {
    statusCode: 500,
    body: new AppError(ErrorCodes.DATABASE_ERROR).toJSON(),
  };
}

// Zodエラーの判定
function isZodError(error: any): boolean {
  return error && error.name === 'ZodError';
}

// Zodエラーのハンドリング
function handleZodError(error: any): { statusCode: number; body: any } {
  const fields = error.errors.map((err: any) => ({
    field: err.path.join('.'),
    message: err.message,
  }));

  return {
    statusCode: 400,
    body: new AppError(ErrorCodes.VALIDATION_ERROR, { fields }).toJSON(),
  };
}

// ============================================================
// エラーロギング
// ============================================================

export async function logError(error: Error, context?: any) {
  // 本番環境ではSentryなどに送信
  if (process.env.NODE_ENV === 'production') {
    // await Sentry.captureException(error, { extra: context });
  }

  // 開発環境ではコンソールに出力
  console.error('Error:', {
    message: error.message,
    stack: error.stack,
    context,
  });
}

// ============================================================
// Next.js APIルートでの使用例
// ============================================================

/*
import { NextRequest, NextResponse } from 'next/server';
import { AppError, ErrorCodes, handleError } from '@/lib/errors';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    
    // バリデーション
    if (!body.email) {
      throw new AppError(ErrorCodes.REQUIRED_FIELD, {
        field: 'email',
      });
    }
    
    // ビジネスロジック
    const user = await createUser(body);
    
    return NextResponse.json(user, { status: 201 });
  } catch (error) {
    const { statusCode, body } = handleError(error);
    return NextResponse.json(body, { status: statusCode });
  }
}
*/

// ============================================================
// React コンポーネントでの使用例
// ============================================================

/*
import { AppError, ErrorCodes } from '@/lib/errors';

function LoginForm() {
  const [error, setError] = useState<string | null>(null);
  
  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    
    try {
      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      
      if (!response.ok) {
        const error = await response.json();
        setError(error.message);
        return;
      }
      
      // ログイン成功
      router.push('/dashboard');
    } catch (error) {
      setError('ネットワークエラーが発生しました');
    }
  }
  
  return (
    <form onSubmit={handleSubmit}>
      {error && <div className="error">{error}</div>}
      {/* フォームフィールド */}
    </form>
  );
}
*/

