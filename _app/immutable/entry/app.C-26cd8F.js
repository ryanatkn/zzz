const __vite__mapDeps=(i,m=__vite__mapDeps,d=(m.f||(m.f=["_app/immutable/nodes/0.Di9-PSoc.js","_app/immutable/chunks/disclose-version.DDkxTJXx.js","_app/immutable/chunks/runtime.-JsZzBAw.js","_app/immutable/chunks/store.f2EFjb3D.js","_app/immutable/chunks/if.D9UcrOZM.js","_app/immutable/chunks/string.-zY814zy.js","_app/immutable/chunks/props.EqimzTDr.js","_app/immutable/chunks/index-client.C5zUTiT9.js","_app/immutable/chunks/pkg.D-WwuCi0.js","_app/immutable/assets/0.S6iGPJJd.css","_app/immutable/nodes/1.DqorNRgG.js","_app/immutable/chunks/stores.mTM-7JKr.js","_app/immutable/chunks/entry.IRiUlEzv.js","_app/immutable/chunks/paths.CuWMjyrQ.js","_app/immutable/nodes/2.Bu9f7CnX.js","_app/immutable/chunks/logos.DTvkRBwh.js","_app/immutable/assets/logos.bqgmxUqm.css","_app/immutable/assets/2.4ZvyTriW.css","_app/immutable/nodes/3.D3jozHYv.js","_app/immutable/assets/3.D56UXTXS.css"])))=>i.map(i=>d[i]);
var F=n=>{throw TypeError(n)};var B=(n,t,r)=>t.has(n)||F("Cannot "+r);var u=(n,t,r)=>(B(n,t,"read from private field"),r?r.call(n):t.get(n)),S=(n,t,r)=>t.has(n)?F("Cannot add the same private member more than once"):t instanceof WeakSet?t.add(n):t.set(n,r),T=(n,t,r,o)=>(B(n,t,"write to private field"),o?o.call(n,r):t.set(n,r),r);import{h as G,i as J,b as K,E as Q,e as X,m as Z,g as p,C as _,T as M,ab as $,ac as tt,ad as et,x as rt,f as w,p as st,a as nt,ae as at,s as ot,c as ct,t as it,r as ut,V as L}from"../chunks/runtime.-JsZzBAw.js";import{b as A,m as lt,c as O,a as b,t as W,f as dt,g as V}from"../chunks/disclose-version.DDkxTJXx.js";import{h as ft,m as mt,u as ht,a as _t}from"../chunks/store.f2EFjb3D.js";import{i as D}from"../chunks/if.D9UcrOZM.js";import{p as I,a as vt}from"../chunks/props.EqimzTDr.js";import{o as gt,b as j}from"../chunks/index-client.C5zUTiT9.js";function U(n,t,r){G&&J();var o=n,a,i;K(()=>{a!==(a=t())&&(i&&(p(i),i=null),a&&(i=X(()=>r(o,a))))},Q),G&&(o=Z)}function yt(n){return class extends bt{constructor(t){super({component:n,...t})}}}var v,l;class bt{constructor(t){S(this,v);S(this,l);var i;var r=new Map,o=(e,s)=>{var c=lt(s);return r.set(e,c),c};const a=new Proxy({...t.props||{},$$events:{}},{get(e,s){return _(r.get(s)??o(s,Reflect.get(e,s)))},has(e,s){return s===M?!0:(_(r.get(s)??o(s,Reflect.get(e,s))),Reflect.has(e,s))},set(e,s,c){return A(r.get(s)??o(s,c),c),Reflect.set(e,s,c)}});T(this,l,(t.hydrate?ft:mt)(t.component,{target:t.target,anchor:t.anchor,props:a,context:t.context,intro:t.intro??!1,recover:t.recover})),(!((i=t==null?void 0:t.props)!=null&&i.$$host)||t.sync===!1)&&$(),T(this,v,a.$$events);for(const e of Object.keys(u(this,l)))e==="$set"||e==="$destroy"||e==="$on"||tt(this,e,{get(){return u(this,l)[e]},set(s){u(this,l)[e]=s},enumerable:!0});u(this,l).$set=e=>{Object.assign(a,e)},u(this,l).$destroy=()=>{ht(u(this,l))}}$set(t){u(this,l).$set(t)}$on(t,r){u(this,v)[t]=u(this,v)[t]||[];const o=(...a)=>r.call(this,...a);return u(this,v)[t].push(o),()=>{u(this,v)[t]=u(this,v)[t].filter(a=>a!==o)}}$destroy(){u(this,l).$destroy()}}v=new WeakMap,l=new WeakMap;const Et="modulepreload",Pt=function(n){return"/"+n},N={},k=function(t,r,o){let a=Promise.resolve();if(r&&r.length>0){document.getElementsByTagName("link");const e=document.querySelector("meta[property=csp-nonce]"),s=(e==null?void 0:e.nonce)||(e==null?void 0:e.getAttribute("nonce"));a=Promise.allSettled(r.map(c=>{if(c=Pt(c),c in N)return;N[c]=!0;const g=c.endsWith(".css"),R=g?'[rel="stylesheet"]':"";if(document.querySelector(`link[href="${c}"]${R}`))return;const m=document.createElement("link");if(m.rel=g?"stylesheet":Et,g||(m.as="script"),m.crossOrigin="",m.href=c,s&&m.setAttribute("nonce",s),document.head.appendChild(m),g)return new Promise((h,d)=>{m.addEventListener("load",h),m.addEventListener("error",()=>d(new Error(`Unable to preload CSS for ${c}`)))})}))}function i(e){const s=new Event("vite:preloadError",{cancelable:!0});if(s.payload=e,window.dispatchEvent(s),!s.defaultPrevented)throw e}return a.then(e=>{for(const s of e||[])s.status==="rejected"&&i(s.reason);return t().catch(i)})},Dt={};var Rt=W('<div id="svelte-announcer" aria-live="assertive" aria-atomic="true" style="position: absolute; left: 0; top: 0; clip: rect(0 0 0 0); clip-path: inset(50%); overflow: hidden; white-space: nowrap; width: 1px; height: 1px"><!></div>'),xt=W("<!> <!>",1);function wt(n,t){nt(t,!0);let r=I(t,"components",23,()=>[]),o=I(t,"data_0",3,null),a=I(t,"data_1",3,null);et(()=>t.stores.page.set(t.page)),rt(()=>{t.stores,t.page,t.constructors,r(),t.form,o(),a(),t.stores.page.notify()});let i=V(!1),e=V(!1),s=V(null);gt(()=>{const h=t.stores.page.subscribe(()=>{_(i)&&(A(e,!0),at().then(()=>{A(s,vt(document.title||"untitled page"))}))});return A(i,!0),h});const c=L(()=>t.constructors[1]);var g=xt(),R=w(g);D(R,()=>t.constructors[1],h=>{var d=O();const E=L(()=>t.constructors[0]);var P=w(d);U(P,()=>_(E),(y,C)=>{j(C(y,{get data(){return o()},get form(){return t.form},children:(f,kt)=>{var q=O(),Y=w(q);U(Y,()=>_(c),(z,H)=>{j(H(z,{get data(){return a()},get form(){return t.form}}),x=>r()[1]=x,()=>{var x;return(x=r())==null?void 0:x[1]})}),b(f,q)},$$slots:{default:!0}}),f=>r()[0]=f,()=>{var f;return(f=r())==null?void 0:f[0]})}),b(h,d)},h=>{var d=O();const E=L(()=>t.constructors[0]);var P=w(d);U(P,()=>_(E),(y,C)=>{j(C(y,{get data(){return o()},get form(){return t.form}}),f=>r()[0]=f,()=>{var f;return(f=r())==null?void 0:f[0]})}),b(h,d)});var m=ot(R,2);D(m,()=>_(i),h=>{var d=Rt(),E=ct(d);D(E,()=>_(e),P=>{var y=dt();it(()=>_t(y,_(s))),b(P,y)}),ut(d),b(h,d)}),b(n,g),st()}const It=yt(wt),jt=[()=>k(()=>import("../nodes/0.Di9-PSoc.js"),__vite__mapDeps([0,1,2,3,4,5,6,7,8,9])),()=>k(()=>import("../nodes/1.DqorNRgG.js"),__vite__mapDeps([10,1,2,3,11,12,13])),()=>k(()=>import("../nodes/2.Bu9f7CnX.js"),__vite__mapDeps([14,1,2,5,15,4,16,13,17])),()=>k(()=>import("../nodes/3.D3jozHYv.js"),__vite__mapDeps([18,1,2,3,4,5,6,15,16,11,12,13,8,19]))],Ut=[],qt={"/":[2],"/about":[3]},Ft={handleError:({error:n})=>{console.error(n)},reroute:()=>{}};export{qt as dictionary,Ft as hooks,Dt as matchers,jt as nodes,It as root,Ut as server_loads};