/* BFT Trade Lab - website analytics tracker v1  (same idea as the Rajasthan Career Hub tracker, but it writes to Supabase)
   Stores: page views, traffic source / UTM, device / OS / browser, approx location (country / state / city),
   active time on page, scroll depth, and button / link actions.
   Never stores: IP address, name, email, phone, typed text, trades, notes or anything inside the Journal / Lab / Classroom.
   Skips: bots, localhost, file://, the signed-in admin's browser (admin.html sets the flag) and ?notrack=1.
   Options (set BEFORE this script):  window.BFT_ANALYTICS = { geo:false }  -> no city lookup.
   Manual event from any page script:  window.BFTTrack('label', 'target') */
(() => {
  "use strict";
  const SB_URL = "https://ytdipdzzwuzdnzrabpwx.supabase.co";
  const SB_KEY = "sb_publishable_TZWfmoKVdyeuoBpmOvllUA_Cj7atACi";
  const OPT = window.BFT_ANALYTICS || {};
  const ua = navigator.userAgent || "";
  const LS = {
    get(k) { try { return localStorage.getItem(k); } catch (_) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (_) {} }
  };

  /* ---- skip bots, localhost and the owner's own browser ---- */
  if (navigator.webdriver || /bot|crawl|spider|slurp|headless|lighthouse|pagespeed|preview|facebookexternalhit|monitor|uptime/i.test(ua)) return;
  if (/^(localhost|127\.0\.0\.1|\[::1\])$/.test(location.hostname) || location.protocol === "file:") return;
  const params = new URLSearchParams(location.search);
  if (params.get("notrack") === "1") { LS.set("bft_no_track", "1"); return; }
  if (params.get("notrack") === "0") LS.set("bft_no_track", "0");
  if (LS.get("bft_no_track") === "1") return;

  const cut = (v, n) => String(v == null ? "" : v).slice(0, n);
  const uuid = () => (crypto.randomUUID ? crypto.randomUUID() : "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => { const r = Math.random() * 16 | 0; return (c === "x" ? r : r & 3 | 8).toString(16); }));

  /* ---- visitor (browser) id + session (30 min inactivity) ---- */
  let visitorId = LS.get("bft_an_visitor");
  if (!visitorId) { visitorId = uuid(); LS.set("bft_an_visitor", visitorId); }
  const now = Date.now();
  let sess = null;
  try { sess = JSON.parse(LS.get("bft_an_sess") || "null"); } catch (_) {}
  const isNewSession = !sess || !sess.id || now - (sess.last || 0) > 30 * 60 * 1000;

  const host = location.hostname.replace(/^www\./, "");
  const refHost = (() => {
    try { return document.referrer ? new URL(document.referrer).hostname.replace(/^www\./, "").slice(0, 120) : ""; } catch (_) { return ""; }
  })();

  function classify() {
    const utmSource = cut(params.get("utm_source") || params.get("source"), 60);
    const medium = cut(params.get("utm_medium"), 40).toLowerCase();
    const campaign = cut(params.get("utm_campaign"), 80);
    const h = refHost.toLowerCase();
    let channel = "Direct", source = "Direct";
    if (h && h !== host) { channel = "Referral"; source = h; }
    const rules = [
      [/google\.|googlequicksearchbox/, "Organic Search", "Google"], [/bing\./, "Organic Search", "Bing"], [/yahoo\./, "Organic Search", "Yahoo"],
      [/duckduckgo\./, "Organic Search", "DuckDuckGo"], [/yandex\.|baidu\.|ecosia\./, "Organic Search", h],
      [/facebook\.|(^|\.)fb\.|com\.facebook|lm\.facebook/, "Social", "Facebook"], [/instagram\./, "Social", "Instagram"],
      [/(^|\.)t\.co$|twitter\.|(^|\.)x\.com$/, "Social", "X / Twitter"], [/linkedin\.|lnkd\.in/, "Social", "LinkedIn"],
      [/youtube\.|youtu\.be/, "Social", "YouTube"], [/pinterest\./, "Social", "Pinterest"], [/reddit\./, "Social", "Reddit"],
      [/whatsapp\.|(^|\.)wa\.me$/, "Social", "WhatsApp"], [/(^|\.)t\.me$|telegram\./, "Social", "Telegram"],
      [/tradingview\./, "Referral", "TradingView"],
      [/mail\.google|outlook\.|mail\.yahoo|webmail/, "Email", "Email"]
    ];
    if (h && h !== host) for (const [re, ch, src] of rules) if (re.test(h)) { channel = ch; source = src; break; }
    if (utmSource) source = utmSource;
    if (/^(cpc|ppc|paid|paidsearch|paid_social|display|ads?)$/.test(medium)) channel = "Paid";
    else if (medium === "email") channel = "Email";
    else if (medium === "social" && channel !== "Social") channel = "Social";
    else if (utmSource && channel === "Direct") channel = "Campaign";
    return { channel, source: cut(source, 60), referrer: h === host ? "" : cut(refHost, 120), medium, campaign };
  }

  if (isNewSession) {
    const visits = (parseInt(LS.get("bft_an_visits") || "0", 10) || 0) + 1;
    LS.set("bft_an_visits", String(visits));
    sess = { id: uuid(), start: now, last: now, idx: 0, visits, attr: classify() };
  }
  const idx = sess.idx || 0;
  sess.idx = idx + 1; sess.last = now;
  LS.set("bft_an_sess", JSON.stringify(sess));
  const attr = sess.attr || classify();

  /* ---- environment ---- */
  const device = /ipad|tablet|(android(?!.*mobile))/i.test(ua) ? "Tablet" : /mobi|iphone|ipod|android/i.test(ua) ? "Mobile" : "Desktop";
  const os = /windows nt/i.test(ua) ? "Windows" : /android/i.test(ua) ? "Android" : /iphone|ipad|ipod/i.test(ua) ? "iOS" : /mac os x/i.test(ua) ? "macOS" : /cros/i.test(ua) ? "ChromeOS" : /linux/i.test(ua) ? "Linux" : "Other";
  const browser = /FBAN|FBAV/.test(ua) ? "Facebook App" : /Instagram/.test(ua) ? "Instagram App" : /EdgA?\//.test(ua) ? "Edge" : /OPR\/|Opera/.test(ua) ? "Opera" : /SamsungBrowser/.test(ua) ? "Samsung Internet" : /Firefox\/|FxiOS/.test(ua) ? "Firefox" : /Chrome\/|CriOS/.test(ua) ? "Chrome" : /Safari\//.test(ua) ? "Safari" : "Other";
  const page = cut(location.pathname.split("/").pop() || "index.html", 160);
  const tz = (() => { try { return cut(Intl.DateTimeFormat().resolvedOptions().timeZone, 60); } catch (_) { return ""; } })();
  const cached = (() => { try { const c = JSON.parse(LS.get("bft_an_geo") || "null"); return c && Date.now() - c.t < 864e5 ? c : null; } catch (_) { return null; } })();

  /* Pages that hold personal practice data: never record what is clicked or typed there (page view + time only). */
  const APP_PAGE = /^(journal|trade-lab-pro|classroom)\.html$/.test(page);

  /* ---- talking to Supabase (plain REST, no library) ---- */
  let dead = false;
  function post(path, body, keep) {
    if (dead) return Promise.resolve(false);
    return fetch(SB_URL + "/rest/v1/" + path, {
      method: "POST", keepalive: !!keep,
      headers: { apikey: SB_KEY, "Content-Type": "application/json", Prefer: "return=minimal" },
      body: JSON.stringify(body)
    }).then(r => {
      if (!r.ok) { if (r.status === 401 || r.status === 403 || r.status === 404) dead = true; return false; }
      return true;
    }).catch(() => false);
  }

  const viewId = uuid();
  const state = { duration: 0, scroll: 0, clicks: 0 };
  const created = post("web_views", {
    id: viewId, visitor_id: cut(visitorId, 80), session_id: cut(sess.id, 80),
    page, title: cut(document.title || page, 160),
    referrer: attr.referrer, source: attr.source, channel: attr.channel, medium: attr.medium, campaign: attr.campaign,
    device, os, browser, screen: screen.width + "x" + screen.height,
    language: cut(navigator.language, 20), tz,
    landing: idx === 0, page_index: idx + 1, visit_count: sess.visits || 1, is_new: (sess.visits || 1) === 1,
    country: cached ? cut(cached.country, 60) : "", country_code: cached ? cut(cached.cc, 4) : "",
    region: cached ? cut(cached.region, 60) : "", city: cached ? cut(cached.city, 60) : ""
  });

  let pending = {}, timer = null, sentSig = "";
  function patch(obj, immediate) {
    if (dead) return;
    Object.assign(pending, obj);
    clearTimeout(timer);
    timer = setTimeout(flush, immediate ? 0 : 2500);
  }
  async function flush() {
    if (dead || !Object.keys(pending).length) return;
    const body = pending; pending = {};
    const sig = JSON.stringify(body);
    if (sig === sentSig) return;
    sentSig = sig;
    if (!(await created)) return;
    post("rpc/track_ping", Object.assign({ p_id: viewId }, body), true);
  }

  /* ---- approximate location (country / state / city only; the IP is never saved by us) ---- */
  if (!cached && OPT.geo !== false) {
    (async () => {
      try {
        const ctl = new AbortController(); const t = setTimeout(() => ctl.abort(), 4000);
        const r = await fetch("https://ipwho.is/?fields=success,country,country_code,region,city", { signal: ctl.signal, cache: "no-store" });
        clearTimeout(t);
        const j = await r.json();
        if (!j || !j.success) return;
        const g = { t: Date.now(), country: cut(j.country, 60), cc: cut(j.country_code, 4), region: cut(j.region, 60), city: cut(j.city, 60) };
        LS.set("bft_an_geo", JSON.stringify(g));
        patch({ p_country: g.country, p_country_code: g.cc, p_region: g.region, p_city: g.city });
      } catch (_) {}
    })();
  }

  /* ---- time on page (visible seconds) and scroll depth ---- */
  const marks = [10, 20, 30, 45, 60, 90, 120, 180, 300, 600, 900, 1800];
  let lastSent = 0, lastScrollSent = 0;
  const pack = () => ({ p_duration: state.duration, p_scroll: state.scroll, p_interactions: state.clicks });
  const scrollNow = () => {
    const d = document.documentElement, h = Math.max(d.scrollHeight, document.body ? document.body.scrollHeight : 0);
    if (!h) return 0;
    return Math.min(100, Math.round(((window.scrollY || d.scrollTop || 0) + innerHeight) / h * 100));
  };
  let st = 0;
  addEventListener("scroll", () => {
    if (st) return;
    st = setTimeout(() => {
      st = 0; const s = scrollNow();
      if (s > state.scroll) {
        state.scroll = s;
        const m = [25, 50, 75, 90, 100].find(x => state.scroll >= x && lastScrollSent < x);
        if (m) { lastScrollSent = m; patch(pack()); }
      }
    }, 250);
  }, { passive: true });
  setTimeout(() => { state.scroll = Math.max(state.scroll, scrollNow()); }, 1200);

  setInterval(() => {
    if (document.visibilityState !== "visible" || state.duration >= 1800) return;
    state.duration++;
    if (marks.includes(state.duration)) { lastSent = state.duration; patch(pack()); }
  }, 1000);
  const leave = () => {
    state.scroll = Math.max(state.scroll, scrollNow());
    if (state.duration !== lastSent || state.scroll > lastScrollSent) { lastSent = state.duration; patch(pack(), true); }
  };
  document.addEventListener("visibilitychange", () => { if (document.visibilityState === "hidden") leave(); });
  addEventListener("pagehide", leave);

  /* ---- actions ---- */
  let sent = 0; const once = new Set();
  function track(type, label, target) {
    if (dead || sent >= 60) return;
    sent++;
    created.then(ok => {
      if (!ok) return;
      post("web_events", {
        type, label: cut(label, 80), target: cut(target, 80), page,
        visitor_id: cut(visitorId, 80), session_id: cut(sess.id, 80)
      });
    });
  }
  window.BFTTrack = (label, target) => track("custom", label || "custom", target || "");

  const priv = e => !!(e.target && e.target.closest && e.target.closest("[data-bft-private]"));
  /* Short button / link captions only, and never anything that looks like an email (e.g. a signed-in member's name). */
  const txt = el => {
    const t = (el.getAttribute("data-track") || el.getAttribute("aria-label") || el.textContent || "").replace(/\s+/g, " ").trim();
    return t.length > 40 || t.indexOf("@") > -1 ? "" : t;
  };

  document.addEventListener("click", e => {
    if (priv(e)) return;
    state.clicks++;
    const el = e.target && e.target.closest ? e.target.closest("a,button,[data-track]") : null;
    if (!el) return;
    const tracked = el.hasAttribute("data-track");
    const label = txt(el);
    const zone = (el.closest("[id]") || {}).id || "";

    if (el.tagName !== "A") {
      if (APP_PAGE && !tracked) return;            /* Journal / Lab / Classroom: only elements you explicitly mark */
      if (!label) return;
      return track(tracked ? "custom" : "button_click", label, zone);
    }
    const href = el.getAttribute("href") || "";
    if (/^tel:/i.test(href)) return track("call_click", label || href.slice(4), zone);
    if (/^mailto:/i.test(href)) return track("email_click", label || "email", zone);
    if (/wa\.me|api\.whatsapp\.com|^whatsapp:|chat\.whatsapp\.com/i.test(href)) return track("whatsapp_click", label || "WhatsApp", zone);
    if (/(^|\/\/)t\.me\/|telegram\.(me|org)/i.test(href)) return track("telegram_click", label || "Telegram", zone);
    try {
      const u = new URL(href, location.href);
      if (u.hostname === location.hostname) {
        const to = u.pathname.split("/").pop() || "index.html";
        if (/\.(pdf|docx?|xlsx?|zip|csv|gz)$/i.test(to)) return track("download_click", to, zone);
        if (/\.html$/.test(to) && to !== page) track("cta_click", APP_PAGE && !tracked ? "" : label, to.replace(".html", ""));
      } else if (/^https?:$/.test(u.protocol)) {
        const h = u.hostname.replace(/^www\./, "");
        track(/\.(pdf|docx?|xlsx?|zip|csv)$/i.test(u.pathname) ? "download_click" : "outbound_click", h, zone);
      }
    } catch (_) {}
  }, true);

  /* ---- searches and forms (what is typed or entered is NOT saved, except a public search box on marketing pages) ---- */
  if (!APP_PAGE) {
    const seenSearch = new Set(); let sTimer = 0;
    document.addEventListener("input", e => {
      if (priv(e)) return;
      const t = e.target;
      if (!t || t.tagName !== "INPUT" || t.type !== "search") return;
      clearTimeout(sTimer);
      sTimer = setTimeout(() => {
        const q = cut(String(t.value || "").trim().toLowerCase(), 60);
        if (q.length < 2 || q.indexOf("@") > -1 || seenSearch.has(q) || seenSearch.size >= 5) return;
        seenSearch.add(q); track("search", q, t.id || "");
      }, 1500);
    }, true);
    document.addEventListener("focusin", e => {
      if (priv(e)) return;
      const f = e.target && e.target.closest ? e.target.closest("form") : null;
      if (!f || !/INPUT|TEXTAREA|SELECT/.test(e.target.tagName) || e.target.type === "search") return;
      const id = f.id || "form"; if (once.has("s" + id)) return; once.add("s" + id); track("form_start", id, "");
    }, true);
    document.addEventListener("submit", e => {
      if (priv(e)) return;
      const f = e.target; track("form_submit", (f && f.id) || "form", "");
    }, true);
  }
})();
