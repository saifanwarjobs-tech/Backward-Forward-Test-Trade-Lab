/* BFT access + paywall. Free trial minutes, free journal entries, pay once / monthly, per-item (PDF, indicator).
   Prices and limits come from the `products` and `items.price` tables, which you edit in admin-pricing.html.
   NOTE: trial counters live in the browser (localStorage). They are a nudge, not DRM. Paid Academy files are protected by Supabase RLS. */
(function(){
const CFG={sbUrl:'https://ytdipdzzwuzdnzrabpwx.supabase.co',sbKey:'sb_publishable_TZWfmoKVdyeuoBpmOvllUA_Cj7atACi',
 razorpayKey:'rzp_live_Tq2J3Mo863dERr',orderUrl:'https://ytdipdzzwuzdnzrabpwx.supabase.co/functions/v1/razorpay-order',wa:'916350566010'};   // fill razorpayKey + orderUrl when Razorpay is live; until then payment goes through WhatsApp
const TOOL={'journal.html':'journal','trade-lab-pro.html':'lab','classroom.html':'classroom'}[location.pathname.split('/').pop()||'']||'';
const P={},ENT={};let sb=null,email='',ready=null;
const rs=n=>'₹'+Number(n).toLocaleString('en-IN');
const h=(t,a,...k)=>{const e=document.createElement(t);for(const x in a||{}){x==='style'?e.style.cssText=a[x]:x.startsWith('on')?e[x]=a[x]:e.setAttribute(x,a[x])}k.flat().forEach(c=>e.append(c&&c.nodeType?c:document.createTextNode(c==null?'':c)));return e};
const rest=async(path)=>{try{const r=await fetch(CFG.sbUrl+'/rest/v1/'+path,{headers:{apikey:CFG.sbKey}});return r.ok?await r.json():[]}catch(e){return[]}};
const lib=()=>window.supabase?Promise.resolve():new Promise(ok=>{const s=document.createElement('script');s.src='https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js';s.onload=ok;s.onerror=ok;document.head.appendChild(s)});
async function loadEnt(){Object.keys(ENT).forEach(k=>delete ENT[k]);email='';
 try{const s=(await sb.auth.getSession()).data.session;if(!s)return;email=(s.user.email||'').toLowerCase();
  const{data}=await sb.from('entitlements').select('product_id,expires_at');(data||[]).forEach(r=>{if(!r.expires_at||Date.parse(r.expires_at)>Date.now())ENT[r.product_id]=1})}catch(e){}}
function init(){return ready||(ready=(async()=>{const rows=await rest('products?select=*&active=eq.true');rows.forEach(r=>P[r.id]=r);
 await lib();try{if(window.supabase)sb=supabase.createClient(CFG.sbUrl,CFG.sbKey)}catch(e){}if(sb)await loadEnt();})())}
const entitled=()=>!!(ENT[TOOL]||ENT.all_tools);
const owns=x=>typeof x==='string'?!!ENT[x]:!!(x&&ENT['item:'+x.id]);
/* ---------- UI ---------- */
let box=null;
function close(){if(box){box.remove();box=null}}
function show(o){close();const msg=h('div',{style:'font-size:13px;margin-top:8px;color:#8e9bb8;min-height:18px'});
 const em=h('input',{type:'email',placeholder:'Your email (access is linked to it)',value:email,style:'width:100%;padding:11px;border-radius:10px;border:1px solid #3a4666;background:#0b1220;color:#e8eefb;margin:10px 0 4px'});
 const ph=h('input',{type:'tel',placeholder:'Mobile (optional)',style:'width:100%;padding:11px;border-radius:10px;border:1px solid #3a4666;background:#0b1220;color:#e8eefb;margin-bottom:6px'});
 const cards=o.options.map(op=>h('div',{style:'border:1px solid #3a4666;border-radius:12px;padding:12px;margin-top:8px;display:flex;gap:10px;align-items:center;justify-content:space-between'},
  h('div',{},h('b',{},op.label),h('div',{style:'font-size:12px;color:#8e9bb8'},op.sub||'')),
  h('div',{style:'display:flex;gap:6px;flex-wrap:wrap;justify-content:flex-end'},
   h('button',{style:btn('#f5c76b','#2a1d00'),onclick:()=>pay(op,em.value,ph.value,msg)},CFG.razorpayKey&&CFG.orderUrl?'Pay '+rs(op.amount):rs(op.amount)+' · WhatsApp'))));
 const pw=h('input',{type:'password',placeholder:'Password',style:'width:100%;padding:11px;border-radius:10px;border:1px solid #3a4666;background:#0b1220;color:#e8eefb;margin-top:6px'});
 const sign=async(up)=>{if(!sb)return;const e=em.value.trim().toLowerCase();if(!e||!pw.value)return msg.textContent='Enter email and password';
  const r=up?await sb.auth.signUp({email:e,password:pw.value}):await sb.auth.signInWithPassword({email:e,password:pw.value});
  if(r.error)return msg.textContent=r.error.message;if(up&&!r.data.session)return msg.textContent='Check your email to confirm, then sign in.';
  await loadEnt();if(o.blocking?entitled():o.owned&&o.owned()){close();upBadge()}else msg.textContent='Signed in. No active plan on this email yet.'};
 box=h('div',{style:'position:fixed;inset:0;z-index:99999;background:rgba(3,6,14,.82);display:flex;align-items:center;justify-content:center;padding:16px;font:15px/1.5 system-ui,sans-serif'},
  h('div',{style:'background:#0f1626;color:#e8eefb;border:1px solid #3a4666;border-radius:18px;padding:22px;max-width:440px;width:100%;max-height:92vh;overflow:auto'},
   h('div',{style:'font-size:34px;text-align:center'},'🔒'),h('h3',{style:'text-align:center;margin:4px 0'},o.title),h('p',{style:'text-align:center;color:#8e9bb8;font-size:14px'},o.text||''),
   em,ph,...cards,
   h('details',{style:'margin-top:12px;font-size:13px;color:#8e9bb8'},h('summary',{style:'cursor:pointer'},'Already paid? Sign in'),pw,
    h('div',{style:'display:flex;gap:8px;margin-top:8px'},h('button',{style:btn('#6aa5ff','#06101f'),onclick:()=>sign(false)},'Sign in'),h('button',{style:btn('#2a3350','#e8eefb'),onclick:()=>sign(true)},'Create account'))),
   msg,o.blocking?'':h('button',{style:'display:block;margin:10px auto 0;background:none;border:0;color:#8e9bb8;cursor:pointer',onclick:close},'Not now'),
   h('p',{style:'font-size:11px;color:#6b7896;text-align:center;margin-top:10px'},'Education & practice tool. No tips or advice. See Terms and Refund policy.')));
 document.body.appendChild(box)}
const btn=(bg,fg)=>`background:${bg};color:${fg};border:0;border-radius:10px;padding:10px 14px;font-weight:700;cursor:pointer`;
async function pay(op,e,ph,msg){e=(e||'').trim().toLowerCase();if(!/\S+@\S+\.\S+/.test(e))return msg.textContent='Enter a valid email';
 const phone=(ph||'').replace(/\D/g,'');
 if(CFG.razorpayKey&&CFG.orderUrl){msg.textContent='Opening payment…';
  try{if(!window.Razorpay)await new Promise((ok,no)=>{const s=document.createElement('script');s.src='https://checkout.razorpay.com/v1/checkout.js';s.onload=ok;s.onerror=no;document.head.appendChild(s)});
   const r=await fetch(CFG.orderUrl,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({email:e,phone,product_id:op.pid,plan:op.plan})});const d=await r.json();if(!r.ok||!d.order_id)throw new Error(d.error||'Could not start payment');
   new Razorpay({key:CFG.razorpayKey,order_id:d.order_id,amount:d.amount,currency:'INR',name:'BFT Trade Lab',description:op.label,prefill:{email:e,contact:phone},theme:{color:'#6aa5ff'},
    handler:()=>{msg.textContent='Payment received ✅ Sign in with '+e+'. Access turns on within a minute.'}}).open()}catch(x){msg.textContent=x.message||'Payment could not start'}return}
 // WhatsApp flow: the message already carries product, plan and amount, so you know exactly what they want
 const t=`Hi, I want ${op.label}${op.plan==='month'?' (monthly)':op.plan==='once'?' (one-time)':''}. Amount: ${rs(op.amount)}. Product code: ${op.pid}. My email: ${e}${phone?'. Mobile: '+phone:''}`;
 window.open('https://wa.me/'+CFG.wa+'?text='+encodeURIComponent(t),'_blank','noopener');msg.textContent='Pay by UPI, send the screenshot on WhatsApp. We switch it on for '+e+'.'}
function opts(pid,name){const p=P[pid]||{},o=[];
 if(p.price_once)o.push({pid,plan:'once',amount:p.price_once,label:name||p.name,sub:'One-time, lifetime'});
 if(p.price_month)o.push({pid,plan:'month',amount:p.price_month,label:name||p.name,sub:'Monthly, 30 days, renew any time'});return o}
function toolOptions(){const o=opts(TOOL);const b=P.all_tools;if(b&&TOOL){if(b.price_once)o.push({pid:'all_tools',plan:'once',amount:b.price_once,label:b.name,sub:'Journal + Lab + Classroom, one-time'});if(b.price_month)o.push({pid:'all_tools',plan:'month',amount:b.price_month,label:b.name,sub:'Journal + Lab + Classroom, monthly'})}return o}
/* ---------- trial ---------- */
const TK='bftx_t_'+TOOL;let secs=0;const getS=()=>{try{return +localStorage.getItem(TK)||0}catch(e){return 0}};
function upBadge(){let b=document.getElementById('bftx-badge');if(!TOOL||entitled()||!P[TOOL]||P[TOOL].trial_minutes==null){b&&b.remove();return}
 const left=Math.max(0,P[TOOL].trial_minutes*60-secs);if(!b){b=h('div',{id:'bftx-badge',style:'position:fixed;left:10px;bottom:10px;z-index:9999;background:#0f1626;color:#f5c76b;border:1px solid #3a4666;border-radius:99px;padding:5px 12px;font:600 12px system-ui;cursor:pointer',onclick:()=>openTool(false)});document.body.appendChild(b)}
 b.textContent='Free: '+Math.ceil(left/60)+' min left'}
function openTool(blocking){const p=P[TOOL]||{};show({title:blocking?'Free trial finished':'Unlock '+p.name,text:blocking?`Your free ${p.trial_minutes} minutes in ${p.name} are over. Pick a plan to continue. Your data stays saved.`:'Choose a plan.',options:toolOptions(),blocking,owned:entitled})}
async function tick(){if(document.hidden||entitled())return;const p=P[TOOL];if(!p||p.trial_minutes==null)return;secs+=5;try{localStorage.setItem(TK,secs)}catch(e){}upBadge();if(secs>=p.trial_minutes*60&&!box)openTool(true)}
/* ---------- public API ---------- */
window.BFTX={owns,
 entry(count){const p=P[TOOL];if(!p||p.free_entries==null||entitled()||count<p.free_entries)return true;
  show({title:'Free entries used',text:`You have used your ${p.free_entries} free journal entries. Unlock to keep logging.`,options:toolOptions(),blocking:false,owned:entitled});return false},
 async sell(x){await init();const pid='item:'+x.id;let pr=x.price;if(pr==null){const r=await rest('items?select=price&id=eq.'+encodeURIComponent(x.id));pr=r[0]&&r[0].price}
  const o=pr>0?[{pid,plan:'once',amount:pr,label:x.t||x.name||'This item',sub:'Buy just this, lifetime'}]:[];
  if(P.academy&&P.academy.price_once)o.push({pid:'academy',plan:'once',amount:P.academy.price_once,label:P.academy.name,sub:'Every course, PDF and indicator, lifetime'});
  show({title:(x.t||x.name||'Premium content')+' is premium',text:o.length?'Buy just this one, or get everything.':'Ask us on WhatsApp for access.',options:o,blocking:false,owned:()=>owns(x)})}};
init().then(()=>{if(!TOOL)return;secs=getS();upBadge();setInterval(tick,5000);const p=P[TOOL];if(p&&p.trial_minutes!=null&&secs>=p.trial_minutes*60&&!entitled())openTool(true)});
})();
