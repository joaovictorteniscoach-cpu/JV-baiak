// Executes the exact JavaScript embedded in the C++ input-coordinate helper.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const cpp=fs.readFileSync(process.argv[2]+'/src/framework/platform/browserwindow.cpp','utf8');
const helper=cpp.match(/static Point jvInputPosition[\s\S]*?MAIN_THREAD_EM_ASM\(\{([\s\S]*?)\}, clientX, clientY, point\);/);
assert.ok(helper,'coordinate helper must exist');
function point(rect,width,height,x,y){
 const heap=new Float64Array(8);
 vm.runInNewContext(helper[1],{$0:x,$1:y,$2:16,HEAPF64:heap,document:{getElementById:()=>({width,height,getBoundingClientRect:()=>rect})}});
 return [heap[2],heap[3]];
}
for(const z of [0.6,0.8,1,1.15,1.5,2]){
 for(const [w,h] of [[844,390],[390,844]]){
  const rect={left:110,top:27,width:w,height:h};
  const pw=Math.floor(w*2/z),ph=Math.floor(h*2/z);
  for(const [fx,fy] of [[0,0],[.05,.95],[.5,.5],[.99,.99],[1,1]]){
   const [x,y]=point(rect,pw,ph,rect.left+fx*w,rect.top+fy*h);
   assert.ok(Math.abs(x-fx*pw)<1e-8);assert.ok(Math.abs(y-fy*ph)<1e-8);
  }
 }
}
assert.deepEqual(point({left:0,top:0,width:0,height:0},0,0,0,0),[-10000,-10000]);
console.log('OK: coordenadas reais do canvas com offset, zoom, rotação, bordas e buffer arredondado');
