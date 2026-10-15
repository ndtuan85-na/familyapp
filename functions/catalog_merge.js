'use strict';
const fs=require('node:fs');const path=require('node:path');
const csv=path.join(__dirname,'../assets/quynh_luu_seafood.csv');
const lines=fs.readFileSync(csv,'utf8').trim().split(/\r?\n/);
const existing=lines.slice(1).map(l=>{const [code,category,name,baseUnit,sourceType]=l.split(',');return {code,category,name,baseUnit,sourceType};});
const normalize=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/đ/g,'d').replace(/Đ/g,'D').toLowerCase().replace(/[^a-z0-9]/g,'');
const categoryOf=(r)=>{if(/^(Cá chế biến|Mực chế biến|Tôm chế biến|Hàng chế biến)$/.test(r.category))return 'Đồ đã chế biến';if(r.category==='Cá')return 'Cá';if(r.category==='Tôm')return 'Tôm';if(r.category==='Mực')return 'Mực';return 'Thực phẩm khác';};
for(const r of existing)r.category=categoryOf(r);
const additional=[
['CHA_OC','Đồ đã chế biến','Chả ốc'],['CHA_CA','Đồ đã chế biến','Chả cá'],['CHA_MUC','Đồ đã chế biến','Chả mực'],['NEM_HAI_SAN','Đồ đã chế biến','Nem hải sản'],['CA_NUC_MOT_NANG','Đồ đã chế biến','Cá nục một nắng'],['CA_NUC_CHUOI','Cá','Cá nục chuối'],['CA_THU_NUONG','Đồ đã chế biến','Cá thu nướng'],['CA_THU_TUOI','Cá','Cá thu tươi'],['CA_THU_LUON','Cá','Cá thu lườn'],['CA_THU_MIENG','Cá','Cá thu miếng'],['CA_THU_DAU_DUOI','Cá','Cá thu đầu đuôi'],['TOM_BOC','Tôm','Tôm bóc'],['TOM_NON','Tôm','Tôm nõn'],['MOI','Tôm','Moi'],['CA_MOM_TUOI','Cá','Cá mờm tươi'],['CA_MOM_KHO','Đồ đã chế biến','Cá mờm khô'],['CA_MOM_RIM_LAC','Đồ đã chế biến','Cá mờm rim lạc'],['MUC_SIM_KHO','Đồ đã chế biến','Mực sim khô'],['MUC_RIM','Đồ đã chế biến','Mực rim'],['MUC_HAP','Đồ đã chế biến','Mực hấp'],['MUC_MOT_NANG','Đồ đã chế biến','Mực một nắng'],['MUC_SIM_TUOI','Mực','Mực sim tươi'],['MUC_SIM_NHAY','Mực','Mực sim nháy'],['MUC_NHAY_THUONG','Mực','Mực nháy thường'],['MUC_NHAY_TO','Mực','Mực nháy to'],['MUC_ONG_THUONG','Mực','Mực ống thường'],['MUC_ONG_TO','Mực','Mực ống to'],['HAU_BOC','Thực phẩm khác','Hàu bóc'],['GHE_XAY','Thực phẩm khác','Ghẹ xay'],['CHAN_MAI','Thực phẩm khác','Chân mai'],['CA_THUNG','Cá','Cá thửng'],['CA_CHI_VANG','Cá','Cá chỉ vàng'],['CA_BI_KHO','Đồ đã chế biến','Cá bì khô'],['TOM_LOT','Tôm','Tôm lột'],['TOM','Tôm','Tôm'],['CA_NUC_UOP','Đồ đã chế biến','Cá nục ướp'],['LUON','Thực phẩm khác','Lươn']];
const names=new Set(existing.map(r=>normalize(r.name)));
const ids=new Set(existing.map(r=>r.code));
let added=0;
for(const [code,category,name] of additional){
 if(names.has(normalize(name)) || ids.has(code)) continue;
 existing.push({code,category,name,baseUnit:'kg',sourceType:'user_requested'});names.add(normalize(name));ids.add(code);added++;
}
const output=['code,category,name,base_unit,source_type',...existing.map(r=>[r.code,r.category,r.name,r.baseUnit,r.sourceType].join(','))].join('\n')+'\n';
fs.writeFileSync(csv,output);
console.log(JSON.stringify({existing:lines.length-1,added,total:existing.length,categories:Object.fromEntries([...new Set(existing.map(x=>x.category))].map(c=>[c,existing.filter(x=>x.category===c).length]))},null,2));
