var m=a=>{throw TypeError(a)};var u=(a,t,s)=>t.has(a)||m("Cannot "+s);var e=(a,t,s)=>(u(a,t,"read from private field"),s?s.call(a):t.get(a)),r=(a,t,s)=>t.has(a)?m("Cannot add the same private member more than once"):t instanceof WeakSet?t.add(a):t.set(a,s);import{p as i}from"./if.BMieiNQQ.js";import{a0 as _,e as h,h as c}from"./runtime.Bcodve5O.js";import{c as z}from"./string.BHamiALR.js";const d=Object.freeze({});var o;class w{constructor(){r(this,o,_(!1))}get show_main_menu(){return h(e(this,o))}set show_main_menu(t){c(e(this,o),i(t))}toJSON(){return{show_main_menu:this.show_main_menu}}}o=new WeakMap;const g=z(()=>new p);var n;class p{constructor(t=d){r(this,n,_());this.data=t.data??new w}get data(){return h(e(this,n))}set data(t){c(e(this,n),i(t))}toJSON(){return{data:this.data.toJSON()}}}n=new WeakMap;export{p as Z,g as z};
