// Unit tests of the shell's control logic, without WASM, network or game accounts.
const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(require('node:path').join(__dirname, '../web/shell.html'), 'utf8');
const script = html.match(/<script type="text\/javascript">([\s\S]*?)<\/script>/)[1];
function fixture(mobile=false) {
  const nodes = new Map();
  const listeners = {};
  class Element {
    constructor() { this.style = {}; this.attributes = {}; this.listeners = {}; this.value = ''; this.textContent = ''; this.classes = new Set(); this.classList = {add:n=>this.classes.add(n),contains:n=>this.classes.has(n)}; }
    addEventListener(n, f) { (this.listeners[n] ||= []).push(f); }
    setAttribute(n,v) { this.attributes[n]=v; }
    focus() { this.focused=true; }
    blur() { for(const f of this.listeners.blur || []) f({}); }
    getBoundingClientRect() { return {left:0,top:0,width:context.innerWidth,height:context.innerHeight}; }
    dispatchEvent(e) { for(const f of this.listeners[e.type] || []) f(e); return true; }
  }
  for(const m of html.matchAll(/id="([^"]+)"/g)) nodes.set(m[1],new Element());
  const storage = new Map();
  let calls=0;
  const dispatched=[];
  const context = {console, navigator:mobile?{userAgent:'iPhone',maxTouchPoints:5}:{}, Number, Math, JSON, FS:{}, IDBFS:{}, setTimeout:()=>1,clearTimeout:()=>{}, callMain:()=>calls++,
    Event:class {constructor(type){this.type=type;}},KeyboardEvent:class{constructor(type,opts){this.type=type;Object.assign(this,opts);}},
    innerWidth:844,innerHeight:390,devicePixelRatio:3,location:{origin:'https://teste.example',pathname:'/jogar/'},
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
for(const dpr of [1,2,3,4]) {
 const f=fixture(true);f.c.devicePixelRatio=dpr;
 assert.equal(f.c.lerZoom(),0.7);
 assert.equal(f.c.jvPixelRatio(),1/0.7);
 f.storage.set('jvZoom-em-pe','0.6');
 f.c.innerWidth=390;f.c.innerHeight=844;
 assert.equal(f.c.lerZoom(),0.8);
 f.click('zoom-menos');assert.equal(f.c.lerZoom(),0.7);
 f.c.aplicarPinca(0.1);assert.equal(f.c.lerZoom(),0.6);
 f.click('zoom-mais');assert.equal(f.c.lerZoom(),0.7);
 f.c.innerWidth=844;f.c.innerHeight=390;
 f.click('zoom-mais');assert.equal(f.c.lerZoom(),0.8);
 f.click('zoom-restaurar');assert.equal(f.c.lerZoom(),0.7);
 assert.ok(f.c.Module.locateFile('otclient.wasm').includes('?v=toque-v6'));
}
console.log('OK: escala mobile independente do DPR, reducao abaixo de 100% e versao de assets');

{
 const f=fixture(true);
 f.click('jv-equipamento');
 assert.deepEqual(f.dispatched.map(e=>[e.type,e.code]),[['keydown','ControlLeft'],['keydown','ShiftLeft'],['keydown','F8'],['keyup','F8'],['keyup','ShiftLeft'],['keyup','ControlLeft']]);
 assert.equal(f.nodes.get('jv-equipamento').hidden,false);
 assert.equal(fixture().nodes.get('jv-equipamento').hidden,true);
}

{
 const f=fixture(true);const canvas=f.nodes.get('canvas');
 canvas.getBoundingClientRect=()=>({left:10,top:20,width:800,height:400});
 f.c.Module.print('JV_TOUCH_TARGET root=400,200 rect=50,40,30,30');
 assert.equal(f.nodes.get('jv-destino').style.display,undefined);
 f.click('jv-ver-toque');assert.equal(f.nodes.get('jv-ver-toque').attributes['aria-pressed'],'true');
 canvas.dispatchEvent({type:'touchstart',touches:[{clientX:120,clientY:110}]});
 f.c.Module.print('JV_TOUCH_TARGET root=400,200 rect=50,40,30,30');
 const box=f.nodes.get('jv-destino').style;
 assert.deepEqual([box.left,box.top,box.width,box.height],['110px','100px','60px','60px']);
 assert.equal(box.display,'block');
 f.click('jv-ver-toque');assert.equal(box.display,'none');
}
console.log('OK: marcadores opcionais, offsets do canvas, escala e ocultacao');

{
 const f=fixture(true);
 assert.equal(f.nodes.get('jv-fechar-painel').hidden,false);
 f.c.innerWidth=390;f.c.innerHeight=844;f.c.atualizarBotaoMapa();
 assert.equal(f.nodes.get('jv-fechar-painel').hidden,false);
 f.click('jv-fechar-painel');assert.ok(f.dispatched.some(e=>e.type==='keydown'&&e.code==='F12'));
}

// Limites reais, inclusive o limite superior entre dois passos do menu.
for(const [width,height] of [[844,390],[390,844],[568,320],[932,430]]) {
 const f=fixture(true);f.c.innerWidth=width;f.c.innerHeight=height;
 for(let i=0;i<30;i++)f.click('zoom-menos');
 assert.equal(f.c.lerZoom(),0.6);assert.equal(f.nodes.get('zoom-menos').disabled,true);
 for(let i=0;i<30;i++)f.click('zoom-mais');
 assert.equal(f.c.lerZoom(),f.c.limiteZoom());assert.equal(f.nodes.get('zoom-mais').disabled,true);
 f.c.aplicarPinca(NaN);assert.ok(Number.isFinite(f.c.lerZoom()));
 // O limite usa a area segura do canvas, nao a tela com recortes.
 f.nodes.get('canvas').getBoundingClientRect=()=>({width:width-40,height:height-30});
 assert.ok(f.c.lerZoom()<=f.c.limiteZoom());
}
{
 const f=fixture(true);
 f.c.localStorage.getItem=()=>{throw Error('bloqueado');};
 f.c.localStorage.setItem=()=>{throw Error('bloqueado');};
 f.click('zoom-menos');assert.equal(f.c.lerZoom(),0.6);
 f.click('zoom-mais');assert.equal(f.c.lerZoom(),0.7);
 f.c.innerWidth=390;f.c.innerHeight=844;assert.equal(f.c.lerZoom(),0.8);
 f.click('zoom-mais');assert.equal(f.c.lerZoom(),0.9);
 f.c.innerWidth=844;f.c.innerHeight=390;assert.equal(f.c.lerZoom(),0.7);
}
console.log('OK: limites alcancaveis, area segura e zoom sem localStorage');
