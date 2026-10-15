'use strict';
const D=require('./domain');
// Hàm thuần để kiểm thử. Tiền nguyên VND; số lượng 1/1000 đơn vị chuẩn.
function allocatePayment(outstanding, requested, explicit) {
 D.integer(requested,'Tiền thu');D.assert(Array.isArray(outstanding),'Danh sách công nợ');
 const rows=outstanding.map(x=>({id:x.id,dueVnd:D.integer(x.dueVnd,'Còn nợ')}));
 let remaining=requested;const items=[];
 if(explicit){
  D.assert(Array.isArray(explicit) && explicit.length>0,'Phải có dòng phân bổ');
  const ids=new Set();
  for(const r of explicit){D.assert(!ids.has(r.id),'Trùng phân bổ');ids.add(r.id);const o=rows.find(x=>x.id===r.id);D.assert(o,'Không có phiếu gốc');const n=D.integer(r.amountVnd,'Tiền phân bổ',1);D.assert(n<=o.dueVnd,'Thanh toán vượt nợ phiếu');items.push({id:r.id,amountVnd:n});remaining-=n;}
  D.assert(remaining===0,'Tổng phân bổ phải bằng số tiền thanh toán');
 }else{
  for(const x of rows){const n=Math.min(remaining,x.dueVnd);if(n>0){items.push({id:x.id,amountVnd:n});remaining-=n;}if(remaining===0)break;}
  D.assert(remaining===0,'Thanh toán vượt công nợ');
 }
 return items;
}
function refundDistribution(original,returnedLines,priorReturned,discountVnd){
 // Hoàn theo tỷ lệ giá bán gốc của dòng và chiết khấu đơn, không dùng giá bán hiện tại.
 const gross=original.reduce((s,x)=>s+x.total,0);D.assert(gross>0,'Phiếu gốc không hợp lệ');
 const grossReturned=returnedLines.reduce((s,x)=>s+x.total,0);
 const priorGross=priorReturned.reduce((s,x)=>s+x.total,0);
 const discountFor=(n)=>Math.floor(discountVnd*n/gross);
 const refund=(grossReturned-discountFor(priorGross+grossReturned)+discountFor(priorGross));
 D.assert(refund>=0,'Tiền hoàn âm');return refund;
}
function applySaleReturnStock(stock,returnLines){
 const next=structuredClone(stock);
 for(const row of returnLines){
  if(!row.restock)continue;
  const s=next[row.productId];D.assert(s,'Hàng không tồn tại');
  s.qtyMilli+=row.baseMilli;s.valueVnd+=row.cogsVnd;
  D.integer(s.qtyMilli,'Tồn');D.integer(s.valueVnd,'Giá trị tồn');
 }
 return next;
}
module.exports={allocatePayment,refundDistribution,applySaleReturnStock};
