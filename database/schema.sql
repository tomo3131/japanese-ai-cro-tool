-- Japanese AI CRO Tool Database Schema
-- PostgreSQL 15+ (Supabase)
-- 作成日: 2025-10-20

-- 拡張機能の有効化
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";
CREATE EXTENSION IF NOT EXISTS "timescaledb"; -- 時系列データ用

-- updated_at自動更新関数
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 1. 組織・ユーザー管理
-- ============================================================

-- 組織テーブル
CREATE TABLE organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    plan TEXT NOT NULL DEFAULT 'starter' CHECK (plan IN ('starter', 'professional', 'enterprise')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'cancelled')),
    billing_email TEXT NOT NULL,
    
    -- プラン制限
    max_sites INTEGER NOT NULL DEFAULT 1,
    max_experiments INTEGER NOT NULL DEFAULT 5,
    max_monthly_visitors INTEGER NOT NULL DEFAULT 500000,
    
    -- 請求情報
    stripe_customer_id TEXT,
    stripe_subscription_id TEXT,
    subscription_start_date TIMESTAMPTZ,
    subscription_end_date TIMESTAMPTZ,
    trial_end_date TIMESTAMPTZ,
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    -- インデックス
    CONSTRAINT organizations_name_not_empty CHECK (length(trim(name)) > 0)
);

CREATE INDEX idx_organizations_plan ON organizations(plan);
CREATE INDEX idx_organizations_status ON organizations(status);
CREATE INDEX idx_organizations_stripe_customer_id ON organizations(stripe_customer_id);

CREATE TRIGGER update_organizations_updated_at
    BEFORE UPDATE ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 組織メンバーテーブル
CREATE TABLE organization_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'viewer' CHECK (role IN ('owner', 'admin', 'editor', 'viewer')),
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'suspended')),
    
    -- 招待情報
    invited_by UUID REFERENCES auth.users(id),
    invited_at TIMESTAMPTZ,
    joined_at TIMESTAMPTZ,
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 制約
    UNIQUE(organization_id, user_id)
);

CREATE INDEX idx_organization_members_organization_id ON organization_members(organization_id);
CREATE INDEX idx_organization_members_user_id ON organization_members(user_id);
CREATE INDEX idx_organization_members_role ON organization_members(role);

CREATE TRIGGER update_organization_members_updated_at
    BEFORE UPDATE ON organization_members
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 2. サイト管理
-- ============================================================

-- サイトテーブル
CREATE TABLE sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    domain TEXT NOT NULL CHECK (length(domain) >= 1 AND length(domain) <= 255),
    
    -- サイト設定
    industry TEXT CHECK (industry IN ('ec', 'btob_saas', 'finance', 'media', 'other')),
    target_age TEXT CHECK (target_age IN ('young', 'general', 'senior')),
    
    -- トラッキング
    tracking_id TEXT NOT NULL UNIQUE,
    tracking_verified BOOLEAN NOT NULL DEFAULT FALSE,
    tracking_verified_at TIMESTAMPTZ,
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'archived')),
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    
    -- 制約
    UNIQUE(organization_id, domain)
);

CREATE INDEX idx_sites_organization_id ON sites(organization_id);
CREATE INDEX idx_sites_tracking_id ON sites(tracking_id);
CREATE INDEX idx_sites_status ON sites(status);
CREATE INDEX idx_sites_domain ON sites(domain);

CREATE TRIGGER update_sites_updated_at
    BEFORE UPDATE ON sites
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 3. パーソナライゼーション
-- ============================================================

-- パーソナライゼーションルールテーブル
CREATE TABLE personalization_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    description TEXT,
    
    -- ルール設定
    url_pattern TEXT NOT NULL,
    conditions JSONB NOT NULL DEFAULT '[]',
    changes JSONB NOT NULL DEFAULT '{}',
    priority INTEGER NOT NULL DEFAULT 0,
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'paused', 'archived')),
    
    -- スケジュール
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    
    -- パフォーマンス
    impressions BIGINT NOT NULL DEFAULT 0,
    conversions BIGINT NOT NULL DEFAULT 0,
    
    -- メタデータ
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_personalization_rules_organization_id ON personalization_rules(organization_id);
CREATE INDEX idx_personalization_rules_site_id ON personalization_rules(site_id);
CREATE INDEX idx_personalization_rules_status ON personalization_rules(status);
CREATE INDEX idx_personalization_rules_priority ON personalization_rules(priority DESC);
CREATE INDEX idx_personalization_rules_url_pattern ON personalization_rules(url_pattern);

