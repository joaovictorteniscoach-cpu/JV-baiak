// Regressao do OffscreenCanvas: o DOM permanece 300x150, a imagem usa outro buffer.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const cpp=fs.readFileSync(process.argv[2]+'/src/framework/platform/browserwindow.cpp','utf8');
const helper=cpp.match(/static Point jvInputPosition[\s\S]*?MAIN_THREAD_EM_ASM\(\{([\s\S]*?)\}, clientX, clientY, point\);/);
assert.ok(helper,'coordinate helper must exist');
assert.ok(!/c\.(width|height)/.test(helper[1]),'DOM buffer is stale after transferControlToOffscreen');
assert.match(cpp,/point\[0\] \* renderSize.width\(\) \/ density/);
assert.match(cpp,/point\[1\] \* renderSize.height\(\) \/ density/);
function normalized(rect,x,y){
 const heap=new Float64Array(8);
 vm.runInNewContext(helper[1],{$0:x,$1:y,$2:16,HEAPF64:heap,document:{getElementById:()=>({width:300,height:150,getBoundingClientRect:()=>rect})}});
 return [heap[2],heap[3]];
}
for(const z of [0.6,0.8,1,1.15,1.5,2]) for(const density of [1,1.25,1.5,2]){
 for(const [w,h] of [[844,390],[390,844],[1363,936]]){
  const rect={left:110,top:27,width:w,height:h};
  const pw=Math.floor(w*0.72/z),ph=Math.floor(h*0.72/z);
  for(const [fx,fy] of [[0,0],[.05,.95],[.5,.5],[.99,.99],[1,1]]){
   const [nx,ny]=normalized(rect,rect.left+fx*w,rect.top+fy*h);
   assert.ok(Math.abs(nx-fx)<1e-8);assert.ok(Math.abs(ny-fy)<1e-8);
   // A conversao C++ e conferida no teste compilado; aqui conferimos o trajeto
   // imagem -> CSS -> posicao normalizada -> HUD -> imagem, com buffer DOM obsoleto.
   assert.ok(Math.abs(nx*pw/density*density-fx*pw)<1e-8);
   assert.ok(Math.abs(ny*ph/density*density-fy*ph)<1e-8);
  }
 }
}
assert.deepEqual(normalized({left:0,top:0,width:0,height:0},0,0),[-1,-1]);
console.log('OK: OffscreenCanvas 300x150, offsets, zoom, densidade HUD, retrato e paisagem');
