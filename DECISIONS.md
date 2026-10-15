# Decisions & assumptions

1. **Separate repo** from BFT Trade Lab (static HTML). Bridge comes in Phase 3 (`lab_links`, Backtest-vs-Live Drift).
2. **Name:** "BFT Journal" placeholder. Change in `index.html`, `vite.config.ts` (PWA manifest) and `App.tsx` header.
3. **Phase 0 is local-first:** demo data lives in memory and `localStorage` prefs. Supabase client and migration exist, but auth + sync is not wired into the UI yet. This is the next step.
4. **Equity curve** uses lightweight-charts v5 (`addSeries(AreaSeries)`). Draw-in is a clip-path reveal (GPU-friendly), as the library has no stroke animation.
5. **Calendar heatmap** is plain CSS grid (not ECharts) to keep the Phase 0 bundle small. ECharts arrives with the histograms/heatmaps in Phase 1.
6. **Entries table v1** uses TanStack Virtual with a hand-written column grid (not TanStack Table) so group headers, subtotals and sticky cells stay simple. Revisit if column resize/reorder needs it.
7. **Not in Phase 0 yet:** column reorder/resize, row-expand drawer, keyboard navigation, multi-select, natural-language search, sparkline column, XLSX/PDF export, Hinglish i18n, Gold/Emerald themes, offline queue for Quick Add, charges engine (Quick Add stores charges = 0; demo data has synthetic charges).
8. Charges and lot sizes in demo data are **synthetic**. Real ones must come from dated, configurable tables (Phase 1).
9. Colour is never the only P&L signal: ▲/▼ glyphs and signs everywhere. Colour-blind palette swaps to blue/orange.
10. Demo size: `?demo=50000` in the URL loads up to 100k rows for the scroll-performance check.
