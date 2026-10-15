# BFT Journal (Phase 0)

Cinematic trading journal for Indian retail traders. Journaling and education tool, not investment advice.

## Run
```bash
npm install
npm run dev          # http://localhost:5173  (add ?demo=50000 to stress-test the table)
npm test             # Vitest: analytics fixtures (hand-calculated)
npm run build        # typecheck + production build
```

## Database
`supabase/migrations/0001_phase0.sql` creates the tables with RLS on all of them.
`supabase/tests/rls.sql` is a cross-user test: `psql "$DB_URL" -f supabase/tests/rls.sql`.
Copy `.env.example` to `.env` and fill in the URL + anon key (never the service-role key).

## Layout
`src/design` tokens, themes, motion, GlassCard, CountUp · `src/lib/stats` pure tested analytics ·
`src/features/{trades,table,charts,dashboard}` · `supabase/{migrations,tests}`

See `DECISIONS.md` for assumptions and what is not built yet.
