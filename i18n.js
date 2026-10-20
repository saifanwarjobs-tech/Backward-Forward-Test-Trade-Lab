/* BFT language switch: English | हिंदी. Page text stays the source of truth (English, some Hinglish).
   Hindi is applied on top by exact-text lookup, so nothing breaks if a string has no translation. */
(function(){
const HI={
'Backtest':'बैकटेस्ट','Forward Test':'फॉरवर्ड टेस्ट','Balance':'बैलेंस','Equity':'इक्विटी','Margin':'मार्जिन','Free margin':'फ्री मार्जिन','Floating P/L':'फ्लोटिंग P/L',
'Classroom':'क्लासरूम','Data':'डेटा','Settings':'सेटिंग्स','Full screen chart':'चार्ट फुल स्क्रीन','Choose market data':'मार्केट डेटा चुनें','Pan / zoom':'खिसकाएं / ज़ूम',
'Horizontal line':'हॉरिज़ॉन्टल लाइन','Zone (drag)':'ज़ोन (ड्रैग करें)','Trend line (drag)':'ट्रेंड लाइन (ड्रैग करें)','Eraser':'इरेज़र','Latest':'ताज़ा','Center':'बीच में','Auto':'ऑटो','Max':'बड़ा करें',
'Jump to the latest candle':'आखिरी कैंडल पर जाएं','Next':'अगला','Play':'चलाएं','Day':'दिन','Fresh start':'नई शुरुआत','Clear this mode and start again on a new random day':'इस मोड को साफ़ करके नए दिन से शुरू करें',
'x Indicators':'x इंडिकेटर्स','pause on SL/TP':'SL/TP पर रुकें','Go':'जाएं','blind':'ब्लाइंड','Positions':'पोज़िशन','History':'हिस्ट्री','Backtest vs Forward':'बैकटेस्ट बनाम फॉरवर्ड',
'Download a shareable image of your results':'नतीजों की शेयर करने लायक इमेज डाउनलोड करें','Report':'रिपोर्ट','Export trades':'ट्रेड्स डाउनलोड करें','Download closed trades as CSV':'बंद ट्रेड्स CSV में डाउनलोड करें',
'Collapse':'छोटा करें','Expand':'बड़ा करें','Collapse or expand the trades panel':'ट्रेड पैनल छोटा / बड़ा करें','Collapse or expand the order panel':'ऑर्डर पैनल छोटा / बड़ा करें',
'Hide drawing tools':'ड्रॉइंग टूल छुपाएं','Show drawing tools':'ड्रॉइंग टूल दिखाएं','Light / dark theme':'लाइट / डार्क थीम','New order':'नया ऑर्डर','Lots':'लॉट','Trail (pts)':'ट्रेल (pts)','Order':'ऑर्डर',
'Market':'मार्केट','Limit':'लिमिट','Stop':'स्टॉप','Price':'प्राइस','price':'प्राइस','Close all positions':'सभी पोज़िशन बंद करें','Strategy lock':'स्ट्रैटेजी लॉक','Lock rules & start':'रूल्स लॉक करके शुरू करें',
'Equity after every trade':'हर ट्रेड के बाद इक्विटी','Loading market data…':'मार्केट डेटा लोड हो रहा है…','Bull candle':'बुल कैंडल','Bear candle':'बियर कैंडल','Lot size (qty)':'लॉट साइज़ (मात्रा)',
'Spread (pts)':'स्प्रेड (pts)','Charges':'चार्जेस','NSE futures (STT, GST…)':'NSE फ्यूचर्स (STT, GST…)','Simple %':'सिंपल %','None':'कोई नहीं','Grid':'ग्रिड','On':'चालू','Off':'बंद',
'Demo balance':'डेमो बैलेंस','Save & reset demo account':'सेव करके डेमो अकाउंट रीसेट करें','Close':'बंद करें','Calm':'शांत','Normal':'सामान्य','Wild':'तेज़','Run scenario':'सिनेरियो चलाएं','Exit scenario':'सिनेरियो से बाहर',
'Long (BUY) position: click on chart, then drag the SL / TP lines':'लॉन्ग (BUY) पोज़िशन: चार्ट पर क्लिक करें, फिर SL / TP लाइनें ड्रैग करें',
'Short (SELL) position: click on chart, then drag the SL / TP lines':'शॉर्ट (SELL) पोज़िशन: चार्ट पर क्लिक करें, फिर SL / TP लाइनें ड्रैग करें',
'Fibonacci retracement: drag from swing start to swing end':'फिबोनाची: स्विंग की शुरुआत से अंत तक ड्रैग करें','Pencil path scenario':'पेंसिल से अपना सिनेरियो बनाएं',
'Example shape. Close a trade to start yours':'उदाहरण। एक ट्रेड बंद करें, आपकी कर्व शुरू होगी',
/* classroom */
'Home':'होम','How to use':'कैसे इस्तेमाल करें','Help':'मदद','Live':'लाइव','Export all':'सब एक्सपोर्ट करें','Candle Path':'कैंडल पाथ','Pen':'पेन','Highlight':'हाइलाइट','Arrow':'तीर','Zone':'ज़ोन','T Text':'T टेक्स्ट',
'Laser':'लेज़र','Lessons':'लेसन','Size':'साइज़','Step':'स्टेप','Replay':'रीप्ले','Speed':'स्पीड','Candle':'कैंडल','path':'पाथ','1s pause':'1 सेकंड रुकें','Black board':'ब्लैक बोर्ड','White board':'व्हाइट बोर्ड',
'Chalkboard':'चॉक बोर्ड','grid':'ग्रिड','logo':'लोगो','Brand · Pro':'ब्रांड · Pro','Add brand':'ब्रांड जोड़ें','Brand':'ब्रांड','Undo':'वापस','Reset':'रीसेट','Record':'रिकॉर्ड','voice':'आवाज़','music':'संगीत',
'Toolbar':'टूलबार','Fullscreen':'फुलस्क्रीन','Start teaching':'पढ़ाना शुरू करें','Welcome to the Classroom':'क्लासरूम में स्वागत है','Cancel':'रद्द करें','Yes, reset':'हाँ, रीसेट करें','Reset the board?':'बोर्ड रीसेट करें?',
'Add on board':'बोर्ड पर जोड़ें','Search lessons… e.g. flag, hammer, trap, sell, double top':'लेसन खोजें… जैसे flag, hammer, trap, sell, double top','Export all lessons':'सभी लेसन एक्सपोर्ट करें',
'Video type':'वीडियो टाइप','Category':'कैटेगरी','Flow':'फ्लो','Explanation':'व्याख्या','Background music':'बैकग्राउंड म्यूज़िक','Start export':'एक्सपोर्ट शुरू करें','Live / Reels mode':'लाइव / रील्स मोड',
'Shuffle (random)':'शफ़ल (रैंडम)','In order':'क्रम से','Gap between lessons':'लेसन के बीच गैप','Format':'फॉर्मेट','Voice':'आवाज़','Voice type':'आवाज़ का प्रकार','Start Live':'लाइव शुरू करें','Exit Live':'लाइव बंद करें',
'Slow':'धीमा','Fast':'तेज़','Candle speed':'कैंडल की स्पीड','Sabhi':'सभी','Haan':'हाँ','Nahi (Shorts ke liye)':'नहीं (Shorts के लिए)','Sirf 3 (test)':'सिर्फ़ 3 (टेस्ट)','Pehle kitne lessons (test)':'पहले कितने लेसन (टेस्ट)',
'Poori (Entry, SL, Target, Galti, Yaad rakho)':'पूरी (Entry, SL, Target, गलती, याद रखो)','Chhoti (sirf pehla vaakya)':'छोटी (सिर्फ़ पहला वाक्य)','Normal (thoda pause ke saath)':'सामान्य (थोड़े पॉज़ के साथ)',
'Non-stop (bina pause, Shorts ke liye best)':'नॉन-स्टॉप (बिना पॉज़, Shorts के लिए बेस्ट)','Draw a price path with Candle Path':'Candle Path से प्राइस पाथ बनाएं'};
const EN={'Sabhi':'All','Haan':'Yes','Nahi (Shorts ke liye)':'No (for Shorts)','Sirf 3 (test)':'Only 3 (test)','Pehle kitne lessons (test)':'How many lessons first (test)',
'Poori (Entry, SL, Target, Galti, Yaad rakho)':'Full (Entry, SL, Target, Mistake, Remember)','Chhoti (sirf pehla vaakya)':'Short (first sentence only)','Normal (thoda pause ke saath)':'Normal (with short pauses)',
'Non-stop (bina pause, Shorts ke liye best)':'Non-stop (no pause, best for Shorts)','Har label pe 1 second ruk-ke aage badhe':'Pause 1 second at every label','Halka background music (voice ke waqt dheema)':'Soft background music (lower during voice)',
'Hide toolbar (video me toolbar record nahi hota)':'Hide toolbar (it is not recorded in the video)','Har lesson ki alag video file (Reels ya Video)':'One video file per lesson (Reels or Video)'};
Object.keys(EN).forEach(k=>{if(!HI[k])HI[k]=EN[k]});
/* whole-block translations (HTML) for blocks that carry inline tags */
const HK={
tlTip:'टिप: ट्रेड खोलने के बाद चार्ट पर उसकी <b>SL / TP लाइन को ड्रैग करके</b> बदलें।',
tlDrag:'<b>चार्ट पर अपना SL और TP खिसकाएं</b><br>आपके ट्रेड पर अब लाल <b>SL</b> और हरी <b>TP</b> लाइन दिख रही है। <b>लाइन को ऊपर या नीचे ड्रैग</b> करके बदलें। लाइन नहीं है? चार्ट पर <b>+ SL</b> या <b>+ TP</b> पर क्लिक करें।',
tlEmpty:'<b style="color:var(--tx,#e6edf7)">अभी कोई ओपन पोज़िशन नहीं</b><br>1. चार्ट आगे बढ़ाने के लिए <b>Next</b> या <b>Play</b> दबाएं।<br>2. <b>BUY</b> या <b>SELL</b> दबाएं। चाहें तो SL और TP लगाएं।<br>3. <b>Backtest vs Forward</b> खोलकर देखें कि आपका एज नए डेटा पर टिकता है या नहीं।',
clsIntro:'पढ़ाने के लिए खाली बोर्ड। तीन आसान स्टेप:',
clsSteps:'<li><b>शुरू करें</b>: 🕯 <b>Candle Path</b> से अपना प्राइस पाथ बनाएं (कैंडल उसी पर चलेंगी), या 📚 <b>Lessons</b> खोलकर 100+ तैयार लेसन में से चुनें।</li><li><b>समझाएं</b>: रोकने के लिए <b>Space</b> दबाएं, ⏭ से एक कैंडल आगे बढ़ाएं, 🔴 Laser से इशारा करें, ✏️ Pen से लिखें।</li><li><b>रिकॉर्ड करें</b>: ☰ से टूलबार छुपाएं, ● <b>Record</b> दबाएं, बोलें, फिर <b>Stop &amp; Download</b> दबाएं।</li>',
clsMist:'गलती हो गई? ↶ Undo, ⌫ Eraser, या 🗑 <b>Reset</b> से दोबारा शुरू करें।'};
const RULES=[
[/^(Collapse|Expand) · (\d+) open$/,m=>(m[1]==='Collapse'?'छोटा करें':'बड़ा करें')+' · '+m[2]+' खुले'],
[/^FREE · (\d+) min$/,m=>'फ्री · '+m[1]+' मिनट'],[/^Free: (\d+) min left · Upgrade$/,m=>'फ्री: '+m[1]+' मिनट बाकी · अपग्रेड'],
[/^or press \/ to pick one of (\d+) ready lessons$/,m=>'या / दबाकर '+m[1]+' तैयार लेसन में से चुनें']];
let lang='en';try{lang=localStorage.getItem('bft_lang')==='hi'?'hi':'en'}catch(e){}
const RX=/^([^A-Za-z\u0900-\u097F]*)([\s\S]*?)([^A-Za-z\u0900-\u097F]*)$/;
function tr(s,l){const m=RX.exec(s);if(!m||!m[2])return s;const c=m[2],d=l==='hi'?HI:EN;let v=d[c];
 if(v==null&&l==='hi')for(const r of RULES){const x=r[0].exec(c);if(x){v=r[1](x);break}}return v==null?s:m[1]+v+m[3]}
const NS=new WeakMap(),AS=new WeakMap();let busy=false;
const okText=n=>{const p=n.parentElement;return !p||(!/^(SCRIPT|STYLE|TEXTAREA|CANVAS|NOSCRIPT)$/.test(p.tagName)&&!p.closest('[data-k],[data-nox]'))};
function doText(n){let r=NS.get(n);if(!r||n.nodeValue!==r.t){r={o:n.nodeValue,t:n.nodeValue};NS.set(n,r)}const out=tr(r.o,lang);if(out!==n.nodeValue)n.nodeValue=out;r.t=out}
function doEl(e){if(e.closest&&e.closest('[data-nox]'))return;
 ['title','placeholder'].forEach(a=>{if(!e.hasAttribute(a))return;let m=AS.get(e);if(!m){m={};AS.set(e,m)}let r=m[a];const cur=e.getAttribute(a);if(!r||cur!==r.t){r={o:cur,t:cur};m[a]=r}const out=tr(r.o,lang);if(out!==cur)e.setAttribute(a,out);r.t=out});
 const k=e.getAttribute&&e.getAttribute('data-k');if(k){if(e._o===undefined)e._o=e.innerHTML;const want=lang==='hi'&&HK[k]?HK[k]:e._o;if(e.innerHTML!==want)e.innerHTML=want}}
function walk(root){if(root.nodeType===3){if(okText(root))doText(root);return}if(root.nodeType!==1)return;
 doEl(root);root.querySelectorAll('[title],[placeholder],[data-k]').forEach(doEl);
 const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode:n=>okText(n)?1:2});let n;while(n=w.nextNode())doText(n)}
