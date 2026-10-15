'use strict';
const {onCall,HttpsError}=require('firebase-functions/v2/https');
const admin=require('firebase-admin');
const D=require('./domain');
const {createHash}=require('node:crypto');
admin.initializeApp();
const db=admin.firestore();
const invalid=e=>{if(e instanceof HttpsError) return e; return new HttpsError('failed-precondition',e.message||String(e));};
const root=async(uid)=>{
 if(!uid) throw new HttpsError('unauthenticated','Hãy đăng nhập');
 const member=await db.doc(`members/${uid}`).get();
 const hid=member.data()?.householdId;
 if(!hid || !/^[A-Za-z0-9_-]{1,80}$/.test(hid)) throw new HttpsError('permission-denied','Chưa có quyền hộ gia đình');
 return db.collection('households').doc(hid);
};
// Tạo danh mục và khách hàng qua callable. Cấm sửa trực tiếp Firestore từ ứng dụng.
exports.upsertMaster=onCall(async(request)=>{
 try {
 const parent=await root(request.auth?.uid);
 const {kind,id,data}=request.data||{};
 D.assert(['products','customers','suppliers'].includes(kind),'Loại danh mục');
 const key=D.bounded(id,'ID',100); D.assert(/^[\w-]+$/.test(key),'ID phải là chữ, số, gạch nối');
 const name=D.bounded(data?.name,'Tên');
 const body={name,updatedAt:admin.firestore.FieldValue.serverTimestamp()};
 if(kind==='products') {body.baseUnit=D.bounded(data.baseUnit||'kg','Đơn vị chuẩn',30);body.category=D.bounded(data.category||'Khác','Nhóm');if(data.retailVnd!==undefined)body.retailVnd=D.integer(data.retailVnd,'Giá bán lẻ');if(data.wholesaleVnd!==undefined)body.wholesaleVnd=D.integer(data.wholesaleVnd,'Giá bán sỉ');body.units={};if(data.units && typeof data.units==='object'){for(const [unit,fac] of Object.entries(data.units)){D.bounded(unit,'Tên đơn vị',30);body.units[unit]=fac===-1?-1:D.integer(fac,'Hệ số quy đổi',1);}}}
 else {body.phone=typeof data.phone==='string'?data.phone.slice(0,30):'';body.address=typeof data.address==='string'?data.address.slice(0,300):'';body.gender=typeof data.gender==='string'?data.gender.slice(0,20):'';body.work=typeof data.work==='string'?data.work.slice(0,150):'';}
 // Không cập nhật baseUnit khi đã tồn tại chuyển động kho.
 const ref=parent.collection(kind).doc(key);
 await db.runTransaction(async(tx)=>{const old=await tx.get(ref);if(kind==='products' && old.exists && old.data().baseUnit!==body.baseUnit) throw new Error('Không được thay đổi đơn vị chuẩn của sản phẩm đã tạo');tx.set(ref,body,{merge:true});});
 return {ok:true,id:key};
 }catch(e){throw invalid(e);}
});

