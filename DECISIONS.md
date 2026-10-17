# Decisions and open items
- Project is static HTML. package.json, vite, tailwind and tsconfig files are unused leftovers from an earlier React plan.
- Academy access is enforced by Supabase RLS (schema.sql), not by the page: paid videos, PDFs and Pine code are only returned to a confirmed, non-expired student. Video/PDF links are signed and expire (2h / 1h). A page-level watermark shows the member's email on videos (deterrent only).
- Pasted YouTube/Vimeo links can be shared by a student; uploaded videos (private bucket) cannot. Supabase free plan caps uploads at 50 MB.
- Payment is temporary: manual UPI + WhatsApp screenshot, admin adds the student. Replace with a gateway webhook that inserts into `students` (service-role key, server side) when ready.
- TODO before charging at scale: refund/terms/privacy pages (CFG.refund/terms/privacy), cloud sync for Journal, broker tradebook import, confirm data licence for the CSV files.
