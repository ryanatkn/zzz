var yn=Array.isArray,wn=Array.from,Tn=Object.defineProperty,et=Object.getOwnPropertyDescriptor,Ht=Object.getOwnPropertyDescriptors,mn=Object.prototype,An=Array.prototype,Yt=Object.getPrototypeOf;function gn(t){return typeof t=="function"}const In=()=>{};function jt(t){for(var n=0;n<t.length;n++)t[n]()}const w=2,lt=4,k=8,it=16,g=32,K=64,S=128,B=256,h=512,A=1024,L=2048,N=4096,H=8192,Ut=16384,ft=32768,Rn=65536,Bt=1<<18,_t=1<<19,st=Symbol("$state"),Sn=Symbol("");function ct(t){return t===this.v}function Vt(t,n){return t!=t?n==n:t!==n||t!==null&&typeof t=="object"||typeof t=="function"}function vt(t){return!Vt(t,this.v)}function $t(t){throw new Error("effect_in_teardown")}function Gt(){throw new Error("effect_in_unowned_derived")}function Kt(t){throw new Error("effect_orphan")}function Zt(){throw new Error("effect_update_depth_exceeded")}function xn(){throw new Error("hydration_failed")}function Dn(t){throw new Error("props_invalid_value")}function On(){throw new Error("state_descriptors_fixed")}function Cn(){throw new Error("state_prototype_fixed")}function zt(){throw new Error("state_unsafe_local_read")}function Wt(){throw new Error("state_unsafe_mutation")}function tt(t){return{f:0,v:t,reactions:null,equals:ct,version:0}}function Nn(t){return Xt(tt(t))}function kn(t,n=!1){var e;const r=tt(t);return n||(r.equals=vt),i!==null&&i.l!==null&&((e=i.l).s??(e.s=[])).push(r),r}function Xt(t){return l!==null&&l.f&w&&(d===null?fn([t]):d.push(t)),t}function Pn(t,n){return l!==null&&J()&&l.f&w&&(d===null||!d.includes(t))&&Wt(),t.equals(n)||(t.v=n,t.version=Nt(),pt(t,A),J()&&u!==null&&u.f&h&&!(u.f&g)&&(p!==null&&p.includes(t)?(y(u,A),z(u)):m===null?_n([t]):m.push(t))),n}function pt(t,n){var r=t.reactions;if(r!==null)for(var e=J(),s=r.length,o=0;o<s;o++){var a=r[o],f=a.f;f&A||!e&&a===u||(y(a,n),f&(h|S)&&(f&w?pt(a,L):z(a)))}}const bn=1,Fn=2,qn=4,Mn=8,Ln=16,Hn=1,Yn=2,jn=4,Un=8,Bn=16,Vn=1,$n=2,Jt="[",Qt="[!",tn="]",ht={},Gn=Symbol();function Et(t){console.warn("hydration_mismatch")}let R=!1;function Kn(t){R=t}let _;function F(t){if(t===null)throw Et(),ht;return _=t}function Zn(){return F(x(_))}function zn(t){if(R){if(x(_)!==null)throw Et(),ht;_=t}}function Wn(t=1){if(R){for(var n=t,r=_;n--;)r=x(r);_=r}}function Xn(){for(var t=0,n=_;;){if(n.nodeType===8){var r=n.data;if(r===tn){if(t===0)return n;t-=1}else(r===Jt||r===Qt)&&(t+=1)}var e=x(n);n.remove(),n=e}}var ot,nn,dt,yt;function Jn(){if(ot===void 0){ot=window,nn=document;var t=Element.prototype,n=Node.prototype;dt=et(n,"firstChild").get,yt=et(n,"nextSibling").get,t.__click=void 0,t.__className="",t.__attributes=null,t.__e=void 0,Text.prototype.__t=void 0}}function nt(t=""){return document.createTextNode(t)}function W(t){return dt.call(t)}function x(t){return yt.call(t)}function Qn(t){if(!R)return W(t);var n=W(_);return n===null&&(n=_.appendChild(nt())),F(n),n}function tr(t,n){if(!R){var r=W(t);return r instanceof Comment&&r.data===""?x(r):r}if(n&&(_==null?void 0:_.nodeType)!==3){var e=nt();return _==null||_.before(e),F(e),e}return _}function nr(t,n=1,r=!1){let e=R?_:t;for(;n--;)e=x(e);if(!R)return e;var s=e.nodeType;if(r&&s!==3){var o=nt();return e==null||e.before(o),F(o),o}return F(e),e}function rr(t){t.textContent=""}function wt(t){u===null&&l===null&&Kt(),l!==null&&l.f&S&&Gt(),rt&&$t()}function rn(t,n){var r=n.last;r===null?n.last=n.first=t:(r.next=t,t.prev=r,n.last=t)}function P(t,n,r,e=!0){var s=(t&K)!==0,o=u,a={ctx:i,deps:null,nodes_start:null,nodes_end:null,f:t|A,first:null,fn:n,last:null,next:null,parent:s?null:o,prev:null,teardown:null,transitions:null,version:0};if(r){var f=O;try{at(!0),Z(a),a.f|=Ut}catch(T){throw Y(a),T}finally{at(f)}}else n!==null&&z(a);var c=r&&a.deps===null&&a.first===null&&a.nodes_start===null&&a.teardown===null&&(a.f&_t)===0;if(!c&&!s&&e&&(o!==null&&rn(a,o),l!==null&&l.f&w)){var v=l;(v.children??(v.children=[])).push(a)}return a}function er(t){const n=P(k,null,!1);return y(n,h),n.teardown=t,n}function sr(t){wt();var n=u!==null&&(u.f&k)!==0&&i!==null&&!i.m;if(n){var r=i;(r.e??(r.e=[])).push({fn:t,effect:u,reaction:l})}else{var e=Tt(t);return e}}function or(t){return wt(),mt(t)}function ar(t){const n=P(K,t,!0);return()=>{Y(n)}}function Tt(t){return P(lt,t,!1)}function mt(t){return P(k,t,!0)}function ur(t){return mt(t)}function lr(t,n=0){return P(k|it|n,t,!0)}function ir(t,n=!0){return P(k|g,t,!0,n)}function At(t){var n=t.teardown;if(n!==null){const r=rt,e=l;ut(!0),$(null);try{n.call(null)}finally{ut(r),$(e)}}}function Y(t,n=!0){var r=!1;if((n||t.f&Bt)&&t.nodes_start!==null){for(var e=t.nodes_start,s=t.nodes_end;e!==null;){var o=e===s?null:x(e);e.remove(),e=o}r=!0}Pt(t,n&&!r),M(t,0),y(t,H);var a=t.transitions;if(a!==null)for(const c of a)c.stop();At(t);var f=t.parent;f!==null&&f.first!==null&&gt(t),t.next=t.prev=t.teardown=t.ctx=t.deps=t.parent=t.fn=t.nodes_start=t.nodes_end=null}function gt(t){var n=t.parent,r=t.prev,e=t.next;r!==null&&(r.next=e),e!==null&&(e.prev=r),n!==null&&(n.first===t&&(n.first=e),n.last===t&&(n.last=r))}function fr(t,n){var r=[];It(t,r,!0),en(r,()=>{Y(t),n&&n()})}function en(t,n){var r=t.length;if(r>0){var e=()=>--r||n();for(var s of t)s.out(e)}else n()}function It(t,n,r){if(!(t.f&N)){if(t.f^=N,t.transitions!==null)for(const a of t.transitions)(a.is_global||r)&&n.push(a);for(var e=t.first;e!==null;){var s=e.next,o=(e.f&ft)!==0||(e.f&g)!==0;It(e,n,o?r:!1),e=s}}}function _r(t){Rt(t,!0)}function Rt(t,n){if(t.f&N){t.f^=N,j(t)&&Z(t);for(var r=t.first;r!==null;){var e=r.next,s=(r.f&ft)!==0||(r.f&g)!==0;Rt(r,s?n:!1),r=e}if(t.transitions!==null)for(const o of t.transitions)(o.is_global||n)&&o.in()}}let V=!1,X=[];function St(){V=!1;const t=X.slice();X=[],jt(t)}function cr(t){V||(V=!0,queueMicrotask(St)),X.push(t)}function sn(){V&&St()}function on(t){let n=w|A;u===null?n|=S:u.f|=_t;const r={children:null,deps:null,equals:ct,f:n,fn:t,reactions:null,v:null,version:0,parent:u};if(l!==null&&l.f&w){var e=l;(e.children??(e.children=[])).push(r)}return r}function vr(t){const n=on(t);return n.equals=vt,n}function xt(t){var n=t.children;if(n!==null){t.children=null;for(var r=0;r<n.length;r+=1){var e=n[r];e.f&w?an(e):Y(e)}}}function Dt(t){var n,r=u;G(t.parent);try{xt(t),n=kt(t)}finally{G(r)}var e=(D||t.f&S)&&t.deps!==null?L:h;y(t,e),t.equals(n)||(t.v=n,t.version=Nt())}function an(t){xt(t),M(t,0),y(t,H),t.children=t.deps=t.reactions=t.fn=null}function un(t){throw new Error("lifecycle_outside_component")}const Ot=0,ln=1;let U=Ot,q=!1,O=!1,rt=!1;function at(t){O=t}function ut(t){rt=t}let I=[],C=0;let l=null;function $(t){l=t}let u=null;function G(t){u=t}let d=null;function fn(t){d=t}let p=null,E=0,m=null;function _n(t){m=t}let Ct=0,D=!1,i=null;function Nt(){return++Ct}function J(){return i!==null&&i.l===null}function j(t){var a,f;var n=t.f;if(n&A)return!0;if(n&L){var r=t.deps,e=(n&S)!==0;if(r!==null){var s;if(n&B){for(s=0;s<r.length;s++)((a=r[s]).reactions??(a.reactions=[])).push(t);t.f^=B}for(s=0;s<r.length;s++){var o=r[s];if(j(o)&&Dt(o),e&&u!==null&&!D&&!((f=o==null?void 0:o.reactions)!=null&&f.includes(t))&&(o.reactions??(o.reactions=[])).push(t),o.version>t.version)return!0}}e||y(t,h)}return!1}function cn(t,n,r){throw t}function kt(t){var T;var n=p,r=E,e=m,s=l,o=D,a=d;p=null,E=0,m=null,l=t.f&(g|K)?null:t,D=!O&&(t.f&S)!==0,d=null;try{var f=(0,t.fn)(),c=t.deps;if(p!==null){var v;if(M(t,E),c!==null&&E>0)for(c.length=E+p.length,v=0;v<p.length;v++)c[E+v]=p[v];else t.deps=c=p;if(!D)for(v=E;v<c.length;v++)((T=c[v]).reactions??(T.reactions=[])).push(t)}else c!==null&&E<c.length&&(M(t,E),c.length=E);return f}finally{p=n,E=r,m=e,l=s,D=o,d=a}}function vn(t,n){let r=n.reactions;if(r!==null){var e=r.indexOf(t);if(e!==-1){var s=r.length-1;s===0?r=n.reactions=null:(r[e]=r[s],r.pop())}}r===null&&n.f&w&&(p===null||!p.includes(n))&&(y(n,L),n.f&(S|B)||(n.f^=B),M(n,0))}function M(t,n){var r=t.deps;if(r!==null)for(var e=n;e<r.length;e++)vn(t,r[e])}function Pt(t,n=!1){var r=t.first;for(t.first=t.last=null;r!==null;){var e=r.next;Y(r,n),r=e}}function Z(t){var n=t.f;if(!(n&H)){y(t,h);var r=u,e=i;u=t,i=t.ctx;try{n&it||Pt(t),At(t);var s=kt(t);t.teardown=typeof s=="function"?s:null,t.version=Ct}catch(o){cn(o)}finally{u=r,i=e}}}function bt(){C>1e3&&(C=0,Zt()),C++}function Ft(t){var n=t.length;if(n!==0){bt();var r=O;O=!0;try{for(var e=0;e<n;e++){var s=t[e];s.f&h||(s.f^=h);var o=[];qt(s,o),pn(o)}}finally{O=r}}}function pn(t){var n=t.length;if(n!==0)for(var r=0;r<n;r++){var e=t[r];!(e.f&(H|N))&&j(e)&&(Z(e),e.deps===null&&e.first===null&&e.nodes_start===null&&(e.teardown===null?gt(e):e.fn=null))}}function hn(){if(q=!1,C>1001)return;const t=I;I=[],Ft(t),q||(C=0)}function z(t){U===Ot&&(q||(q=!0,queueMicrotask(hn)));for(var n=t;n.parent!==null;){n=n.parent;var r=n.f;if(r&(K|g)){if(!(r&h))return;n.f^=h}}I.push(n)}function qt(t,n){var r=t.first,e=[];t:for(;r!==null;){var s=r.f,o=(s&g)!==0,a=o&&(s&h)!==0;if(!a&&!(s&N))if(s&k){o?r.f^=h:j(r)&&Z(r);var f=r.first;if(f!==null){r=f;continue}}else s&lt&&e.push(r);var c=r.next;if(c===null){let b=r.parent;for(;b!==null;){if(t===b)break t;var v=b.next;if(v!==null){r=v;continue t}b=b.parent}}r=c}for(var T=0;T<e.length;T++)f=e[T],n.push(f),qt(f,n)}function Mt(t){var n=U,r=I;try{bt();const s=[];U=ln,I=s,q=!1,Ft(r);var e=t==null?void 0:t();return sn(),(I.length>0||s.length>0)&&Mt(),C=0,e}finally{U=n,I=r}}async function pr(){await Promise.resolve(),Mt()}function hr(t){var n=t.f;if(n&H)return t.v;if(l!==null){d!==null&&d.includes(t)&&zt();var r=l.deps;p===null&&r!==null&&r[E]===t?E++:p===null?p=[t]:p.push(t),m!==null&&u!==null&&u.f&h&&!(u.f&g)&&m.includes(t)&&(y(u,A),z(u))}if(n&w){var e=t;j(e)&&Dt(e)}return t.v}function Er(t){const n=l;try{return l=null,t()}finally{l=n}}const En=~(A|L|h);function y(t,n){t.f=t.f&En|n}function dr(t){return Lt().get(t)}function yr(t,n){return Lt().set(t,n),n}function Lt(t){return i===null&&un(),i.c??(i.c=new Map(dn(i)||void 0))}function dn(t){let n=t.p;for(;n!==null;){const r=n.c;if(r!==null)return r;n=n.p}return null}function wr(t,n=!1,r){i={p:i,c:null,e:null,m:!1,s:t,x:null,l:null},n||(i.l={s:null,u:null,r1:[],r2:tt(!1)})}function Tr(t){const n=i;if(n!==null){t!==void 0&&(n.x=t);const a=n.e;if(a!==null){var r=u,e=l;n.e=null;try{for(var s=0;s<a.length;s++){var o=a[s];G(o.effect),$(o.reaction),Tt(o.fn)}}finally{G(r),$(e)}}i=n.p,n.m=!0}return t||{}}function mr(t){if(!(typeof t!="object"||!t||t instanceof EventTarget)){if(st in t)Q(t);else if(!Array.isArray(t))for(let n in t){const r=t[n];typeof r=="object"&&r&&st in r&&Q(r)}}}function Q(t,n=new Set){if(typeof t=="object"&&t!==null&&!(t instanceof EventTarget)&&!n.has(t)){n.add(t),t instanceof Date&&t.getTime();for(let e in t)try{Q(t[e],n)}catch{}const r=Yt(t);if(r!==Object.prototype&&r!==Array.prototype&&r!==Map.prototype&&r!==Set.prototype&&r!==Date.prototype){const e=Ht(r);for(let s in e){const o=e[s].get;if(o)try{o.call(t)}catch{}}}}}export{vr as $,i as A,mn as B,An as C,tt as D,ft as E,On as F,Pn as G,Qt as H,et as I,hr as J,Cn as K,Yt as L,yn as M,Tt as N,mt as O,Er as P,cr as Q,Dn as R,st as S,Rn as T,Gn as U,jn as V,vt as W,Hn as X,Yn as Y,Un as Z,on as _,Zn as a,Bn as a0,kn as a1,gn as a2,un as a3,sr as a4,In as a5,er as a6,tr as a7,ur as a8,Qn as a9,nn as aA,zn as aa,nr as ab,Wn as ac,Tn as ad,Vn as ae,$n as af,Mt as ag,or as ah,pr as ai,Nn as aj,N as ak,bn as al,Fn as am,Ln as an,It as ao,en as ap,Y as aq,qn as ar,Mn as as,Sn as at,Ht as au,mr as av,Vt as aw,yr as ax,dr as ay,ot as az,lr as b,Kn as c,_r as d,ir as e,_ as f,nt as g,R as h,Bt as i,Jt as j,x as k,W as l,Jn as m,ht as n,tn as o,fr as p,Et as q,Xn as r,F as s,xn as t,rr as u,wn as v,ar as w,wr as x,u as y,Tr as z};