// Đây là điểm ghi chứng từ DUY NHẤT. Giao dịch online có tính lặp an toàn.
exports.postDocument=onCall({timeoutSeconds:60},async(request)=>{
 try{
 const parent=await root(request.auth?.uid);
 const body=request.data||{};
 const kind=D.bounded(body.kind,'Loại chứng từ',30);
 D.assert(['purchase','sale'].includes(kind),'Dùng settleDocument để thu/trả tiền theo chứng từ');
 const opId=D.bounded(body.idempotencyKey,'Khóa giao dịch',100);
 D.assert(/^[a-zA-Z0-9_-]{8,100}$/.test(opId),'Khóa giao dịch không hợp lệ');
 const counterparty=typeof body.counterpartyId==='string'?body.counterpartyId:'';
 const relatedId=typeof body.relatedId==='string'?body.relatedId:'';
 const paidVnd=D.integer(body.paidVnd??0,'Tiền đã trả');
 const feeVnd=D.integer(body.feeVnd??0,'Chi phí thu mua');
 const discountVnd=D.integer(body.discountVnd??0,'Chiết khấu');
 const reference=parent.collection('documents').doc(opId);
 const rawLines=['sale','purchase'].includes(kind)?D.normalizeLines(body.lines):[];
 const requestHash=createHash('sha256').update(JSON.stringify({kind,counterparty,relatedId,paidVnd,feeVnd,discountVnd,rawLines})).digest('hex');
 D.assert(!(['sale','purchase','collect','paySupplier'].includes(kind))||counterparty,'Phải chọn khách hàng/nhà cung cấp');
 const productIds=[...new Set(rawLines.map(l=>l.productId))].sort();
 const prodRefs=productIds.map(id=>parent.collection('products').doc(id));
 const stockRefs=productIds.map(id=>parent.collection('stock').doc(id));
 const balanceRef=counterparty?parent.collection('balances').doc(`${kind==='purchase'||kind==='paySupplier'?'supplier':'customer'}_${counterparty}`):null;
 const originalRef=relatedId?parent.collection('documents').doc(relatedId):null;
 const result=await db.runTransaction(async(tx)=>{
  const existing=await tx.get(reference);
  if(existing.exists) {D.assert(existing.data().kind===kind,'ID giao dịch đã được dùng cho nghiệp vụ khác');D.assert(!existing.data().requestHash || existing.data().requestHash===requestHash,'Mã phiếu đã xác nhận với nội dung khác');return {id:opId,alreadyPosted:true,...existing.data().summary};}
  // ĐỌC TẤT CẢ TRƯỚC KHI GHI theo yêu cầu Firestore transactions.
  const productDocs=await Promise.all(prodRefs.map(ref=>tx.get(ref)));
  const stockDocs=await Promise.all(stockRefs.map(ref=>tx.get(ref)));
  const balanceDoc=balanceRef?await tx.get(balanceRef):null;
  const original=originalRef?await tx.get(originalRef):null;
  const productMap=Object.fromEntries(productIds.map((id,i)=>[id,productDocs[i].data()]));
  const stock=Object.fromEntries(productIds.map((id,i)=>[id,{qtyMilli:stockDocs[i].data()?.qtyMilli||0,valueVnd:stockDocs[i].data()?.valueVnd||0,version:(stockDocs[i].data()?.version||0)}]));
  for(const l of rawLines){
   const p=productMap[l.productId]; D.assert(p,'Mặt hàng không tồn tại: '+l.productId);
   D.assert(l.unit===p.baseUnit || (p.units && (p.units[l.unit]===l.factorMilli || p.units[l.unit]===-1)),'Đơn vị quy đổi chưa được cấu hình: '+l.unit);
   if(l.unit===p.baseUnit)D.assert(l.factorMilli===1000,'Sai hệ số đơn vị chuẩn');
  }
  let gross=0,cogs=0,receivableDelta=0,payableDelta=0;
  const itemRows=[];
  if(kind==='sale'){
   D.reserveSale(stock,rawLines);
   for(const l of rawLines){const s=stock[l.productId],calc=D.saleCost(s.qtyMilli,s.valueVnd,l.baseMilli);s.qtyMilli=calc.remaining.qtyMilli;s.valueVnd=calc.remaining.valueVnd;gross+=l.total;cogs+=calc.cost;itemRows.push({...l,cogsVnd:calc.cost});}
   D.assert(discountVnd<=gross,'Giảm giá vượt tiền hàng');D.assert(paidVnd<=gross-discountVnd,'Đã thu vượt tiền bán');
   receivableDelta=gross-discountVnd-paidVnd;
  } else if(kind==='purchase'){
   const sum=rawLines.reduce((v,l)=>v+l.total,0);D.assert(sum>0,'Giá trị nhập phải lớn hơn 0');
   for(let i=0;i<rawLines.length;i++){const l=rawLines[i],s=stock[l.productId];const allocated=i===rawLines.length-1?feeVnd-itemRows.reduce((v,x)=>v+x.allocatedFeeVnd,0):Math.floor(feeVnd*l.total/sum);const newState=D.purchaseValue(s.qtyMilli,s.valueVnd,l.baseMilli,l.total+allocated);Object.assign(s,newState);itemRows.push({...l,allocatedFeeVnd:allocated});gross+=l.total;}
   D.assert(paidVnd<=gross+feeVnd,'Đã trả vượt tổng tiền nhập');payableDelta=gross+feeVnd-paidVnd;
  } else if(kind==='collect'||kind==='paySupplier'){
   D.assert(paidVnd>0,'Số tiền thanh toán phải lớn hơn 0');
   const owed=balanceDoc?.data()?.balanceVnd||0;D.assert(owed>=paidVnd,'Thanh toán vượt công nợ');
   if(kind==='collect')receivableDelta=-paidVnd;else payableDelta=-paidVnd;

  }
  for(const id of productIds){stock[id].version++;tx.set(parent.collection('stock').doc(id),stock[id]);}
  const changes=kind==='purchase'||kind==='paySupplier'?payableDelta:receivableDelta;
  if(balanceRef){const next=(balanceDoc?.data()?.balanceVnd||0)+changes;D.assert(next>=0,'Công nợ âm');tx.set(balanceRef,{balanceVnd:next,updatedAt:admin.firestore.FieldValue.serverTimestamp()},{merge:true});}
  const summary={grossVnd:gross,cogsVnd:cogs,paidVnd,receivableDelta,payableDelta};
  tx.create(reference,{kind,requestHash,counterpartyId:counterparty,relatedId,lines:itemRows,feeVnd,discountVnd,paidVnd,dueVnd:kind==='sale'?receivableDelta:payableDelta,returnedMilli:{},status:'posted',stockVersions:Object.fromEntries(productIds.map(id=>[id,stock[id].version])),createdBy:request.auth.uid,createdAt:admin.firestore.FieldValue.serverTimestamp(),summary});
  return {id:opId,alreadyPosted:false,...summary};
 });
 return result;
 }catch(e){throw invalid(e);}
});

Object.assign(exports,require('./ledger_ops').createOperations({db,admin,root,invalid}));
