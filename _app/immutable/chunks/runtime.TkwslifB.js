var Et=Array.isArray,yt=Array.from,wt=Object.defineProperty,rn=Object.getOwnPropertyDescriptor,Yn=Object.getOwnPropertyDescriptors,Tt=Object.prototype,mt=Array.prototype,jn=Object.getPrototypeOf;function At(n){return typeof n=="function"}const gt=()=>{};function Un(n){for(var t=0;t<n.length;t++)n[t]()}const w=2,fn=4,k=8,_n=16,T=32,J=64,R=128,B=256,E=512,A=1024,P=2048,C=4096,q=8192,Bn=16384,cn=32768,xt=65536,Vn=1<<18,en=Symbol("$state"),It=Symbol("");function pn(n){return n===this.v}function $n(n,t){return n!=n?t==t:n!==t||n!==null&&typeof n=="object"||typeof n=="function"}function vn(n){return!$n(n,this.v)}function Gn(n){throw new Error("effect_in_teardown")}function Kn(){throw new Error("effect_in_unowned_derived")}function Zn(n){throw new Error("effect_orphan")}function zn(){throw new Error("effect_update_depth_exceeded")}function Rt(){throw new Error("hydration_failed")}function St(n){throw new Error("props_invalid_value")}function Ot(){throw new Error("state_descriptors_fixed")}function Dt(){throw new Error("state_prototype_fixed")}function Wn(){throw new Error("state_unsafe_local_read")}function Xn(){throw new Error("state_unsafe_mutation")}function Q(n){return{f:0,v:n,reactions:null,equals:pn,version:0}}function Nt(n){return Jn(Q(n))}function Ct(n){var r;const t=Q(n);return t.equals=vn,i!==null&&i.l!==null&&((r=i.l).s??(r.s=[])).push(t),t}function Jn(n){return l!==null&&l.f&w&&(y===null?ft([n]):y.push(n)),n}function kt(n,t){return l!==null&&W()&&l.f&w&&(y===null||!y.includes(n))&&Xn(),n.equals(t)||(n.v=t,n.version=kn(),hn(n,A),W()&&f!==null&&f.f&E&&!(f.f&T)&&(v!==null&&v.includes(n)?(d(f,A),G(f)):m===null?_t([n]):m.push(n))),t}function hn(n,t){var r=n.reactions;if(r!==null)for(var e=W(),s=r.length,o=0;o<s;o++){var u=r[o],c=u.f;c&A||!e&&u===f||(d(u,t),c&(E|R)&&(c&w?hn(u,P):G(u)))}}const Pt=1,qt=2,Mt=4,bt=8,Ft=16,Lt=1,Ht=2,Yt=4,jt=8,Ut=16,Bt=1,Vt=2,Qn="[",nt="[!",tt="]",dn={},$t=Symbol();function En(n){console.warn("hydration_mismatch")}let I=!1;function Gt(n){I=n}let _;function F(n){if(n===null)throw En(),dn;return _=n}function Kt(){return F(S(_))}function Zt(n){if(I){if(S(_)!==null)throw En(),dn;_=n}}function zt(n=1){if(I){for(var t=n,r=_;t--;)r=S(r);_=r}}function Wt(){for(var n=0,t=_;;){if(t.nodeType===8){var r=t.data;if(r===tt){if(n===0)return t;n-=1}else(r===Qn||r===nt)&&(n+=1)}var e=S(t);t.remove(),t=e}}var sn,rt,yn,wn;function Xt(){if(sn===void 0){sn=window,rt=document;var n=Element.prototype,t=Node.prototype;yn=rn(t,"firstChild").get,wn=rn(t,"nextSibling").get,n.__click=void 0,n.__className="",n.__attributes=null,n.__e=void 0,Text.prototype.__t=void 0}}function nn(n=""){return document.createTextNode(n)}function Z(n){return yn.call(n)}function S(n){return wn.call(n)}function Jt(n){if(!I)return Z(n);var t=Z(_);return t===null&&(t=_.appendChild(nn())),F(t),t}function Qt(n,t){if(!I){var r=Z(n);return r instanceof Comment&&r.data===""?S(r):r}if(t&&(_==null?void 0:_.nodeType)!==3){var e=nn();return _==null||_.before(e),F(e),e}return _}function nr(n,t=1,r=!1){let e=I?_:n;for(;t--;)e=S(e);if(!I)return e;var s=e.nodeType;if(r&&s!==3){var o=nn();return e==null||e.before(o),F(o),o}return F(e),e}function tr(n){n.textContent=""}function Tn(n){f===null&&l===null&&Zn(),l!==null&&l.f&R&&Kn(),tn&&Gn()}function et(n,t){var r=t.last;r===null?t.last=t.first=n:(r.next=n,n.prev=r,t.last=n)}function M(n,t,r,e=!0){var s=(n&J)!==0,o=f,u={ctx:i,deps:null,nodes_start:null,nodes_end:null,f:n|A,first:null,fn:t,last:null,next:null,parent:s?null:o,prev:null,teardown:null,transitions:null,version:0};if(r){var c=D;try{on(!0),$(u),u.f|=Bn}catch(g){throw Y(u),g}finally{on(c)}}else t!==null&&G(u);var a=r&&u.deps===null&&u.first===null&&u.nodes_start===null&&u.teardown===null;if(!a&&!s&&e&&(o!==null&&et(u,o),l!==null&&l.f&w)){var p=l;(p.children??(p.children=[])).push(u)}return u}function rr(n){const t=M(k,null,!1);return d(t,E),t.teardown=n,t}function er(n){Tn();var t=f!==null&&(f.f&k)!==0&&i!==null&&!i.m;if(t){var r=i;(r.e??(r.e=[])).push(n)}else{var e=mn(n);return e}}function sr(n){return Tn(),An(n)}function or(n){const t=M(J,n,!0);return()=>{Y(t)}}function mn(n){return M(fn,n,!1)}function An(n){return M(k,n,!0)}function ur(n){return An(n)}function lr(n,t=0){return M(k|_n|t,n,!0)}function ar(n,t=!0){return M(k|T,n,!0,t)}function gn(n){var t=n.teardown;if(t!==null){const r=tn,e=l;un(!0),ln(null);try{t.call(null)}finally{un(r),ln(e)}}}function Y(n,t=!0){var r=!1;if((t||n.f&Vn)&&n.nodes_start!==null){for(var e=n.nodes_start,s=n.nodes_end;e!==null;){var o=e===s?null:S(e);e.remove(),e=o}r=!0}qn(n,t&&!r),H(n,0),d(n,q);var u=n.transitions;if(u!==null)for(const a of u)a.stop();gn(n);var c=n.parent;c!==null&&c.first!==null&&xn(n),n.next=n.prev=n.teardown=n.ctx=n.deps=n.parent=n.fn=n.nodes_start=n.nodes_end=null}function xn(n){var t=n.parent,r=n.prev,e=n.next;r!==null&&(r.next=e),e!==null&&(e.prev=r),t!==null&&(t.first===n&&(t.first=e),t.last===n&&(t.last=r))}function ir(n,t){var r=[];In(n,r,!0),st(r,()=>{Y(n),t&&t()})}function st(n,t){var r=n.length;if(r>0){var e=()=>--r||t();for(var s of n)s.out(e)}else t()}function In(n,t,r){if(!(n.f&C)){if(n.f^=C,n.transitions!==null)for(const u of n.transitions)(u.is_global||r)&&t.push(u);for(var e=n.first;e!==null;){var s=e.next,o=(e.f&cn)!==0||(e.f&T)!==0;In(e,t,o?r:!1),e=s}}}function fr(n){Rn(n,!0)}function Rn(n,t){if(n.f&C){n.f^=C,j(n)&&$(n);for(var r=n.first;r!==null;){var e=r.next,s=(r.f&cn)!==0||(r.f&T)!==0;Rn(r,s?t:!1),r=e}if(n.transitions!==null)for(const o of n.transitions)(o.is_global||t)&&o.in()}}let V=!1,z=[];function Sn(){V=!1;const n=z.slice();z=[],Un(n)}function _r(n){V||(V=!0,queueMicrotask(Sn)),z.push(n)}function ot(){V&&Sn()}function ut(n){let t=w|A;f===null&&(t|=R);const r={children:null,deps:null,equals:pn,f:t,fn:n,reactions:null,v:null,version:0};if(l!==null&&l.f&w){var e=l;(e.children??(e.children=[])).push(r)}return r}function cr(n){const t=ut(n);return t.equals=vn,t}function On(n){var t=n.children;if(t!==null){n.children=null;for(var r=0;r<t.length;r+=1){var e=t[r];e.f&w?lt(e):Y(e)}}}function Dn(n){var t;On(n),t=Pn(n);var r=(O||n.f&R)&&n.deps!==null?P:E;d(n,r),n.equals(t)||(n.v=t,n.version=kn())}function lt(n){On(n),H(n,0),d(n,q),n.children=n.deps=n.reactions=n.fn=null}function at(n){throw new Error("lifecycle_outside_component")}const Nn=0,it=1;let U=Nn,L=!1,D=!1,tn=!1;function on(n){D=n}function un(n){tn=n}let x=[],N=0,l=null;function ln(n){l=n}let f=null,y=null;function ft(n){y=n}let v=null,h=0,m=null;function _t(n){m=n}let Cn=0,O=!1,i=null;function kn(){return++Cn}function W(){return i!==null&&i.l===null}function j(n){var u,c;var t=n.f;if(t&A)return!0;if(t&P){var r=n.deps,e=(t&R)!==0;if(r!==null){var s;if(t&B){for(s=0;s<r.length;s++)((u=r[s]).reactions??(u.reactions=[])).push(n);n.f^=B}for(s=0;s<r.length;s++){var o=r[s];if(j(o)&&Dn(o),e&&f!==null&&!O&&!((c=o==null?void 0:o.reactions)!=null&&c.includes(n))&&(o.reactions??(o.reactions=[])).push(n),o.version>n.version)return!0}}e||d(n,E)}return!1}function ct(n,t,r){throw n}function Pn(n){var g;var t=v,r=h,e=m,s=l,o=O,u=y;v=null,h=0,m=null,l=n.f&(T|J)?null:n,O=!D&&(n.f&R)!==0,y=null;try{var c=(0,n.fn)(),a=n.deps;if(v!==null){var p;if(H(n,h),a!==null&&h>0)for(a.length=h+v.length,p=0;p<v.length;p++)a[h+p]=v[p];else n.deps=a=v;if(!O)for(p=h;p<a.length;p++)((g=a[p]).reactions??(g.reactions=[])).push(n)}else a!==null&&h<a.length&&(H(n,h),a.length=h);return c}finally{v=t,h=r,m=e,l=s,O=o,y=u}}function pt(n,t){let r=t.reactions;if(r!==null){var e=r.indexOf(n);if(e!==-1){var s=r.length-1;s===0?r=t.reactions=null:(r[e]=r[s],r.pop())}}r===null&&t.f&w&&(d(t,P),t.f&(R|B)||(t.f^=B),H(t,0))}function H(n,t){var r=n.deps;if(r!==null)for(var e=t;e<r.length;e++)pt(n,r[e])}function qn(n,t=!1){var r=n.first;for(n.first=n.last=null;r!==null;){var e=r.next;Y(r,t),r=e}}function $(n){var t=n.f;if(!(t&q)){d(n,E);var r=n.ctx,e=f,s=i;f=n,i=r;try{t&_n||qn(n),gn(n);var o=Pn(n);n.teardown=typeof o=="function"?o:null,n.version=Cn}catch(u){ct(u)}finally{f=e,i=s}}}function Mn(){N>1e3&&(N=0,zn()),N++}function bn(n){var t=n.length;if(t!==0){Mn();var r=D;D=!0;try{for(var e=0;e<t;e++){var s=n[e];if(s.first===null&&!(s.f&T))an([s]);else{var o=[];Fn(s,o),an(o)}}}finally{D=r}}}function an(n){var t=n.length;if(t!==0)for(var r=0;r<t;r++){var e=n[r];!(e.f&(q|C))&&j(e)&&($(e),e.deps===null&&e.first===null&&e.nodes_start===null&&(e.teardown===null?xn(e):e.fn=null))}}function vt(){if(L=!1,N>1001)return;const n=x;x=[],bn(n),L||(N=0)}function G(n){U===Nn&&(L||(L=!0,queueMicrotask(vt)));for(var t=n;t.parent!==null;){t=t.parent;var r=t.f;if(r&T){if(!(r&E))return;d(t,P)}}x.push(t)}function Fn(n,t){var r=n.first,e=[];n:for(;r!==null;){var s=r.f,o=(s&(q|C))===0,u=(s&T)!==0,c=(s&E)!==0,a=r.first;if(o&&(!u||!c)){if(u&&d(r,E),s&k){if(!u&&j(r)&&$(r),a=r.first,a!==null){r=a;continue}}else if(s&fn)if(u||c){if(a!==null){r=a;continue}}else e.push(r)}var p=r.next;if(p===null){let b=r.parent;for(;b!==null;){if(n===b)break n;var g=b.next;if(g!==null){r=g;continue n}b=b.parent}}r=p}for(var K=0;K<e.length;K++)a=e[K],t.push(a),Fn(a,t)}function Ln(n){var t=U,r=x;try{Mn();const s=[];U=it,x=s,L=!1,bn(r);var e=n==null?void 0:n();return ot(),(x.length>0||s.length>0)&&Ln(),N=0,e}finally{U=t,x=r}}async function pr(){await Promise.resolve(),Ln()}function vr(n){var t=n.f;if(t&q)return n.v;if(l!==null){y!==null&&y.includes(n)&&Wn();var r=l.deps;v===null&&r!==null&&r[h]===n?h++:v===null?v=[n]:v.push(n),m!==null&&f!==null&&f.f&E&&!(f.f&T)&&m.includes(n)&&(d(f,A),G(f))}if(t&w){var e=n;j(e)&&Dn(e)}return n.v}function hr(n){const t=l;try{return l=null,n()}finally{l=t}}const ht=~(A|P|E);function d(n,t){n.f=n.f&ht|t}function dr(n){return Hn().get(n)}function Er(n,t){return Hn().set(n,t),t}function Hn(n){return i===null&&at(),i.c??(i.c=new Map(dt(i)||void 0))}function dt(n){let t=n.p;for(;t!==null;){const r=t.c;if(r!==null)return r;t=t.p}return null}function yr(n,t=!1,r){i={p:i,c:null,e:null,m:!1,s:n,x:null,l:null},t||(i.l={s:null,u:null,r1:[],r2:Q(!1)})}function wr(n){const t=i;if(t!==null){n!==void 0&&(t.x=n);const e=t.e;if(e!==null){t.e=null;for(var r=0;r<e.length;r++)mn(e[r])}i=t.p,t.m=!0}return n||{}}function Tr(n){if(!(typeof n!="object"||!n||n instanceof EventTarget)){if(en in n)X(n);else if(!Array.isArray(n))for(let t in n){const r=n[t];typeof r=="object"&&r&&en in r&&X(r)}}}function X(n,t=new Set){if(typeof n=="object"&&n!==null&&!(n instanceof EventTarget)&&!t.has(n)){t.add(n),n instanceof Date&&n.getTime();for(let e in n)try{X(n[e],t)}catch{}const r=jn(n);if(r!==Object.prototype&&r!==Array.prototype&&r!==Map.prototype&&r!==Set.prototype&&r!==Date.prototype){const e=Yn(r);for(let s in e){const o=e[s].get;if(o)try{o.call(n)}catch{}}}}}export{cn as $,Ot as A,kt as B,rn as C,vr as D,Dt as E,jn as F,Et as G,Vn as H,St as I,vn as J,Lt as K,xt as L,Ht as M,jt as N,hr as O,Yt as P,ut as Q,cr as R,en as S,Ut as T,$t as U,Ct as V,At as W,nt as X,Wt as Y,fr as Z,ir as _,Qn as a,mn as a0,An as a1,_r as a2,at as a3,er as a4,gt as a5,rr as a6,Qt as a7,ur as a8,Jt as a9,rt as aA,Zt as aa,nr as ab,It as ac,Yn as ad,zt as ae,wt as af,Bt as ag,Vt as ah,Ln as ai,sr as aj,pr as ak,Nt as al,C as am,Pt as an,qt as ao,Ft as ap,In as aq,st as ar,Y as as,Mt as at,bt as au,Tr as av,$n as aw,Er as ax,dr as ay,sn as az,lr as b,nn as c,F as d,_ as e,Z as f,S as g,I as h,Xt as i,dn as j,Kt as k,tt as l,En as m,Rt as n,tr as o,yt as p,or as q,ar as r,Gt as s,yr as t,f as u,wr as v,i as w,Tt as x,mt as y,Q as z};
