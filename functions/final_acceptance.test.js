'use strict';
const test=require('node:test');
const assert=require('node:assert/strict');
const D=require('./domain');
const A=require('./accounting');
function cashLedger() {
 const state={qtyMilli:0,valueVnd:0,receivable:0, revenue:0,cogs:0, cash:0,events:new Map()};
 function post(key, event){
  if(state.events.has(key))return state.events.get(key);
  let result;
  if(event.kind==='purchase'){
   const next=D.purchaseValue(state.qtyMilli,state.valueVnd,event.qty,event.value);
   state.qtyMilli=next.qtyMilli;state.valueVnd=next.valueVnd;result={ok:true};
  } else if(event.kind==='sale') {
   D.assert(state.qtyMilli>=event.qty,'not enough stock');
   const next=D.saleCost(state.qtyMilli,state.valueVnd,event.qty);
   D.assert(event.paid<=event.amount,'overpaid');
   state.qtyMilli=next.remaining.qtyMilli;state.valueVnd=next.remaining.valueVnd;
   state.revenue+=event.amount;state.cogs+=next.cost;
   state.receivable+=event.amount-event.paid;state.cash+=event.paid;
   result={cogs:next.cost};
  }else if(event.kind==='collect'){
   D.assert(event.amount<=state.receivable,'overcollection');
   state.receivable-=event.amount;state.cash+=event.amount;result={ok:true};
  }
  state.events.set(key,result);return result;
 }
 return {state,post};
}
test('nhiều nghiệp vụ tạo giá vốn, tồn kho, tiền mặt và công nợ khớp nhau',()=>{
 const {state,post}=cashLedger();
 post('purchase-1',{kind:'purchase',qty:10000,value:1000000});
 post('purchase-2',{kind:'purchase',qty:10000,value:1500000});
 assert.equal(state.qtyMilli,20000);assert.equal(state.valueVnd,2500000);
 const sale=post('sale-1',{kind:'sale',qty:12000,amount:2400000,paid:500000});
 assert.equal(sale.cogs,1500000);assert.equal(state.qtyMilli,8000);
 assert.equal(state.valueVnd,1000000);assert.equal(state.receivable,1900000);
 assert.equal(post('sale-1',{kind:'sale',qty:12000,amount:2400000,paid:500000}).cogs,1500000);
 assert.equal(state.qtyMilli,8000);
 post('collect-1',{kind:'collect',amount:700000});
 assert.equal(state.receivable,1200000);assert.equal(state.cash,1200000);
 assert.equal(state.revenue-state.cogs,900000);
});
test('1000 hành động giả lập có lặp thao tác không tạo tiền và tồn giả',()=>{
 const {state,post}=cashLedger();
 post('starting-inventory',{kind:'purchase',qty:1000000,value:25000000});
 let expectedQty=1000000,expectedRevenue=0,expectedCash=0;
 for(let i=0;i<1000;i++){
  const e={kind:'sale',qty:1000,amount:35000,paid:i%2===0?35000:10000};
  post(`sale-${i}`,e);post(`sale-${i}`,e);
  expectedQty-=1000;expectedRevenue+=35000;expectedCash+=e.paid;
 }
 assert.equal(state.qtyMilli,expectedQty);assert.equal(state.revenue,expectedRevenue);
 assert.equal(state.cash,expectedCash);assert.equal(state.valueVnd,0);
 assert.equal(state.receivable,expectedRevenue-expectedCash);
 assert.throws(()=>post('invalid-collect',{kind:'collect',amount:state.receivable+1}));
});
test('trả hàng hỏng không cộng tồn, trả hàng bán được giữ giá vốn',()=>{
 const stock={p:{qtyMilli:2000,valueVnd:200000}};
 const next=A.applySaleReturnStock(stock,[{productId:'p',baseMilli:1000,cogsVnd:80000,restock:false},{productId:'p',baseMilli:500,cogsVnd:40000,restock:true}]);
 assert.deepEqual(next,{p:{qtyMilli:2500,valueVnd:240000}});
 assert.equal(stock.p.qtyMilli,2000);
});
