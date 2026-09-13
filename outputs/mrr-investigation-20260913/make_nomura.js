const fs=require('fs'); const path='outputs/mrr-investigation-20260913/';
const load=f=>JSON.parse(fs.readFileSync(path+f,'utf8')).result.records;
const cs=load('contracts.json'), ms=load('monthly.json'), is=load('invoices.json'), qs=load('quotations.json'), ql=load('quotation-lines.json'), ps=load('products.json');
const nm=x=>(x||'').replaceAll('"','""'); const prod=new Map(ps.map(x=>[x.Id,x.Name]));
const nc=cs.filter(x=>(x.Account__r?.Name||'').includes('野村不動産'));
let out=['契約ID,契約番号,契約ステータス,契約MRR,契約自動作成,契約作成元,月次明細ID,年月,月次明細名,商品ID,商品名,Total,RevenueAmount,MRR_Target,InitialFee,QuotationLineID,RelatedInvoiceID,契約取引ID'];
for(const c of nc){for(const m of ms.filter(x=>x.MasterContract__c===c.Id&&x.ContractYearMonth__c==='2026/08')) out.push([c.Id,c.Name,c.Status__c,c.MRR__c??'',c.AutoCreatedFromFreee__c,c.CreationSource__c??'',m.Id,m.ContractYearMonth__c,m.Name,m.ProductMaster__c??'',prod.get(m.ProductMaster__c)||'',m.Total__c??'',m.RevenueAmount__c??'',m.MRR_Target__c,m.InitialFee__c,m.QuotationLine__c??'',m.RelatedInvoice__c??'',c.Oppotunity__c??''].map(v=>'"'+nm(String(v))+'"').join(','));}
out.push(''); out.push('# 契約・請求紐付けサマリ');
for(const c of nc){const inv=is.filter(x=>x.Contract__c===c.Id||x.Account__c===c.Account__c); for(const i of inv) out.push([c.Name,'請求',i.Id,i.Name,i.Total__c??'',i.BillingDate__c??'',i.Status__c??''].map(v=>'"'+nm(String(v))+'"').join(','));}
fs.writeFileSync(path+'野村不動産_契約商品請求見積突合.csv',out.join('\n'),'utf8');
console.log('written',out.length);
