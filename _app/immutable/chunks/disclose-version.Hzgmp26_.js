import{ac as N,ae as k,a4 as A,x as I,B as E,K as d,Y as y,af as T,ag as M,D as p,J as l,I as D,O}from"./runtime.N-NP-VGW.js";const x=new Set,C=new Set;function P(e,r,t,i){function n(a){if(i.capture||B.call(r,a),!a.cancelBubble)return t.call(this,a)}return e.startsWith("pointer")||e.startsWith("touch")||e==="wheel"?I(()=>{r.addEventListener(e,n,i)}):r.addEventListener(e,n,i),n}function $(e,r,t,i,n){var a={capture:i,passive:n},o=P(e,r,t,a);(r===document.body||r===window||r===document)&&N(()=>{r.removeEventListener(e,o,a)})}function q(e){for(var r=0;r<e.length;r++)x.add(e[r]);for(var t of C)t(e)}function B(e){var w;var r=this,t=r.ownerDocument,i=e.type,n=((w=e.composedPath)==null?void 0:w.call(e))||[],a=n[0]||e.target,o=0,f=e.__root;if(f){var s=n.indexOf(f);if(s!==-1&&(r===document||r===window)){e.__root=r;return}var c=n.indexOf(r);if(c===-1)return;s<=c&&(o=s)}if(a=n[o]||e.target,a!==r){k(e,"currentTarget",{configurable:!0,get(){return a||t}});try{for(var _,v=[];a!==null;){var g=a.assignedSlot||a.parentNode||a.host||null;try{var h=a["__"+i];if(h!==void 0&&!a.disabled)if(A(h)){var[S,...L]=h;S.apply(a,[e,...L])}else h.call(a,e)}catch(m){_?v.push(m):_=m}if(e.cancelBubble||g===r||g===null)break;a=g}if(_){for(let m of v)queueMicrotask(()=>{throw m});throw _}}finally{e.__root=r,delete e.currentTarget}}}function b(e){var r=document.createElement("template");return r.innerHTML=e,r.content}function u(e,r){var t=y;t.nodes_start===null&&(t.nodes_start=e,t.nodes_end=r)}function G(e,r){var t=(r&T)!==0,i=(r&M)!==0,n,a=!e.startsWith("<!>");return()=>{if(p)return u(l,null),l;n===void 0&&(n=b(a?e:"<!>"+e),t||(n=d(n)));var o=i?document.importNode(n,!0):n.cloneNode(!0);if(t){var f=d(o),s=o.lastChild;u(f,s)}else u(o,o);return o}}function j(e,r,t="svg"){var i=!e.startsWith("<!>"),n=(r&T)!==0,a=`<${t}>${i?e:"<!>"+e}</${t}>`,o;return()=>{if(p)return u(l,null),l;if(!o){var f=b(a),s=d(f);if(n)for(o=document.createDocumentFragment();d(s);)o.appendChild(d(s));else o=d(s)}var c=o.cloneNode(!0);if(n){var _=d(c),v=c.lastChild;u(_,v)}else u(c,c);return c}}function z(e=""){if(!p){var r=E(e+"");return u(r,r),r}var t=l;return t.nodeType!==3&&(t.before(t=E()),D(t)),u(t,t),t}function H(){if(p)return u(l,null),l;var e=document.createDocumentFragment(),r=document.createComment(""),t=E();return e.append(r,t),u(r,t),e}function J(e,r){if(p){y.nodes_end=l,O();return}e!==null&&e.before(r)}function K(e){return e.endsWith("capture")&&e!=="gotpointercapture"&&e!=="lostpointercapture"}const V=["beforeinput","click","change","dblclick","contextmenu","focusin","focusout","input","keydown","keyup","mousedown","mousemove","mouseout","mouseover","mouseup","pointerdown","pointermove","pointerout","pointerover","pointerup","touchend","touchmove","touchstart"];function Y(e){return V.includes(e)}const W={formnovalidate:"formNoValidate",ismap:"isMap",nomodule:"noModule",playsinline:"playsInline",readonly:"readOnly"};function Q(e){return e=e.toLowerCase(),W[e]??e}const R=["touchstart","touchmove"];function X(e){return R.includes(e)}const F="5";typeof window<"u"&&(window.__svelte||(window.__svelte={v:new Set})).v.add(F);export{J as a,x as b,u as c,H as d,q as e,z as f,b as g,B as h,X as i,K as j,P as k,Q as l,Y as m,j as n,$ as o,C as r,G as t};