CREATE TRIGGER update_personalization_rules_updated_at
    BEFORE UPDATE ON personalization_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 4. A/Bテスト・実験
-- ============================================================

-- 実験テーブル
CREATE TABLE experiments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    hypothesis TEXT NOT NULL,
    description TEXT,
    
    -- 実験設定
    url_pattern TEXT NOT NULL,
    traffic_allocation JSONB NOT NULL DEFAULT '{"control": 50, "variant": 50}',
    goal_metric TEXT NOT NULL DEFAULT 'conversion' CHECK (goal_metric IN ('conversion', 'click', 'engagement', 'revenue')),
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'running', 'paused', 'completed', 'archived')),
    
    -- スケジュール
    start_date TIMESTAMPTZ,
    end_date TIMESTAMPTZ,
    
    -- 統計結果
    winner_variant_id UUID,
    confidence_level NUMERIC(5, 2),
    p_value NUMERIC(10, 8),
    improvement_rate NUMERIC(10, 2),
    
    -- メタデータ
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_experiments_organization_id ON experiments(organization_id);
CREATE INDEX idx_experiments_site_id ON experiments(site_id);
CREATE INDEX idx_experiments_status ON experiments(status);
CREATE INDEX idx_experiments_created_at ON experiments(created_at DESC);

CREATE TRIGGER update_experiments_updated_at
    BEFORE UPDATE ON experiments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- バリアントテーブル
CREATE TABLE variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    experiment_id UUID NOT NULL REFERENCES experiments(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    description TEXT,
    is_control BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- バリアント設定
    changes JSONB NOT NULL DEFAULT '{}',
    traffic_percentage INTEGER NOT NULL DEFAULT 50 CHECK (traffic_percentage >= 0 AND traffic_percentage <= 100),
    
    -- パフォーマンス
    visitors BIGINT NOT NULL DEFAULT 0,
    conversions BIGINT NOT NULL DEFAULT 0,
    conversion_rate NUMERIC(10, 6) GENERATED ALWAYS AS (
        CASE WHEN visitors > 0 THEN (conversions::NUMERIC / visitors::NUMERIC) ELSE 0 END
    ) STORED,
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 制約
    UNIQUE(experiment_id, name)
);

CREATE INDEX idx_variants_experiment_id ON variants(experiment_id);
CREATE INDEX idx_variants_is_control ON variants(is_control);

CREATE TRIGGER update_variants_updated_at
    BEFORE UPDATE ON variants
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 5. イベント・メトリクス（時系列データ）
-- ============================================================

-- イベントテーブル（TimescaleDB）
CREATE TABLE events (
    id UUID DEFAULT gen_random_uuid(),
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    visitor_id TEXT NOT NULL,
    session_id TEXT NOT NULL,
    
    -- イベント情報
    event_type TEXT NOT NULL CHECK (event_type IN ('pageview', 'click', 'conversion', 'custom')),
    event_name TEXT,
    event_data JSONB,
    
    -- ページ情報
    url TEXT NOT NULL,
    referrer TEXT,
    
    -- デバイス情報
    user_agent TEXT,
    device_type TEXT CHECK (device_type IN ('desktop', 'mobile', 'tablet')),
    browser TEXT,
    os TEXT,
    
    -- 位置情報
    country TEXT,
    region TEXT,
    city TEXT,
    
    -- 実験・パーソナライゼーション
    experiment_id UUID REFERENCES experiments(id) ON DELETE SET NULL,
    variant_id UUID REFERENCES variants(id) ON DELETE SET NULL,
    personalization_rule_id UUID REFERENCES personalization_rules(id) ON DELETE SET NULL,
    
    -- UTMパラメータ
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    utm_term TEXT,
    utm_content TEXT,
    
    -- タイムスタンプ
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- 制約
    PRIMARY KEY (id, timestamp)
);

