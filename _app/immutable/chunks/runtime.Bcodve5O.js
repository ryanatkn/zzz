var In=Array.isArray,Rn=Array.from,Sn=Object.defineProperty,ot=Object.getOwnPropertyDescriptor,Bt=Object.getOwnPropertyDescriptors,gn=Object.prototype,Dn=Array.prototype,Ut=Object.getPrototypeOf;function On(t){return typeof t=="function"}const Nn=()=>{};function Vt(t){for(var n=0;n<t.length;n++)t[n]()}const m=2,_t=4,M=8,tt=16,y=32,K=64,g=128,U=256,p=512,I=1024,H=2048,k=4096,Y=8192,Gt=16384,ct=32768,Cn=65536,$t=1<<18,vt=1<<19,lt=Symbol("$state"),kn=Symbol("");function pt(t){return t===this.v}function Kt(t,n){return t!=t?n==n:t!==n||t!==null&&typeof t=="object"||typeof t=="function"}function ht(t){return!Kt(t,this.v)}function Zt(t){throw new Error("effect_in_teardown")}function zt(){throw new Error("effect_in_unowned_derived")}function Jt(t){throw new Error("effect_orphan")}function Wt(){throw new Error("effect_update_depth_exceeded")}function bn(){throw new Error("hydration_failed")}function Fn(t){throw new Error("props_invalid_value")}function Pn(){throw new Error("state_descriptors_fixed")}function Ln(){throw new Error("state_prototype_fixed")}function Xt(){throw new Error("state_unsafe_local_read")}function Qt(){throw new Error("state_unsafe_mutation")}function nt(t){return{f:0,v:t,reactions:null,equals:pt,version:0}}function qn(t){return tn(nt(t))}function Mn(t,n=!1){var e;const r=nt(t);return n||(r.equals=ht),i!==null&&i.l!==null&&((e=i.l).s??(e.s=[])).push(r),r}function tn(t){return u!==null&&u.f&m&&(E===null?dn([t]):E.push(t)),t}function Hn(t,n){return u!==null&&st()&&u.f&(m|tt)&&(E===null||!E.includes(t))&&Qt(),nn(t,n)}function nn(t,n){return t.equals(n)||(t.v=n,t.version=Pt(),dt(t,I),st()&&l!==null&&l.f&p&&!(l.f&y)&&(_!==null&&_.includes(t)?(w(l,I),z(l)):x===null?En([t]):x.push(t))),n}function dt(t,n){var r=t.reactions;if(r!==null)for(var e=st(),s=r.length,a=0;a<s;a++){var o=r[a],f=o.f;f&I||!e&&o===l||(w(o,n),f&(p|g)&&(f&m?dt(o,H):z(o)))}}const Yn=1,jn=2,Bn=4,Un=8,Vn=16,Gn=1,$n=2,Kn=4,Zn=8,zn=16,Jn=4,Wn=1,Xn=2,rn="[",en="[!",sn="]",Et={},Qn=Symbol();function yt(t){console.warn("hydration_mismatch")}let S=!1;function tr(t){S=t}let d;function P(t){if(t===null)throw yt(),Et;return d=t}function nr(){return P(D(d))}function rr(t){if(S){if(D(d)!==null)throw yt(),Et;d=t}}function er(t=1){if(S){for(var n=t,r=d;n--;)r=D(r);d=r}}function sr(){for(var t=0,n=d;;){if(n.nodeType===8){var r=n.data;if(r===sn){if(t===0)return n;t-=1}else(r===rn||r===en)&&(t+=1)}var e=D(n);n.remove(),n=e}}var ut,an,wt,Tt;function ar(){if(ut===void 0){ut=window,an=document;var t=Element.prototype,n=Node.prototype;wt=ot(n,"firstChild").get,Tt=ot(n,"nextSibling").get,t.__click=void 0,t.__className="",t.__attributes=null,t.__styles=null,t.__e=void 0,Text.prototype.__t=void 0}}function J(t=""){return document.createTextNode(t)}function W(t){return wt.call(t)}function D(t){return Tt.call(t)}function or(t,n){if(!S)return W(t);var r=W(d);if(r===null)r=d.appendChild(J());else if(n&&r.nodeType!==3){var e=J();return r==null||r.before(e),P(e),e}return P(r),r}function lr(t,n){if(!S){var r=W(t);return r instanceof Comment&&r.data===""?D(r):r}return d}function ur(t,n=1,r=!1){let e=S?d:t;for(;n--;)e=D(e);if(!S)return e;var s=e.nodeType;if(r&&s!==3){var a=J();return e==null||e.before(a),P(a),a}return P(e),e}function ir(t){t.textContent=""}function on(t){var n=m|I;l===null?n|=g:l.f|=vt;const r={children:null,ctx:i,deps:null,equals:pt,f:n,fn:t,reactions:null,v:null,version:0,parent:l};if(u!==null&&u.f&m){var e=u;(e.children??(e.children=[])).push(r)}return r}function fr(t){const n=on(t);return n.equals=ht,n}function mt(t){var n=t.children;if(n!==null){t.children=null;for(var r=0;r<n.length;r+=1){var e=n[r];e.f&m?rt(e):F(e)}}}function At(t){var n,r=l;$(t.parent);try{mt(t),n=Lt(t)}finally{$(r)}return n}function xt(t){var n=At(t),r=(O||t.f&g)&&t.deps!==null?H:p;w(t,r),t.equals(n)||(t.v=n,t.version=Pt())}function rt(t){mt(t),q(t,0),w(t,Y),t.v=t.children=t.deps=t.ctx=t.reactions=null}function It(t){l===null&&u===null&&Jt(),u!==null&&u.f&g&&zt(),et&&Zt()}function ln(t,n){var r=n.last;r===null?n.last=n.first=t:(r.next=t,t.prev=r,n.last=t)}function b(t,n,r,e=!0){var s=(t&K)!==0,a=l,o={ctx:i,deps:null,deriveds:null,nodes_start:null,nodes_end:null,f:t|I,first:null,fn:n,last:null,next:null,parent:s?null:a,prev:null,teardown:null,transitions:null,version:0};if(r){var f=N;try{it(!0),Z(o),o.f|=Gt}catch(c){throw F(o),c}finally{it(f)}}else n!==null&&z(o);var T=r&&o.deps===null&&o.first===null&&o.nodes_start===null&&o.teardown===null&&(o.f&vt)===0;if(!T&&!s&&e&&(a!==null&&ln(o,a),u!==null&&u.f&m)){var A=u;(A.children??(A.children=[])).push(o)}return o}function _r(t){const n=b(M,null,!1);return w(n,p),n.teardown=t,n}function cr(t){It();var n=l!==null&&(l.f&y)!==0&&i!==null&&!i.m;if(n){var r=i;(r.e??(r.e=[])).push({fn:t,effect:l,reaction:u})}else{var e=Rt(t);return e}}function vr(t){return It(),un(t)}function pr(t){const n=b(K,t,!0);return()=>{F(n)}}function Rt(t){return b(_t,t,!1)}function un(t){return b(M,t,!0)}function hr(t){return fn(t)}function fn(t,n=0){return b(M|tt|n,t,!0)}function dr(t,n=!0){return b(M|y,t,!0,n)}function St(t){var n=t.teardown;if(n!==null){const r=et,e=u;ft(!0),G(null);try{n.call(null)}finally{ft(r),G(e)}}}function gt(t){var n=t.deriveds;if(n!==null){t.deriveds=null;for(var r=0;r<n.length;r+=1)rt(n[r])}}function Dt(t,n=!1){var r=t.first;for(t.first=t.last=null;r!==null;){var e=r.next;F(r,n),r=e}}function _n(t){for(var n=t.first;n!==null;){var r=n.next;n.f&y||F(n),n=r}}function F(t,n=!0){var r=!1;if((n||t.f&$t)&&t.nodes_start!==null){for(var e=t.nodes_start,s=t.nodes_end;e!==null;){var a=e===s?null:D(e);e.remove(),e=a}r=!0}Dt(t,n&&!r),gt(t),q(t,0),w(t,Y);var o=t.transitions;if(o!==null)for(const T of o)T.stop();St(t);var f=t.parent;f!==null&&f.first!==null&&Ot(t),t.next=t.prev=t.teardown=t.ctx=t.deps=t.parent=t.fn=t.nodes_start=t.nodes_end=null}function Ot(t){var n=t.parent,r=t.prev,e=t.next;r!==null&&(r.next=e),e!==null&&(e.prev=r),n!==null&&(n.first===t&&(n.first=e),n.last===t&&(n.last=r))}function Er(t,n){var r=[];Nt(t,r,!0),cn(r,()=>{F(t),n&&n()})}function cn(t,n){var r=t.length;if(r>0){var e=()=>--r||n();for(var s of t)s.out(e)}else n()}function Nt(t,n,r){if(!(t.f&k)){if(t.f^=k,t.transitions!==null)for(const o of t.transitions)(o.is_global||r)&&n.push(o);for(var e=t.first;e!==null;){var s=e.next,a=(e.f&ct)!==0||(e.f&y)!==0;Nt(e,n,a?r:!1),e=s}}}function yr(t){Ct(t,!0)}function Ct(t,n){if(t.f&k){t.f^=k,j(t)&&Z(t);for(var r=t.first;r!==null;){var e=r.next,s=(r.f&ct)!==0||(r.f&y)!==0;Ct(r,s?n:!1),r=e}if(t.transitions!==null)for(const a of t.transitions)(a.is_global||n)&&a.in()}}let V=!1,X=[];function kt(){V=!1;const t=X.slice();X=[],Vt(t)}function wr(t){V||(V=!0,queueMicrotask(kt)),X.push(t)}function vn(){V&&kt()}function pn(t){throw new Error("lifecycle_outside_component")}const bt=0,hn=1;let B=bt,L=!1,N=!1,et=!1;function it(t){N=t}function ft(t){et=t}let R=[],C=0;let u=null;function G(t){u=t}let l=null;function $(t){l=t}let E=null;function dn(t){E=t}let _=null,h=0,x=null;function En(t){x=t}let Ft=0,O=!1,i=null;function Pt(){return++Ft}function st(){return i!==null&&i.l===null}function j(t){var o,f;var n=t.f;if(n&I)return!0;if(n&H){var r=t.deps,e=(n&g)!==0;if(r!==null){var s;if(n&U){for(s=0;s<r.length;s++)((o=r[s]).reactions??(o.reactions=[])).push(t);t.f^=U}for(s=0;s<r.length;s++){var a=r[s];if(j(a)&&xt(a),e&&l!==null&&!O&&!((f=a==null?void 0:a.reactions)!=null&&f.includes(t))&&(a.reactions??(a.reactions=[])).push(t),a.version>t.version)return!0}}e||w(t,p)}return!1}function yn(t,n,r){throw t}function Lt(t){var at;var n=_,r=h,e=x,s=u,a=O,o=E,f=i,T=t.f;_=null,h=0,x=null,u=T&(y|K)?null:t,O=!N&&(T&g)!==0,E=null,i=t.ctx;try{var A=(0,t.fn)(),c=t.deps;if(_!==null){var v;if(q(t,h),c!==null&&h>0)for(c.length=h+_.length,v=0;v<_.length;v++)c[h+v]=_[v];else t.deps=c=_;if(!O)for(v=h;v<c.length;v++)((at=c[v]).reactions??(at.reactions=[])).push(t)}else c!==null&&h<c.length&&(q(t,h),c.length=h);return A}finally{_=n,h=r,x=e,u=s,O=a,E=o,i=f}}function wn(t,n){let r=n.reactions;if(r!==null){var e=r.indexOf(t);if(e!==-1){var s=r.length-1;s===0?r=n.reactions=null:(r[e]=r[s],r.pop())}}r===null&&n.f&m&&(_===null||!_.includes(n))&&(w(n,H),n.f&(g|U)||(n.f^=U),q(n,0))}function q(t,n){var r=t.deps;if(r!==null)for(var e=n;e<r.length;e++)wn(t,r[e])}function Z(t){var n=t.f;if(!(n&Y)){w(t,p);var r=l;l=t;try{n&tt?_n(t):Dt(t),gt(t),St(t);var e=Lt(t);t.teardown=typeof e=="function"?e:null,t.version=Ft}catch(s){yn(s)}finally{l=r}}}function qt(){C>1e3&&(C=0,Wt()),C++}function Mt(t){var n=t.length;if(n!==0){qt();var r=N;N=!0;try{for(var e=0;e<n;e++){var s=t[e];s.f&p||(s.f^=p);var a=[];Ht(s,a),Tn(a)}}finally{N=r}}}function Tn(t){var n=t.length;if(n!==0)for(var r=0;r<n;r++){var e=t[r];!(e.f&(Y|k))&&j(e)&&(Z(e),e.deps===null&&e.first===null&&e.nodes_start===null&&(e.teardown===null?Ot(e):e.fn=null))}}function mn(){if(L=!1,C>1001)return;const t=R;R=[],Mt(t),L||(C=0)}function z(t){B===bt&&(L||(L=!0,queueMicrotask(mn)));for(var n=t;n.parent!==null;){n=n.parent;var r=n.f;if(r&(K|y)){if(!(r&p))return;n.f^=p}}R.push(n)}function Ht(t,n){var r=t.first,e=[];t:for(;r!==null;){var s=r.f,a=(s&y)!==0,o=a&&(s&p)!==0;if(!o&&!(s&k))if(s&M){a?r.f^=p:j(r)&&Z(r);var f=r.first;if(f!==null){r=f;continue}}else s&_t&&e.push(r);var T=r.next;if(T===null){let v=r.parent;for(;v!==null;){if(t===v)break t;var A=v.next;if(A!==null){r=A;continue t}v=v.parent}}r=T}for(var c=0;c<e.length;c++)f=e[c],n.push(f),Ht(f,n)}function Yt(t){var n=B,r=R;try{qt();const s=[];B=hn,R=s,L=!1,Mt(r);var e=t==null?void 0:t();return vn(),(R.length>0||s.length>0)&&Yt(),C=0,e}finally{B=n,R=r}}async function Tr(){await Promise.resolve(),Yt()}function mr(t){var f;var n=t.f,r=(n&m)!==0;if(r&&n&Y){var e=At(t);return rt(t),e}if(u!==null){E!==null&&E.includes(t)&&Xt();var s=u.deps;_===null&&s!==null&&s[h]===t?h++:_===null?_=[t]:_.push(t),x!==null&&l!==null&&l.f&p&&!(l.f&y)&&x.includes(t)&&(w(l,I),z(l))}else if(r&&t.deps===null){var a=t,o=a.parent;o!==null&&!((f=o.deriveds)!=null&&f.includes(a))&&(o.deriveds??(o.deriveds=[])).push(a)}return r&&(a=t,j(a)&&xt(a)),t.v}function Ar(t){const n=u;try{return u=null,t()}finally{u=n}}const An=~(I|H|p);function w(t,n){t.f=t.f&An|n}function xr(t){return jt().get(t)}function Ir(t,n){return jt().set(t,n),n}function jt(t){return i===null&&pn(),i.c??(i.c=new Map(xn(i)||void 0))}function xn(t){let n=t.p;for(;n!==null;){const r=n.c;if(r!==null)return r;n=n.p}return null}function Rr(t,n=!1,r){i={p:i,c:null,e:null,m:!1,s:t,x:null,l:null},n||(i.l={s:null,u:null,r1:[],r2:nt(!1)})}function Sr(t){const n=i;if(n!==null){const o=n.e;if(o!==null){var r=l,e=u;n.e=null;try{for(var s=0;s<o.length;s++){var a=o[s];$(a.effect),G(a.reaction),Rt(a.fn)}}finally{$(r),G(e)}}i=n.p,n.m=!0}return{}}function gr(t){if(!(typeof t!="object"||!t||t instanceof EventTarget)){if(lt in t)Q(t);else if(!Array.isArray(t))for(let n in t){const r=t[n];typeof r=="object"&&r&&lt in r&&Q(r)}}}function Q(t,n=new Set){if(typeof t=="object"&&t!==null&&!(t instanceof EventTarget)&&!n.has(t)){n.add(t),t instanceof Date&&t.getTime();for(let e in t)try{Q(t[e],n)}catch{}const r=Ut(t);if(r!==Object.prototype&&r!==Array.prototype&&r!==Map.prototype&&r!==Set.prototype&&r!==Date.prototype){const e=Bt(r);for(let s in e){const a=e[s].get;if(a)try{a.call(t)}catch{}}}}}export{d as $,i as A,y as B,pn as C,cr as D,gn as E,Dn as F,nt as G,Pn as H,Ln as I,Ut as J,In as K,Cn as L,fn as M,yr as N,dr as O,Kn as P,Er as Q,K as R,lt as S,S as T,Qn as U,nr as V,ct as W,en as X,sr as Y,P as Z,tr as _,Sr as a,qn as a0,J as a1,$t as a2,rn as a3,D as a4,W as a5,ar as a6,Et as a7,sn as a8,yt as a9,kn as aA,Ir as aB,xr as aC,tt as aD,Gt as aE,Jn as aF,gr as aG,Kt as aH,ut as aI,an as aJ,bn as aa,ir as ab,Rn as ac,pr as ad,Nn as ae,_r as af,er as ag,Sn as ah,G as ai,u as aj,Wn as ak,Xn as al,Yt as am,vr as an,Tr as ao,k as ap,nn as aq,Yn as ar,Vn as as,jn as at,Nt as au,cn as av,F as aw,Bn as ax,Un as ay,Bt as az,Fn as b,or as c,ht as d,mr as e,lr as f,ot as g,Hn as h,$ as i,Gn as j,$n as k,Zn as l,on as m,fr as n,l as o,Rr as p,zn as q,rr as r,ur as s,hr as t,Ar as u,Mn as v,On as w,Rt as x,un as y,wr as z};
