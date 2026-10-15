'use strict';
// node seed_catalog.js --household=... --commit (đã cấu hình ADC). Mặc định DRY RUN.
const fs=require('node:fs'),path=require('node:path');
const normal=s=>s.normalize('NFC').toLocaleLowerCase('vi').replace(/[\s\/]+/g,' ').trim();
const rows=fs.readFileSync(path.join(__dirname,'../assets/quynh_luu_seafood.csv'),'utf8').trim().split(/\r?\n/).slice(1).map(line=>{const [code,category,name,baseUnit,sourceType]=line.split(',');return {code,category,name,baseUnit,sourceType};});
const dup=[...new Set(rows.map(x=>normal(x.name)).filter((x,i,a)=>a.indexOf(x)!==i))];if(dup.length)throw Error('Trùng tên danh mục CSV: '+dup.join(','));
const hid=(process.argv.find(x=>x.startsWith('--household='))||'').split('=')[1];
if(!process.argv.includes('--commit')){console.log(JSON.stringify({count:rows.length,groups:rows.reduce((x,r)=>(x[r.category]=(x[r.category]||0)+1,x),{}),preview:rows.slice(-12)},null,2));process.exit(0);}
if(!hid|| !/^[\w-]{1,80}$/.test(hid))throw Error('Cần --household=ID hợp lệ');
const admin=require('firebase-admin');admin.initializeApp();
(async()=>{const db=admin.firestore(),ref=db.collection('households').doc(hid).collection('products');const existing=await ref.get();const ids=new Set(existing.docs.map(d=>d.id));const names=new Set(existing.docs.map(d=>normal(d.data().name||'')));let count=0;let batch=db.batch();const commit=async()=>{if(count)await batch.commit();batch=db.batch();count=0;};let added=0,skipped=0;
for(const r of rows){if(ids.has(r.code)||names.has(normal(r.name))){skipped++;continue;}batch.create(ref.doc(r.code),{name:r.name,category:r.category,baseUnit:r.baseUnit,sourceType:r.sourceType,units:{},createdAt:admin.firestore.FieldValue.serverTimestamp()});count++;added++;ids.add(r.code);names.add(normal(r.name));if(count===400)await commit();}
await commit();console.log(JSON.stringify({added,skipped,totalCsv:rows.length}));})().catch(e=>{console.error(e);process.exitCode=1;});
