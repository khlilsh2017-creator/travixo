-- ============================================================
-- TRAVIXO — إضافة عمود كلمة مرور المطورين في جدول users
-- شغّل هذا السطر مرة واحدة في Supabase -> SQL Editor -> New Query
-- ============================================================

ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS password_code TEXT;

-- ملاحظة: لتفعيل رمز التحقق (OTP) عند "نسيت كلمة المرور" للعملاء أيضاً،
-- افتح في Supabase: Authentication -> Emails -> Reset password
-- وضع نفس الكود مع {{ .Token }} ثم اضغط Save changes.