-- TimescaleDBハイパーテーブル化
SELECT create_hypertable('events', 'timestamp', if_not_exists => TRUE);

-- インデックス
CREATE INDEX idx_events_site_id_timestamp ON events(site_id, timestamp DESC);
CREATE INDEX idx_events_visitor_id ON events(visitor_id, timestamp DESC);
CREATE INDEX idx_events_session_id ON events(session_id, timestamp DESC);
CREATE INDEX idx_events_event_type ON events(event_type, timestamp DESC);
CREATE INDEX idx_events_experiment_id ON events(experiment_id, timestamp DESC) WHERE experiment_id IS NOT NULL;
CREATE INDEX idx_events_variant_id ON events(variant_id, timestamp DESC) WHERE variant_id IS NOT NULL;
CREATE INDEX idx_events_personalization_rule_id ON events(personalization_rule_id, timestamp DESC) WHERE personalization_rule_id IS NOT NULL;

-- 圧縮ポリシー（90日以上前のデータを圧縮）
SELECT add_compression_policy('events', INTERVAL '90 days');

-- 保持ポリシー（180日以上前のデータを削除）
SELECT add_retention_policy('events', INTERVAL '180 days');

-- ============================================================
-- 6. 訪問者・セッション
-- ============================================================

-- 訪問者テーブル
CREATE TABLE visitors (
    id TEXT PRIMARY KEY,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    
    -- 訪問者属性
    first_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    total_sessions INTEGER NOT NULL DEFAULT 1,
    total_pageviews INTEGER NOT NULL DEFAULT 0,
    total_conversions INTEGER NOT NULL DEFAULT 0,
    
    -- デバイス情報（最新）
    device_type TEXT,
    browser TEXT,
    os TEXT,
    
    -- 位置情報（最新）
    country TEXT,
    region TEXT,
    city TEXT,
    
    -- 初回訪問情報
    initial_referrer TEXT,
    initial_utm_source TEXT,
    initial_utm_medium TEXT,
    initial_utm_campaign TEXT,
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_visitors_site_id ON visitors(site_id);
CREATE INDEX idx_visitors_last_seen_at ON visitors(last_seen_at DESC);
CREATE INDEX idx_visitors_total_conversions ON visitors(total_conversions DESC);

CREATE TRIGGER update_visitors_updated_at
    BEFORE UPDATE ON visitors
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- セッションテーブル
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    visitor_id TEXT NOT NULL REFERENCES visitors(id) ON DELETE CASCADE,
    
    -- セッション情報
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    pageviews INTEGER NOT NULL DEFAULT 0,
    
    -- 参照元
    referrer TEXT,
    utm_source TEXT,
    utm_medium TEXT,
    utm_campaign TEXT,
    utm_term TEXT,
    utm_content TEXT,
    
    -- デバイス情報
    device_type TEXT,
    browser TEXT,
    os TEXT,
    
    -- コンバージョン
    converted BOOLEAN NOT NULL DEFAULT FALSE,
    conversion_value NUMERIC(10, 2),
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_site_id ON sessions(site_id);
CREATE INDEX idx_sessions_visitor_id ON sessions(visitor_id);
CREATE INDEX idx_sessions_started_at ON sessions(started_at DESC);
CREATE INDEX idx_sessions_converted ON sessions(converted) WHERE converted = TRUE;

CREATE TRIGGER update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- ============================================================
-- 7. AI・学習データ
-- ============================================================

-- AI仮説テーブル
CREATE TABLE ai_hypotheses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    
    -- 仮説内容
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    change_type TEXT NOT NULL CHECK (change_type IN ('color', 'copy', 'image', 'layout', 'cta', 'form')),
    target_element TEXT NOT NULL,
    current_value TEXT,
    suggested_value TEXT NOT NULL,
    
    -- 根拠
    rationale TEXT NOT NULL,
    psychological_principle TEXT,
    
    -- 期待効果
    expected_improvement NUMERIC(5, 2),
    priority_score INTEGER NOT NULL CHECK (priority_score >= 0 AND priority_score <= 100),
    implementation_difficulty TEXT NOT NULL CHECK (implementation_difficulty IN ('easy', 'medium', 'hard')),
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'suggested' CHECK (status IN ('suggested', 'accepted', 'rejected', 'testing', 'implemented')),
    
    -- 実験との紐付け
    experiment_id UUID REFERENCES experiments(id) ON DELETE SET NULL,
    
    -- メタデータ
    generated_by TEXT NOT NULL DEFAULT 'gemini-2.0-flash',
    generated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_ai_hypotheses_organization_id ON ai_hypotheses(organization_id);
CREATE INDEX idx_ai_hypotheses_site_id ON ai_hypotheses(site_id);
CREATE INDEX idx_ai_hypotheses_status ON ai_hypotheses(status);
CREATE INDEX idx_ai_hypotheses_priority_score ON ai_hypotheses(priority_score DESC);

CREATE TRIGGER update_ai_hypotheses_updated_at
    BEFORE UPDATE ON ai_hypotheses
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 学習データテーブル
CREATE TABLE learning_data (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    site_id UUID NOT NULL REFERENCES sites(id) ON DELETE CASCADE,
    experiment_id UUID REFERENCES experiments(id) ON DELETE CASCADE,
    
    -- 変更内容
    change_type TEXT NOT NULL,
    change_description TEXT NOT NULL,
    
    -- 結果
    improvement_rate NUMERIC(10, 2) NOT NULL,
    confidence_level NUMERIC(5, 2) NOT NULL,
    sample_size INTEGER NOT NULL,
    
    -- セグメント
    segment_data JSONB,
    
    -- メタデータ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_learning_data_organization_id ON learning_data(organization_id);
CREATE INDEX idx_learning_data_site_id ON learning_data(site_id);
CREATE INDEX idx_learning_data_change_type ON learning_data(change_type);
CREATE INDEX idx_learning_data_improvement_rate ON learning_data(improvement_rate DESC);

-- ============================================================
-- 8. APIキー・セキュリティ
-- ============================================================

-- APIキーテーブル
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (length(name) >= 1 AND length(name) <= 255),
    
    -- キー情報（ハッシュ化）
    hashed_key TEXT NOT NULL UNIQUE,
    key_prefix TEXT NOT NULL, -- 表示用（例: sk_abc...）
    
    -- ステータス
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    
    -- 使用状況
    last_used_at TIMESTAMPTZ,
    usage_count BIGINT NOT NULL DEFAULT 0,
    
    -- メタデータ
    created_by UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    revoked_at TIMESTAMPTZ,
    revoked_by UUID REFERENCES auth.users(id)
);

CREATE INDEX idx_api_keys_organization_id ON api_keys(organization_id);
CREATE INDEX idx_api_keys_hashed_key ON api_keys(hashed_key);
CREATE INDEX idx_api_keys_status ON api_keys(status);

-- セキュリティログテーブル
CREATE TABLE security_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
    
    -- イベント情報
    event_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'info' CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    
    -- 詳細
    ip_address INET,
    user_agent TEXT,
    details JSONB,
    
    -- タイムスタンプ
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_security_logs_user_id ON security_logs(user_id, created_at DESC);
CREATE INDEX idx_security_logs_organization_id ON security_logs(organization_id, created_at DESC);
CREATE INDEX idx_security_logs_event_type ON security_logs(event_type, created_at DESC);
CREATE INDEX idx_security_logs_severity ON security_logs(severity, created_at DESC);
CREATE INDEX idx_security_logs_created_at ON security_logs(created_at DESC);

-- ============================================================
-- 9. Row Level Security (RLS)
-- ============================================================

-- RLSを有効化
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE organization_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE personalization_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_hypotheses ENABLE ROW LEVEL SECURITY;
ALTER TABLE learning_data ENABLE ROW LEVEL SECURITY;
ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;

-- 組織: 自分が所属する組織のみ閲覧可能
CREATE POLICY "Users can view their organizations"
ON organizations FOR SELECT
USING (
    id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid()
    )
);

