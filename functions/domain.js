'use strict';
// Số lượng lưu theo 1/1000 đơn vị chuẩn; tiền = nguyên VND.
const assert = (ok, message) => {if (!ok) throw new Error(message);};
const integer = (value, name, min = 0) => {assert(Number.isSafeInteger(value) && value >= min, `${name} không hợp lệ`); return value;};
const bounded = (s, name, max=150) => {assert(typeof s === 'string' && s.trim().length > 0 && s.length <= max, `${name} không hợp lệ`); return s.trim();};
const amount = (price, milli) => {integer(price,'Đơn giá'); integer(milli,'Số lượng',1); const n = Math.round(price*milli/1000); integer(n,'Thành tiền'); return n;};
function normalizeLines(lines) {
 assert(Array.isArray(lines) && lines.length > 0 && lines.length <= 100,'Phiếu cần từ 1–100 dòng');
 return lines.map(l => {
  const productId=bounded(l.productId,'Mã hàng',100);
  const quantityMilli=integer(l.quantityMilli,'Số lượng',1);
  const unit=bounded(l.unit,'Đơn vị',30);
  const factorMilli=integer(l.factorMilli,'Hệ số quy đổi',1);
  // quantityMilli * factorMilli / 1000 PHẢI chia hết, tránh mất đơn vị nhỏ nhất.
  const numerator=quantityMilli*factorMilli;
  assert(Number.isSafeInteger(numerator) && numerator % 1000 === 0,'Số lượng quy đổi không chính xác');
  const baseMilli=numerator/1000;
  integer(baseMilli,'Số lượng chuẩn',1);
  const unitPrice=integer(l.unitPrice,'Đơn giá');
  return {productId,quantityMilli,unit,factorMilli,baseMilli,unitPrice,total:amount(unitPrice,quantityMilli)};
 });
}
function reserveSale(stock, lines) {
 const result=new Map();
 for(const l of lines) result.set(l.productId,(result.get(l.productId)||0)+l.baseMilli);
 for(const [id,q] of result) assert((stock[id]?.qtyMilli||0)>=q,`Hết hàng hoặc không đủ tồn: ${id}`);
 return result;
}
function purchaseValue(qty,value,inQty,inValue) {
 integer(qty,'Tồn');integer(value,'Giá trị tồn');integer(inQty,'Nhập',1);integer(inValue,'Giá trị nhập');
 return {qtyMilli:qty+inQty,valueVnd:value+inValue};
}
function saleCost(qty,value,soldQty) {
 integer(qty,'Tồn',1);integer(value,'Giá trị tồn');integer(soldQty,'Lượng bán',1);
 assert(qty>=soldQty,'Không đủ tồn');
 const cost=soldQty===qty?value:Math.round(value*soldQty/qty);
 return {cost,remaining:{qtyMilli:qty-soldQty,valueVnd:value-cost}};
}
module.exports={assert,integer,bounded,amount,normalizeLines,reserveSale,purchaseValue,saleCost};
