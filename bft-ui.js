/* BFT shared theme. One light / dark choice for the whole site, stored as bft_ui.
   Load it in <head>, before the CSS, so the page never flashes the wrong theme:
     <script src="bft-ui.js" data-default="dark"></script>   (page that was dark-only before)
     <script src="bft-ui.js"></script>                       (page that follows the device until the user chooses)
   It sets html[data-ui] to "light" or "dark" once a choice is saved (and html[data-th] too when the tag has the
   attribute data-attr-th: only Market Movers and Reality Check need that).
   Until then nothing is set, so each page keeps its own default. */
(function(){
var R=document.documentElement,K='bft_ui',cs=document.currentScript,DEF=(cs&&cs.getAttribute('data-default'))||'',TH=!!(cs&&cs.hasAttribute('data-attr-th')),subs=[];
function sys(){try{return matchMedia('(prefers-color-scheme:light)').matches?'light':'dark'}catch(e){return'dark'}}
function stored(){var v=null;try{v=localStorage.getItem(K);if(v!=='light'&&v!=='dark'){v=localStorage.getItem('bft_scr_th')}}catch(e){}return v==='light'||v==='dark'?v:null}
function eff(){return stored()||DEF||sys()}
function paint(){
 var v=stored();
 if(v){R.dataset.ui=v;if(TH)R.dataset.th=v}else{delete R.dataset.ui;if(TH)delete R.dataset.th}
 var m=document.querySelector('meta[name=theme-color]');if(m)m.setAttribute('content',eff()==='light'?'#f4f6fb':'#070b14');
}
function fire(){var v=eff();subs.forEach(function(f){try{f(v)}catch(e){}})}
function set(v){
 if(v!=='light'&&v!=='dark')return;
 try{localStorage.setItem(K,v)}catch(e){}
 paint();fire();
}
window.BFTT={get:eff,stored:stored,set:set,toggle:function(){set(eff()==='light'?'dark':'light')},on:function(f){subs.push(f)},
 /* a page that has its own default (not the device setting) can tell us, so the button shows the right icon */
 def:function(v){if((v==='light'||v==='dark')&&DEF!==v){DEF=v;paint();fire()}}};
paint();
/* keep several open tabs in step */
addEventListener('storage',function(e){if(e.key===K){paint();fire()}});
/* meta tag may not exist yet when this runs in <head>; fix it once the document is ready */
document.addEventListener('DOMContentLoaded',paint);
})();
