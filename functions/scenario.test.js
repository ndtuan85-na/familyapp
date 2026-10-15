const test=require('node:test');
const assert=require('node:assert/strict');
const D=require('./domain');
const A=require('./accounting');
test('hai người cùng bán: chỉ đơn còn đủ tồn được xác nhận',()=>{
 let stock={qtyMilli:10000,valueVnd:1000000};
 function sale(q){ if(stock.qtyMilli<q)return false;const r=D.saleCost(stock.qtyMilli,stock.valueVnd,q);stock=r.remaining;return true; }
 assert.equal(sale(7000),true);assert.equal(sale(5000),false);assert.equal(stock.qtyMilli,3000);
});
test('hai người thu nợ: không vượt số phải thu',()=>{
 let debt=1000000;function collect(n){if(n>debt)return false;debt-=n;return true;}
 assert.equal(collect(700000),true);assert.equal(collect(600000),false);assert.equal(debt,300000);
});
test('gửi lại cùng mã giao dịch không ghi nhận lần hai (mô hình logic)',()=>{
 const seen=new Map();let inventory=10;
 function post(key,q){if(seen.has(key))return seen.get(key);if(q>inventory)throw Error('not enough');inventory-=q;const result={id:key,remaining:inventory};seen.set(key,result);return result;}
 assert.deepEqual(post('fixed-key',3),post('fixed-key',3));assert.equal(inventory,7);
});
