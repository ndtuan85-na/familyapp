'use strict';
const {onCall} = require('firebase-functions/v2/https');
const {onSchedule: schedule} = require('firebase-functions/v2/scheduler');
const D = require('./domain');

function createOrderOperations({db, admin, root, invalid, postLedgerDocument}) {
  const notice = async (parent, {id, actorUid, title, body, orderId, type}) => {
    const members = await db.collection('members').where('householdId', '==', parent.id).get();
    const unreadFor = members.docs.map(d => d.id).filter(uid => uid !== actorUid);
    if (!unreadFor.length) return;
    const ref = parent.collection('notifications').doc(id);
    await db.runTransaction(async tx => {
      const existing = await tx.get(ref);
      if (existing.exists) return;
      tx.create(ref, {
        type, title, body, orderId, unreadFor,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  };

  const createOrder = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const b = request.data || {};
      const id = D.bounded(b.idempotencyKey, 'Mã phiếu', 100);
      D.assert(/^[a-zA-Z0-9_-]{8,100}$/.test(id), 'Mã phiếu không hợp lệ');
      const kind = D.bounded(b.kind, 'Loại phiếu', 20);
      D.assert(kind === 'purchase' || kind === 'sale', 'Loại phiếu không hợp lệ');
      const partyId = D.bounded(b.counterpartyId, 'Khách hàng/nhà cung cấp', 100);
      const partyKind = kind === 'purchase' ? 'suppliers' : 'customers';
      const party = await parent.collection(partyKind).doc(partyId).get();
      D.assert(party.exists, 'Khách hàng/nhà cung cấp không tồn tại');
      const lines = D.normalizeLines(b.lines);
      const productIds = [...new Set(lines.map(l => l.productId))];
      const products = await Promise.all(productIds.map(pid => parent.collection('products').doc(pid).get()));
      const productMap = Object.fromEntries(productIds.map((pid, i) => [pid, products[i].data()]));
      for (const line of lines) {
        const p = productMap[line.productId];
        D.assert(p, 'Mặt hàng không tồn tại: ' + line.productId);
        D.assert(line.unit === p.baseUnit || (p.units && (p.units[line.unit] === line.factorMilli || p.units[line.unit] === -1)), 'Đơn vị quy đổi chưa được cấu hình: ' + line.unit);
        if (line.unit === p.baseUnit) D.assert(line.factorMilli === 1000, 'Sai hệ số đơn vị chuẩn');
      }
      const scheduledAt = new Date(b.scheduledAt);
      D.assert(Number.isFinite(scheduledAt.getTime()), 'Ngày giờ dự kiến không hợp lệ');
      const paidVnd = D.integer(b.paidVnd ?? 0, 'Tiền đã trả/thu');
      const feeVnd = D.integer(b.feeVnd ?? 0, 'Chi phí thu mua');
      const discountVnd = D.integer(b.discountVnd ?? 0, 'Chiết khấu');
      const gross = lines.reduce((n, l) => n + l.total, 0);
      if (kind === 'purchase') D.assert(paidVnd <= gross + feeVnd, 'Đã trả vượt tổng tiền nhập');
      else D.saleBalance(gross, discountVnd, paidVnd);
      const ref = parent.collection('orders').doc(id);
      const payload = {
        kind, counterpartyId: partyId, counterpartyName: party.data().name,
        lines: lines.map(l => ({productId: l.productId, productName: productMap[l.productId].name, unit: l.unit, quantityMilli: l.quantityMilli, factorMilli: l.factorMilli, unitPrice: l.unitPrice, total: l.total})),
        paidVnd, feeVnd, discountVnd, grossVnd: gross,
        scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
        status: 'pending', reminderSent: false, overdueSent: false, createdBy: request.auth.uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      await db.runTransaction(async tx => {
        const existing = await tx.get(ref);
        if (existing.exists) {
          D.assert(existing.data().createdBy === request.auth.uid, 'Mã phiếu đã được sử dụng');
          return;
        }
        tx.create(ref, payload);
      });
      const total = gross + (kind === 'purchase' ? feeVnd : 0) - (kind === 'sale' ? discountVnd : 0);
      await notice(parent, {
        id: `${id}_created`, actorUid: request.auth.uid,
        type: 'orderCreated', title: kind === 'purchase' ? 'Phiếu chờ nhập mới' : 'Đơn chờ xuất mới',
        body: `${party.data().name}: ${total.toLocaleString('vi-VN')} đ · dự kiến ${scheduledAt.toLocaleString('vi-VN')}`,
        orderId: id,
      });
      return {id, status: 'pending'};
    } catch (e) { throw invalid(e); }
  });

  const confirmOrder = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const id = D.bounded(request.data?.orderId, 'Mã phiếu', 100);
      const ref = parent.collection('orders').doc(id);
      let order;
      const claimed = await db.runTransaction(async tx => {
        const snap = await tx.get(ref);
        D.assert(snap.exists, 'Không tìm thấy phiếu');
        order = snap.data();
        if (order.status === 'confirmed') return false;
        D.assert(order.status === 'pending' || order.status === 'processing', 'Phiếu đã hủy hoặc không thể xác nhận');
        if (order.status === 'pending') tx.update(ref, {status: 'processing'});
        return true;
      });
      if (!claimed) return {id, alreadyConfirmed: true};
      try {
        const posted = await postLedgerDocument(request, parent, {
          idempotencyKey: `${id}_posted`, kind: order.kind,
          counterpartyId: order.counterpartyId, lines: order.lines,
          paidVnd: order.paidVnd, feeVnd: order.feeVnd, discountVnd: order.discountVnd,
          relatedId: id,
        });
        await db.runTransaction(async tx => {
          const latest = await tx.get(ref);
          if (latest.data()?.status !== 'confirmed') tx.update(ref, {
            status: 'confirmed', confirmedBy: request.auth.uid,
            confirmedAt: admin.firestore.FieldValue.serverTimestamp(),
            documentId: posted.id,
          });
        });
        await notice(parent, {
          id: `${id}_confirmed`, actorUid: request.auth.uid,
          type: 'orderConfirmed',
          title: order.kind === 'purchase' ? 'Đã xác nhận nhập hàng' : 'Đã xác nhận xuất hàng',
          body: `${order.counterpartyName}: ${order.grossVnd.toLocaleString('vi-VN')} đ`, orderId: id,
        });
        return {id, status: 'confirmed', documentId: posted.id};
      } catch (e) {
        await ref.update({status: 'pending'}).catch(() => {});
        throw e;
      }
    } catch (e) { throw invalid(e); }
  });

  const cancelOrder = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const id = D.bounded(request.data?.orderId, 'Mã phiếu', 100);
      const ref = parent.collection('orders').doc(id);
      await db.runTransaction(async tx => {
        const snap = await tx.get(ref);
        D.assert(snap.exists && snap.data().status === 'pending', 'Chỉ hủy được phiếu đang chờ xác nhận');
        tx.update(ref, {status: 'cancelled', cancelledBy: request.auth.uid, cancelledAt: admin.firestore.FieldValue.serverTimestamp()});
      });
      await notice(parent, {id: `${id}_cancelled`, actorUid: request.auth.uid, type: 'orderCancelled', title: 'Phiếu đã hủy', body: `Mã phiếu ${id}`, orderId: id});
      return {id, status: 'cancelled'};
    } catch (e) { throw invalid(e); }
  });

  const markNotificationRead = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const id = D.bounded(request.data?.notificationId, 'Thông báo', 150);
      await parent.collection('notifications').doc(id).update({unreadFor: admin.firestore.FieldValue.arrayRemove(request.auth.uid)});
      return {ok: true};
    } catch (e) { throw invalid(e); }
  });

  const createDeliverySchedule = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const b = request.data || {};
      const id = D.bounded(b.idempotencyKey, 'Mã lịch giao', 100);
      D.assert(/^[a-zA-Z0-9_-]{8,100}$/.test(id), 'Mã lịch giao không hợp lệ');
      const customerIds = [...new Set((Array.isArray(b.customerIds) ? b.customerIds : []).map(x => D.bounded(x, 'Khách hàng', 100)))];
      D.assert(customerIds.length > 0 && customerIds.length <= 100, 'Chọn từ 1 đến 100 khách hàng');
      const customers = await Promise.all(customerIds.map(cid => parent.collection('customers').doc(cid).get()));
      D.assert(customers.every(s => s.exists), 'Có khách hàng không tồn tại');
      const scheduledAt = new Date(b.scheduledAt);
      D.assert(Number.isFinite(scheduledAt.getTime()), 'Ngày giờ giao không hợp lệ');
      const remindHours = D.integer(b.remindHours ?? 1, 'Giờ nhắc trước');
      D.assert([0, 1, 2, 4, 12, 24].includes(remindHours), 'Khoảng nhắc không hợp lệ');
      const note = typeof b.note === 'string' ? b.note.trim().slice(0, 500) : '';
      const names = customers.map(s => s.data().name);
      const ref = parent.collection('deliverySchedules').doc(id);
      await db.runTransaction(async tx => {
        const old = await tx.get(ref);
        if (!old.exists) tx.create(ref, {
          customerIds, customerNames: names, scheduledAt: admin.firestore.Timestamp.fromDate(scheduledAt),
          remindHours, note, status: 'pending', reminderSent: false, overdueSent: false,
          createdBy: request.auth.uid, createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
      await notice(parent, {id: `${id}_created`, actorUid: request.auth.uid, type: 'deliveryCreated', title: 'Đã lập lịch giao hàng', body: `${names.join(', ')} · ${scheduledAt.toLocaleString('vi-VN')}${note ? ` · ${note}` : ''}`, orderId: id});
      return {id, status: 'pending'};
    } catch (e) { throw invalid(e); }
  });

  const updateDeliverySchedule = onCall(async request => {
    try {
      const parent = await root(request.auth?.uid);
      const id = D.bounded(request.data?.scheduleId, 'Mã lịch giao', 100);
      const action = request.data?.action;
      D.assert(['complete', 'cancel'].includes(action), 'Thao tác không hợp lệ');
      const ref = parent.collection('deliverySchedules').doc(id);
      const snap = await ref.get();
      D.assert(snap.exists && snap.data().status === 'pending', 'Lịch này không còn chờ giao');
      await ref.update({status: action === 'complete' ? 'completed' : 'cancelled', updatedBy: request.auth.uid, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      await notice(parent, {id: `${id}_${action}`, actorUid: request.auth.uid, type: action === 'complete' ? 'deliveryCompleted' : 'deliveryCancelled', title: action === 'complete' ? 'Đã hoàn thành lịch giao' : 'Đã hủy lịch giao', body: (snap.data().customerNames || []).join(', '), orderId: id});
      return {id, status: action === 'complete' ? 'completed' : 'cancelled'};
    } catch (e) { throw invalid(e); }
  });

  const alertDueOrders = schedule('every 15 minutes', async () => {
    const now = Date.now();
    const threshold = now + 30 * 60 * 1000;
    const [orders, deliveries] = await Promise.all([
      db.collectionGroup('orders').where('status', '==', 'pending').get(),
      db.collectionGroup('deliverySchedules').where('status', '==', 'pending').get(),
    ]);
    for (const doc of [...orders.docs, ...deliveries.docs]) {
      const order = doc.data();
      const at = order.scheduledAt?.toMillis?.() ?? 0;
      const isDelivery = doc.ref.parent.id === 'deliverySchedules';
      const late = at > 0 && at <= now;
      const shouldAlert = isDelivery
        ? (late ? !order.overdueSent : at > now && at <= threshold && !order.reminderSent)
        : (late ? !order.overdueSent : at > now && at <= threshold && !order.reminderSent);
      if (!shouldAlert) continue;
      const householdId = doc.ref.parent.parent?.id;
      if (!householdId) continue;
      const parent = db.collection('households').doc(householdId);
      const members = await db.collection('members').where('householdId', '==', householdId).get();
      const unreadFor = members.docs.map(d => d.id);
      if (!unreadFor.length) continue;
      const noticeRef = parent.collection('notifications').doc(`${doc.id}_${isDelivery ? 'delivery_' : 'order_'}${late ? 'overdue' : 'soon'}`);
      await db.runTransaction(async tx => {
        const [latest, existing] = await Promise.all([tx.get(doc.ref), tx.get(noticeRef)]);
        const current = latest.data() || {};
        if (current.status !== 'pending' || existing.exists || (late ? current.overdueSent : current.reminderSent)) return;
        tx.create(noticeRef, {
          type: isDelivery ? (late ? 'deliveryOverdue' : 'deliveryDueSoon') : (late ? 'orderOverdue' : 'orderDueSoon'),
          title: isDelivery ? (late ? 'Lịch giao đã quá giờ' : 'Sắp đến giờ giao hàng') : (late ? 'Phiếu quá giờ, chưa xác nhận' : 'Sắp đến giờ nhập/xuất hàng'),
          body: isDelivery ? `${(order.customerNames || []).join(', ')}: ${new Date(at).toLocaleString('vi-VN')}` : `${order.counterpartyName}: ${new Date(at).toLocaleString('vi-VN')}`,
          orderId: doc.id, unreadFor,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(doc.ref, late ? {overdueSent: true} : {reminderSent: true});
      });
    }
  });

  return {createOrder, confirmOrder, cancelOrder, markNotificationRead, createDeliverySchedule, updateDeliverySchedule, alertDueOrders};
}

module.exports = {createOrderOperations};