-- 組織: Ownerのみ更新可能
CREATE POLICY "Owners can update their organizations"
ON organizations FOR UPDATE
USING (
    id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid() AND role = 'owner'
    )
);

-- サイト: 自分の組織のサイトのみ閲覧可能
CREATE POLICY "Users can view their organization's sites"
ON sites FOR SELECT
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid()
    )
);

-- サイト: Admin以上が作成・更新可能
CREATE POLICY "Admins can manage sites"
ON sites FOR ALL
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
);

-- パーソナライゼーションルール: 自分の組織のルールのみ閲覧可能
CREATE POLICY "Users can view their organization's personalization rules"
ON personalization_rules FOR SELECT
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid()
    )
);

-- パーソナライゼーションルール: Editor以上が作成・更新可能
CREATE POLICY "Editors can manage personalization rules"
ON personalization_rules FOR ALL
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'editor')
    )
);

-- 実験: 自分の組織の実験のみ閲覧可能
CREATE POLICY "Users can view their organization's experiments"
ON experiments FOR SELECT
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid()
    )
);

-- 実験: Editor以上が作成・更新可能
CREATE POLICY "Editors can manage experiments"
ON experiments FOR ALL
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid() AND role IN ('owner', 'admin', 'editor')
    )
);

-- APIキー: Admin以上が閲覧・管理可能
CREATE POLICY "Admins can manage API keys"
ON api_keys FOR ALL
USING (
    organization_id IN (
        SELECT organization_id 
        FROM organization_members 
        WHERE user_id = auth.uid() AND role IN ('owner', 'admin')
    )
);