const mo=new MutationObserver(recs=>{if(busy)return;busy=true;try{recs.forEach(r=>{if(r.type==='characterData')walk(r.target);else r.addedNodes.forEach(walk)})}finally{mo.takeRecords();busy=false}});
function all(){busy=true;try{walk(document.body)}finally{mo.takeRecords();busy=false}}
function label(){document.querySelectorAll('.bft-lg').forEach(b=>{b.textContent=lang==='hi'?'🌐 हिं':'🌐 EN';b.title=lang==='hi'?'Switch to English':'हिंदी में बदलें'})}
function set(l){lang=l==='hi'?'hi':'en';try{localStorage.setItem('bft_lang',lang)}catch(e){}document.documentElement.lang=lang;all();label();window.dispatchEvent(new Event('resize'))}
function mount(){document.querySelectorAll('#lgslot').forEach(s=>{if(s.firstChild)return;const b=document.createElement('button');b.className='bft-lg '+(s.dataset.cls||'');b.setAttribute('data-nox','');b.onclick=()=>set(lang==='hi'?'en':'hi');s.appendChild(b)})}
function init(){mount();document.documentElement.lang=lang;all();label();mo.observe(document.body,{childList:true,subtree:true,characterData:true})}
window.BFTL={t:s=>tr(s,lang),set,get:()=>lang};
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();
