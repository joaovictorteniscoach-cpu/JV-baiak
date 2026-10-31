// Unit tests of the shell's control logic, without WASM, network or game accounts.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(require('node:path').join(__dirname, '../web/shell.html'), 'utf8');
const script = html.match(/<script type="text\/javascript">([\s\S]*?)<\/script>/)[1];
function fixture() {
  const nodes = new Map();
  const listeners = {};
  class Element {
    constructor() { this.style = {}; this.attributes = {}; this.listeners = {}; this.value = ''; this.textContent = ''; this.classes = new Set(); this.classList = {add:n=>this.classes.add(n),contains:n=>this.classes.has(n)}; }
    addEventListener(n, f) { (this.listeners[n] ||= []).push(f); }
    setAttribute(n,v) { this.attributes[n]=v; }
    focus() { this.focused=true; }
    blur() { for(const f of this.listeners.blur || []) f({}); }
    dispatchEvent(e) { for(const f of this.listeners[e.type] || []) f(e); return true; }
  }
  for(const m of html.matchAll(/id="([^"]+)"/g)) nodes.set(m[1],new Element());
  const storage = new Map();
  let calls=0;
  const dispatched=[];
  const context = {console, navigator:{}, Number, Math, JSON, FS:{}, IDBFS:{}, setTimeout:()=>1,clearTimeout:()=>{}, callMain:()=>calls++,
    Event:class {constructor(type){this.type=type;}},KeyboardEvent:class{constructor(type,opts){this.type=type;Object.assign(this,opts);}},
    innerWidth:844,innerHeight:390,devicePixelRatio:3,
    localStorage:{getItem:k=>storage.get(k)??null,setItem:(k,v)=>storage.set(k,v)},
    document:{getElementById:id=>nodes.get(id),querySelector:()=>new Element(),body:new Element(),documentElement:{},visibilityState:'visible',addEventListener:()=>{}},
    addEventListener:(n,f)=>(listeners[n] ||= []).push(f),dispatchEvent:e=>{dispatched.push(e);}};
  context.window=context;
  vm.createContext(context);vm.runInContext(script,context);
  return {c:context,nodes,storage,listeners,dispatched,calls:()=>calls,click:id=>nodes.get(id).dispatchEvent({type:'click',preventDefault(){},stopPropagation(){}})};
}
{
 const {c,storage,click}=fixture();
 for(const [stored,want] of [['Infinity',1],['garbage',1],['-3',1],['200',2],['0.01',0.6]]) {
  storage.set('jvZoom-deitado',stored);assert.equal(c.lerZoom(),want);
 }
 storage.set('jvZoom-deitado','1.05');click('zoom-mais');assert.equal(c.lerZoom(),1.15);
 storage.set('jvZoom-deitado','1.05');click('zoom-menos');assert.equal(c.lerZoom(),1);
 storage.set('jvZoom-deitado','2');click('zoom-mais');assert.equal(c.lerZoom(),2);
 click('zoom-restaurar');assert.equal(c.lerZoom(),1);
 c.innerWidth=390;c.innerHeight=844;click('zoom-restaurar');assert.equal(c.lerZoom(),0.8);
 assert.equal(storage.get('jvZoom-deitado'),'1');
}
{
 const f=fixture();f.c.startGame();f.c.startGame();assert.equal(f.calls(),1);assert.equal(f.nodes.get('start').disabled,true);
 f.click('menu-botao');assert.equal(f.nodes.get('menu-botao').attributes['aria-expanded'],'true');
 f.click('menu-botao');assert.equal(f.nodes.get('menu-botao').attributes['aria-expanded'],'false');
 f.click('menu-botao');f.click('abrir-teclado');assert.equal(f.nodes.get('menu-painel').style.display,'none');
 f.click('fechar-teclado');assert.equal(f.nodes.get('canvas').focused,true);
 assert.equal(f.nodes.get('tela-cheia').hidden,true);
 assert.equal(f.nodes.get('zoom-mais').listeners.touchend,undefined);
}
{
 const f=fixture();const canvas=f.nodes.get('canvas');
 f.listeners.touchstart[0]({target:canvas,touches:[{clientX:0,clientY:0},{clientX:10,clientY:0}]});assert.notEqual(f.c.pinca,null);
 f.listeners.touchcancel[0]();assert.equal(f.c.pinca,null);
 f.listeners.touchstart[0]({target:canvas,touches:[{clientX:0,clientY:0},{clientX:0,clientY:0}]});assert.equal(f.c.pinca,null);
}
{
 const f=fixture();let stopped=false;
 f.listeners.keydown[0]({target:{closest:()=>true},stopImmediatePropagation:()=>{stopped=true;}});
 assert.equal(stopped,true);
}
{
 const f=fixture();
 f.c.localStorage.getItem=()=>{throw Error('bloqueado');};
 f.c.localStorage.setItem=()=>{throw Error('bloqueado');};
 assert.equal(f.c.lerZoom(),1);f.click('zoom-restaurar');
 assert.ok(Number.isFinite(f.c.jvPixelRatio()));
}
{
 const f=fixture();let stopped=0,prevented=0;
 f.listeners.keydown[0]({target:f.nodes.get('teclado'),key:'Backspace',stopImmediatePropagation:()=>stopped++,preventDefault:()=>prevented++});
 assert.equal(stopped,1);assert.equal(prevented,1);
 assert.deepEqual(f.dispatched.map(e=>e.type),['keydown','keyup']);
 assert.ok(f.dispatched.every(e=>e.key==='Backspace'));
 f.c.Module.onAbort('teste');assert.equal(f.nodes.get('start').style.display,'none');
 assert.equal(f.nodes.get('capa').style.display,'flex');
}
console.log('OK: zoom bounds/steps/reset, orientation, single start, menu, keyboard focus, unsupported fullscreen and pinch cancellation');
