/* BFT partner links. A visit to any page with ?ref=CODE remembers the code for 30 days (last click wins), counts one
   unique visitor per day for that partner, and removes ?ref from the address bar.
   Checkout code reads the code with window.BFT_REF() and sends it to razorpay-order, which validates it. */
(function () {
  var SB = 'https://ytdipdzzwuzdnzrabpwx.supabase.co', KEY = 'sb_publishable_TZWfmoKVdyeuoBpmOvllUA_Cj7atACi';
  var K = 'bft_ref', V = 'bft_vid', DAYS = 30;
  function get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  function code() {
    try { var o = JSON.parse(get(K) || 'null'); if (o && /^[A-Z0-9]{4,12}$/.test(o.c) && Date.now() - o.t < DAYS * 864e5) return o.c; } catch (e) {}
    return '';
  }
  window.BFT_REF = code;
  function vid() {
    var v = get(V);
    if (!v || !/^[A-Za-z0-9-]{8,64}$/.test(v)) {
      v = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : (String(Math.random()).slice(2) + Date.now().toString(36));
      set(V, v);
    }
    return v;
  }
  function click(c) {
    var day = new Date().toISOString().slice(0, 10), mark = 'bft_refc_' + c;
    if (get(mark) === day) return;                       // already counted today on this device
    set(mark, day);
    try {
      fetch(SB + '/rest/v1/rpc/ref_click', { method: 'POST', keepalive: true,
        headers: { apikey: KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_code: c, p_vid: vid() }) }).catch(function () {});
    } catch (e) {}
  }
  try {
    var q = new URLSearchParams(location.search), c = (q.get('ref') || '').trim().toUpperCase();
    if (/^[A-Z0-9]{4,12}$/.test(c)) {
      set(K, JSON.stringify({ c: c, t: Date.now() }));
      click(c);
      q.delete('ref');
      history.replaceState(null, '', location.pathname + (q.toString() ? '?' + q.toString() : '') + location.hash);
    }
  } catch (e) {}
})();
