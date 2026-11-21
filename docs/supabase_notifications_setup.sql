-- ============================================================
-- TRAVIXO — Supabase Realtime Notifications Table & Policies
-- انسخ هذا الكود وشغّله في Supabase -> SQL Editor -> New Query
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  notification_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         BIGINT NULL,
  target_role     TEXT NOT NULL DEFAULT 'all',   -- 'all' | 'customer' | 'developer'
  title           TEXT NOT NULL,
  body            TEXT NOT NULL,
  type            TEXT NOT NULL DEFAULT 'general', -- 'offer' | 'new_booking' | 'booking_status' | 'wallet' | 'general'
  is_read         BOOLEAN NOT NULL DEFAULT FALSE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- فهارس لتسريع جلب الإشعارات حسب العميل والدور والوقت
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_target_role ON public.notifications (target_role);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON public.notifications (created_at DESC);

-- تفعيل سياسات القراءة والكتابة والتحديث (RLS)
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow public read notifications" ON public.notifications;
CREATE POLICY "Allow public read notifications"
  ON public.notifications FOR SELECT
  USING (true);

DROP POLICY IF EXISTS "Allow public insert notifications" ON public.notifications;
CREATE POLICY "Allow public insert notifications"
  ON public.notifications FOR INSERT
  WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public update notifications" ON public.notifications;
CREATE POLICY "Allow public update notifications"
  ON public.notifications FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- تفعيل البث اللحظي (Supabase Realtime) لجدول الإشعارات
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END $$;

-- ============================================================
-- ملاحظة إعداد التحقق بالبريد الإلكتروني (Email OTP):
-- 1) من لوحة Supabase اذهب إلى: Authentication -> Providers -> Email (تأكد أنه مفعّل).
-- 2) من Authentication -> Email Templates -> Magic Link:
--    تأكد من وجود السطر التالي داخل قالب الرسالة ليصل رمز الـ 6 أرقام للعميل:
--    <h2>رمز التحقق الخاص بك في TRAVIXO: {{ .Token }}</h2>
-- ============================================================