-- ============================================================
-- 10. ビュー（集計用）
-- ============================================================

-- 実験パフォーマンスビュー
CREATE VIEW experiment_performance AS
SELECT 
    e.id AS experiment_id,
    e.name AS experiment_name,
    e.status,
    v.id AS variant_id,
    v.name AS variant_name,
    v.is_control,
    v.visitors,
    v.conversions,
    v.conversion_rate,
    e.confidence_level,
    e.p_value,
    e.improvement_rate
FROM experiments e
JOIN variants v ON e.id = v.experiment_id
WHERE e.deleted_at IS NULL;

-- サイト統計ビュー
CREATE VIEW site_statistics AS
SELECT 
    s.id AS site_id,
    s.name AS site_name,
    COUNT(DISTINCT v.id) AS total_visitors,
    COUNT(DISTINCT sess.id) AS total_sessions,
    SUM(sess.pageviews) AS total_pageviews,
    COUNT(DISTINCT CASE WHEN sess.converted THEN sess.id END) AS total_conversions,
    ROUND(
        COUNT(DISTINCT CASE WHEN sess.converted THEN sess.id END)::NUMERIC / 
        NULLIF(COUNT(DISTINCT sess.id), 0) * 100, 
        2
    ) AS overall_conversion_rate
FROM sites s
LEFT JOIN visitors v ON s.id = v.site_id
LEFT JOIN sessions sess ON v.id = sess.visitor_id
WHERE s.deleted_at IS NULL
GROUP BY s.id, s.name;

-- ============================================================
-- 11. 初期データ
-- ============================================================

-- プラン制限のデフォルト値を設定する関数
CREATE OR REPLACE FUNCTION set_plan_limits()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.plan = 'starter' THEN
        NEW.max_sites := 1;
        NEW.max_experiments := 5;
        NEW.max_monthly_visitors := 500000;
    ELSIF NEW.plan = 'professional' THEN
        NEW.max_sites := 10;
        NEW.max_experiments := 50;
        NEW.max_monthly_visitors := 5000000;
    ELSIF NEW.plan = 'enterprise' THEN
        NEW.max_sites := 999999;
        NEW.max_experiments := 999999;
        NEW.max_monthly_visitors := 999999999;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_organization_plan_limits
    BEFORE INSERT OR UPDATE OF plan ON organizations
    FOR EACH ROW
    EXECUTE FUNCTION set_plan_limits();

-- ============================================================
-- 完了
-- ============================================================

COMMENT ON DATABASE postgres IS 'Japanese AI CRO Tool Database';

