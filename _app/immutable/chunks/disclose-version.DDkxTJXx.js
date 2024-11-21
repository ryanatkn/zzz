import{af as d,ag as N,ah as V,ai as W,aj as m,ak as j,al as U,D as o,am as I,L as Y,an as T,ao as M,ap as $,aq as q,ar as z,as as G,at as A,au as D,av as H,aw as K,K as J,ax as E,M as g,aa as Q,q as X,ac as Z,I as ee,Y as b,a0 as w,ay as te,az as ae,h as _,m as c,k as re,i as ne}from"./runtime.-JsZzBAw.js";function C(e){return{f:0,v:e,reactions:null,equals:z,version:0}}function me(e){return se(C(e))}function Ee(e,t=!1){const a=C(e);return t||(a.equals=J),a}function se(e){return d!==null&&d.f&N&&(m===null?G([e]):m.push(e)),e}function ge(e,t){return d!==null&&V()&&d.f&(N|W)&&(m===null||!m.includes(e))&&j(),ie(e,t)}function ie(e,t){return e.equals(t)||(e.v=t,e.version=U(),O(e,T),o!==null&&o.f&I&&!(o.f&Y)&&(A!==null&&A.includes(e)?(M(o,T),q(o)):D===null?H([e]):D.push(e))),t}function O(e,t){var a=e.reactions;if(a!==null)for(var i=a.length,n=0;n<i;n++){var r=a[n],s=r.f;s&T||(M(r,t),s&(I|$)&&(s&N?O(r,K):q(r)))}}function ue(e){var t=d,a=o;E(null),g(null);try{return e()}finally{E(t),g(a)}}const oe=new Set,le=new Set;function ce(e,t,a,i){function n(r){if(i.capture||fe.call(t,r),!r.cancelBubble)return ue(()=>a.call(this,r))}return e.startsWith("pointer")||e.startsWith("touch")||e==="wheel"?X(()=>{t.addEventListener(e,n,i)}):t.addEventListener(e,n,i),n}function we(e,t,a,i,n){var r={capture:i,passive:n},s=ce(e,t,a,r);(t===document.body||t===window||t===document)&&Q(()=>{t.removeEventListener(e,s,r)})}function ye(e){for(var t=0;t<e.length;t++)oe.add(e[t]);for(var a of le)a(e)}function fe(e){var S;var t=this,a=t.ownerDocument,i=e.type,n=((S=e.composedPath)==null?void 0:S.call(e))||[],r=n[0]||e.target,s=0,f=e.__root;if(f){var u=n.indexOf(f);if(u!==-1&&(t===document||t===window)){e.__root=t;return}var k=n.indexOf(t);if(k===-1)return;u<=k&&(s=u)}if(r=n[s]||e.target,r!==t){Z(e,"currentTarget",{configurable:!0,get(){return r||a}});var x=d,B=o;E(null),g(null);try{for(var v,L=[];r!==null;){var y=r.assignedSlot||r.parentNode||r.host||null;try{var p=r["__"+i];if(p!==void 0&&!r.disabled)if(ee(p)){var[F,...P]=p;F.apply(r,[e,...P])}else p.call(r,e)}catch(h){v?L.push(h):v=h}if(e.cancelBubble||y===t||y===null)break;r=y}if(v){for(let h of L)queueMicrotask(()=>{throw h});throw v}}finally{e.__root=t,delete e.currentTarget,E(x),g(B)}}}function R(e){var t=document.createElement("template");return t.innerHTML=e,t.content}function l(e,t){var a=o;a.nodes_start===null&&(a.nodes_start=e,a.nodes_end=t)}function Te(e,t){var a=(t&te)!==0,i=(t&ae)!==0,n,r=!e.startsWith("<!>");return()=>{if(_)return l(c,null),c;n===void 0&&(n=R(r?e:"<!>"+e),a||(n=w(n)));var s=i?document.importNode(n,!0):n.cloneNode(!0);if(a){var f=w(s),u=s.lastChild;l(f,u)}else l(s,s);return s}}function be(e,t,a="svg"){var i=!e.startsWith("<!>"),n=`<${a}>${i?e:"<!>"+e}</${a}>`,r;return()=>{if(_)return l(c,null),c;if(!r){var s=R(n),f=w(s);r=w(f)}var u=r.cloneNode(!0);return l(u,u),u}}function Ne(e=""){if(!_){var t=b(e+"");return l(t,t),t}var a=c;return a.nodeType!==3&&(a.before(a=b()),re(a)),l(a,a),a}function ke(){if(_)return l(c,null),c;var e=document.createDocumentFragment(),t=document.createComment(""),a=b();return e.append(t,a),l(t,a),e}function Le(e,t){if(_){o.nodes_end=c,ne();return}e!==null&&e.before(t)}function Se(e){return e.endsWith("capture")&&e!=="gotpointercapture"&&e!=="lostpointercapture"}const de=["beforeinput","click","change","dblclick","contextmenu","focusin","focusout","input","keydown","keyup","mousedown","mousemove","mouseout","mouseover","mouseup","pointerdown","pointermove","pointerout","pointerover","pointerup","touchend","touchmove","touchstart"];function Ae(e){return de.includes(e)}const _e={formnovalidate:"formNoValidate",ismap:"isMap",nomodule:"noModule",playsinline:"playsInline",readonly:"readOnly",srcobject:"srcObject"};function De(e){return e=e.toLowerCase(),_e[e]??e}const ve=["touchstart","touchmove"];function Ie(e){return ve.includes(e)}const pe="5";typeof window<"u"&&(window.__svelte||(window.__svelte={v:new Set})).v.add(pe);export{Le as a,ge as b,ke as c,oe as d,l as e,Ne as f,me as g,fe as h,Ie as i,ie as j,R as k,Se as l,Ee as m,be as n,ce as o,ye as p,De as q,le as r,C as s,Te as t,Ae as u,we as v};
