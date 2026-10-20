'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const D=require('./domain');const A=require('./accounting');
const docId=(id)=>{D.bounded(id,'Mã chứng từ',100);D.assert(/^[\w-]+$/.test(id),'Mã không hợp lệ');return id;};
const payer=(kind)=>kind==='sale'?'customer':'supplier';
function createOperations({db,admin,root,invalid}){
 const stamp=()=>admin.firestore.FieldValue.serverTimestamp();
 // Thu/chi theo phiếu gốc. Phân bổ do người dùng chọn, không cho vượt dư từng phiếu.
 const settleDocument=onCall({timeoutSeconds:60},async(req)=>{try{
  const h=await root(req.auth?.uid),b=req.data||{};const key=docId(b.idempotencyKey),kind=b.kind;
  D.assert(['collect','paySupplier'].includes(kind),'Loại thu/chi không hợp lệ');
  const partyId=docId(b.counterpartyId),amount=D.integer(b.amountVnd,'Số tiền',1);
  D.assert(Array.isArray(b.allocations)&&b.allocations.length>0&&b.allocations.length<=100,'Cần chọn chứng từ công nợ (tối đa 100 phiếu mỗi lần)');
  const al=b.allocations.map(x=>({id:docId(x.id),amountVnd:D.integer(x.amountVnd,'Số tiền phân bổ',1)}));
  D.assert(new Set(al.map(x=>x.id)).size===al.length,'Trùng chứng từ');
  const refs=al.map(x=>h.collection('documents').doc(x.id));const newRef=h.collection('documents').doc(key);
  const balRef=h.collection('balances').doc(`${kind==='collect'?'customer':'supplier'}_${partyId}`);
  return await db.runTransaction(async(tx)=>{
   const existing=await tx.get(newRef);if(existing.exists){D.assert(existing.data().kind===kind,'Khóa đã được dùng');return {id:key,alreadyPosted:true};}
   const originals=await Promise.all(refs.map(r=>tx.get(r)));const bal=await tx.get(balRef);
   const expected=kind==='collect'?'sale':'purchase';
   const rows=originals.map((s,i)=>{D.assert(s.exists,'Phiếu không tồn tại');const x=s.data();D.assert(x.kind===expected&&x.counterpartyId===partyId&&x.status==='posted','Sai khách/NCC hoặc phiếu không hợp lệ');return {id:al[i].id,dueVnd:D.integer(x.dueVnd,'Số dư phiếu')};});
   A.allocatePayment(rows,amount,al);
   const current=D.integer(bal.data()?.balanceVnd??0,'Số dư công nợ');D.assert(current>=amount,'Số tiền lớn hơn công nợ');
   for(let i=0;i<refs.length;i++){const old=originals[i].data();tx.update(refs[i],{dueVnd:old.dueVnd-al[i].amountVnd,updatedAt:stamp()});}
   tx.set(balRef,{balanceVnd:current-amount,updatedAt:stamp()},{merge:true});
   tx.create(newRef,{kind,counterpartyId:partyId,allocations:al,paidVnd:amount,status:'posted',createdAt:stamp(),createdBy:req.auth.uid});
   return {id:key,paidVnd:amount,remainingBalanceVnd:current-amount,alreadyPosted:false};
  });
 }catch(e){throw invalid(e);}});
 // Hoàn đơn bán: ghi âm doanh thu, khôi phục kho nếu còn bán được, giải phóng nợ phiếu,
 // hoàn phần đã thu bằng tiền; không cho hoàn tiền quá tổng thanh toán của chính phiếu.
 const returnSale=onCall({timeoutSeconds:60},async(req)=>{try{
  const h=await root(req.auth?.uid),b=req.data||{};const key=docId(b.idempotencyKey),originalId=docId(b.originalId);
  D.assert(key!==originalId,'Trùng ID');
  const rows=b.lines;D.assert(Array.isArray(rows)&&rows.length>0&&rows.length<=100,'Cần mặt hàng trả');
  const selected=rows.map(x=>({index:D.integer(x.index,'Dòng'),quantityMilli:D.integer(x.quantityMilli,'Số lượng',1),restock:x.restock===true}));
  D.assert(new Set(selected.map(x=>x.index)).size===selected.length,'Dòng trả trùng');
  const originRef=h.collection('documents').doc(originalId),newRef=h.collection('documents').doc(key);
  const result=await db.runTransaction(async(tx)=>{
   const existing=await tx.get(newRef);if(existing.exists){D.assert(existing.data().kind==='saleReturn'&&existing.data().originalId===originalId,'Khóa đã dùng');return {id:key,alreadyPosted:true};}
   const origin=await tx.get(originRef);D.assert(origin.exists,'Không tìm thấy phiếu bán');const o=origin.data();D.assert(o.kind==='sale'&&o.status==='posted','Chỉ hoàn đơn bán đã xác nhận');
   const balanceRef=h.collection('balances').doc(`customer_${o.counterpartyId}`);
   const productIds=[...new Set(selected.map(x=>{D.assert(x.index<o.lines.length,'Dòng hàng không tồn tại');return o.lines[x.index].productId;}))].sort();
   const stockRefs=productIds.map(id=>h.collection('stock').doc(id));
   const stockDocs=await Promise.all(stockRefs.map(r=>tx.get(r)));const balanceDoc=await tx.get(balanceRef);
   const stock=Object.fromEntries(productIds.map((id,i)=>[id,{qtyMilli:stockDocs[i].data()?.qtyMilli||0,valueVnd:stockDocs[i].data()?.valueVnd||0,version:stockDocs[i].data()?.version||0}]));
   const previously=o.returnedMilli||{},now={...previously};const returns=[];let cost=0;
   for(const line of selected){const source=o.lines[line.index];const previous=D.integer(previously[String(line.index)]||0,'Đã trả');
    D.assert(previous+line.quantityMilli<=source.quantityMilli,'Số lượng trả vượt số lượng đã bán');
    const next=previous+line.quantityMilli;
    const prevBase=Math.floor(source.baseMilli*previous/source.quantityMilli),newBase=Math.floor(source.baseMilli*next/source.quantityMilli);
    const prevTotal=Math.floor(source.total*previous/source.quantityMilli),newTotal=Math.floor(source.total*next/source.quantityMilli);
    const prevCost=Math.floor(source.cogsVnd*previous/source.quantityMilli),newCost=Math.floor(source.cogsVnd*next/source.quantityMilli);
    const row={productId:source.productId,index:line.index,quantityMilli:line.quantityMilli,baseMilli:newBase-prevBase,total:newTotal-prevTotal,cogsVnd:newCost-prevCost,restock:line.restock};
    if(row.restock){const s=stock[row.productId];s.qtyMilli+=row.baseMilli;s.valueVnd+=row.cogsVnd;s.version++;}
    cost+=row.cogsVnd;returns.push(row);now[String(line.index)]=next;
   }
   const originalGross=o.lines.reduce((a,l)=>a+l.total,0);
   const sumReturnedGross=(rr)=>rr.reduce((a,l)=>a+l.total,0);
   const previouslyTotalGross=o.lines.reduce((a,l,i)=>a+Math.floor(l.total*(previously[String(i)]||0)/l.quantityMilli),0);
   const thisGross=sumReturnedGross(returns);
   const discounted=(gross)=>gross-Math.floor((o.discountVnd||0)*gross/originalGross);
   const refund=discounted(previouslyTotalGross+thisGross)-discounted(previouslyTotalGross);
   D.assert(refund>=0,'Giá trị trả không hợp lệ');
   const owed=D.integer(o.dueVnd,'Nợ phiếu');const reduceDebt=Math.min(owed,refund);
   const cashRefund=refund-reduceDebt;
   D.assert(D.integer(b.cashRefundVnd??0,'Tiền hoàn')===cashRefund,'Tiền hoàn phải bằng '+cashRefund+' VND');
   // Nếu các khoản khách đã trả nằm ở nhiều phiếu, hạn chế hoàn tiền để không hoàn quá số đã thu phiếu này.
   const paidToDate=(o.lines.reduce((s,l)=>s+l.total,0)-(o.discountVnd||0))-owed-(o.totalReturnedVnd||0);
   D.assert(cashRefund<=paidToDate,'Tiền hoàn lớn hơn đã thu cho phiếu');
   const balance=D.integer(balanceDoc.data()?.balanceVnd??0,'Công nợ');D.assert(balance>=reduceDebt,'Số dư tổng không khớp');
   for(const id of productIds)if(stock[id].version!==(stockDocs[productIds.indexOf(id)].data()?.version||0))tx.set(h.collection('stock').doc(id),stock[id]);
   tx.update(originRef,{returnedMilli:now,dueVnd:owed-reduceDebt,totalReturnedVnd:(o.totalReturnedVnd||0)+refund,updatedAt:stamp()});
   tx.set(balanceRef,{balanceVnd:balance-reduceDebt,updatedAt:stamp()},{merge:true});
   tx.create(newRef,{kind:'saleReturn',originalId,counterpartyId:o.counterpartyId,lines:returns,refundVnd:refund,cashRefundVnd:cashRefund,debtReductionVnd:reduceDebt,cogsReversedVnd:cost,status:'posted',createdBy:req.auth.uid,createdAt:stamp()});
   return {id:key,refundVnd:refund,cashRefundVnd:cashRefund,debtReductionVnd:reduceDebt,alreadyPosted:false};
  });return result;
 }catch(e){throw invalid(e);}});
 // Hủy phiếu nhập chỉ khi KHÔNG có bất kỳ vận động kho hoặc trả tiền sau khi nhập.
 // Các trường hợp phức tạp hơn cần phiếu trả nhà cung cấp riêng; từ chối an toàn.
 const cancelPurchase=onCall({timeoutSeconds:60},async(req)=>{try{
  const h=await root(req.auth?.uid),b=req.data||{},originalId=docId(b.originalId),key=docId(b.idempotencyKey);
  const originRef=h.collection('documents').doc(originalId),newRef=h.collection('documents').doc(key);
  return await db.runTransaction(async(tx)=>{
   const existing=await tx.get(newRef);if(existing.exists){D.assert(existing.data().kind==='purchaseCancel'&&existing.data().originalId===originalId,'Trùng mã thao tác');return {id:key,alreadyPosted:true};}
   const snap=await tx.get(originRef);D.assert(snap.exists,'Phiếu nhập không tồn tại');const o=snap.data();
   D.assert(o.kind==='purchase'&&o.status==='posted','Không thể hủy phiếu này');
   const total=o.lines.reduce((v,l)=>v+l.total,0)+(o.feeVnd||0);
   D.assert(o.paidVnd===0&&o.dueVnd===total,'Phiếu đã có thanh toán; phải hoàn tiền và đối soát trước');
   const ids=[...new Set(o.lines.map(l=>l.productId))].sort(),refs=ids.map(id=>h.collection('stock').doc(id));
   const docs=await Promise.all(refs.map(r=>tx.get(r)));
   const balRef=h.collection('balances').doc(`supplier_${o.counterpartyId}`),bal=await tx.get(balRef);
   const balances=D.integer(bal.data()?.balanceVnd||0,'Dư nợ');D.assert(balances>=total,'Số dư nợ nhà cung cấp không khớp');
   const stock=Object.fromEntries(ids.map((id,i)=>[id,{...docs[i].data()}]));
   for(const id of ids)D.assert(stock[id].version===o.stockVersions?.[id],'Kho đã phát sinh giao dịch sau phiếu nhập; không thể hủy trực tiếp');
   for(const l of o.lines){const st=stock[l.productId];st.qtyMilli-=l.baseMilli;st.valueVnd-=l.total+l.allocatedFeeVnd;D.integer(st.qtyMilli,'Tồn sau hủy');D.integer(st.valueVnd,'Giá trị tồn sau hủy');}
   for(const id of ids){stock[id].version++;tx.set(h.collection('stock').doc(id),stock[id]);}
   tx.set(balRef,{balanceVnd:balances-total,updatedAt:stamp()},{merge:true});
   tx.update(originRef,{status:'cancelled',dueVnd:0,cancelId:key,cancelledAt:stamp()});
   tx.create(newRef,{kind:'purchaseCancel',originalId,amountVnd:total,status:'posted',reason:typeof b.reason==='string'?b.reason.slice(0,300):'',createdBy:req.auth.uid,createdAt:stamp()});
   return {id:key,amountVnd:total,alreadyPosted:false};
  });
 }catch(e){throw invalid(e);}});
 return {settleDocument,returnSale,cancelPurchase};
}
module.exports={createOperations};

