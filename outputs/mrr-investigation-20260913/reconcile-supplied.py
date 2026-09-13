from pathlib import Path
from collections import Counter,defaultdict
from decimal import Decimal
import json,csv,re,sys
sys.stdout.reconfigure(encoding='utf-8')
p=Path(__file__).parent
sheets=json.loads((p/'supplied-workbook-cells.json').read_text(encoding='utf-8'))
live=json.loads((p/'monthly.json').read_text(encoding='utf-8'))['result']['records']
contracts=json.loads((p/'contracts.json').read_text(encoding='utf-8'))['result']['records']
cn={x['Id']:x['Name'] for x in contracts}
def rows(sheet,datecol,accountcol,contractcol,namecol,amountcol,mrrcol):
    out=[]; date=None
    for rr in sheet['rows']:
        cells={re.sub(r'\d+','',c['cell']):c for c in rr}
        if datecol in cells and re.match(r'20\d\d/\d\d/\d\d$',cells[datecol]['value']):date=cells[datecol]['value']
        if not re.match(r'CN-\d+',cells.get(contractcol,{}).get('value','')):continue
        out.append({'SourceSheet':sheet['name'],'SourceRow':int(re.sub(r'\D+','',rr[0]['cell'])),'Date':date,'Account':cells.get(accountcol,{}).get('value'),'Contract':cells[contractcol]['value'],'MonthlyName':cells.get(namecol,{}).get('value'),'Amount':cells.get(amountcol,{}).get('value'),'ContractMRR':cells.get(mrrcol,{}).get('value')})
    return out
a=rows(sheets[0],'B','D','E','F','G','H'); b=rows(sheets[1],'C','E','F','G','H','I')
aug=[r for r in a if r['Date']=='2026/08/01']
def key(r):return (r['Date'],r['Contract'],r['MonthlyName'],r['Amount'])
def total(rs):return sum((Decimal(r['Amount']) for r in rs if r['Amount'] is not None),Decimal(0))
def save(name,rs):
    with (p/name).open('w',encoding='utf-8-sig',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rs[0]) if rs else ['NoRecords']); w.writeheader();w.writerows(rs)
before=Counter(key(r) for r in aug); after=Counter(key(r) for r in b)
removed=before-after; added=after-before
rm=[];ad=[]
for r in aug:
    if removed[key(r)]:rm.append(r);removed[key(r)]-=1
for r in b:
    if added[key(r)]:ad.append(r);added[key(r)]-=1
def matches(r):
    return [x for x in live if cn.get(x['MasterContract__c'])==r['Contract'] and x['Name']==r['MonthlyName'] and (x.get('PeriodStartDate__c') or '').replace('-','/')==r['Date'] and ((r['Amount'] is None and x['Total__c'] is None) or (r['Amount'] is not None and x['Total__c'] is not None and Decimal(r['Amount'])==Decimal(str(x['Total__c']))))]
reconciled=[]
for r in a+b:
    hits=matches(r)
    reconciled.append(r|{'LiveMatchCount':len(hits),'LiveIds':'|'.join(x['Id'] for x in hits),'LiveTotals':'|'.join(str(x['Total__c']) for x in hits),'AmountMatch':len(hits)==1 and (r['Amount'] is None and hits[0]['Total__c'] is None or r['Amount'] is not None and hits[0]['Total__c'] is not None and Decimal(r['Amount'])==Decimal(str(hits[0]['Total__c'])))})
save('共有一覧_本番照合.csv',reconciled);save('共有一覧_元シートとの差分.csv',[r|{'Difference':'2枚目にない','LiveIds':'|'.join(x['Id'] for x in matches(r))} for r in rm]+[r|{'Difference':'2枚目にのみある','LiveIds':'|'.join(x['Id'] for x in matches(r))} for r in ad])
summary={'sheet1_rows':len(a),'sheet1_aug_rows':len(aug),'sheet1_aug_amount':str(total(aug)),'sheet2_rows':len(b),'sheet2_amount':str(total(b)),'removed_rows':len(rm),'removed_amount':str(total(rm)),'added_rows':len(ad),'added_amount':str(total(ad)),'unique_live_match_rows':sum(r['LiveMatchCount']==1 for r in reconciled),'amount_match_rows':sum(r['AmountMatch'] for r in reconciled),'comparison_rows':len(reconciled),'removed':rm,'added':ad}
summary['removed_candidates']=[r|{'LiveMatchCount':len(matches(r)),'LiveRecords':[{k:x[k] for k in ['Id','ProductMaster__c','QuotationLine__c','MRR_Target__c','RelatedInvoice__c','Total__c']} for x in matches(r)]} for r in rm]
cc={x['Id']:x for x in contracts}
actual=[x for x in live if cc[x['MasterContract__c']]['ProductCategory__c']=='Rendery' and cc[x['MasterContract__c']]['Status__c']=='Activated' and '2026-03-01'<=(x['PeriodStartDate__c'] or '')<='2027-02-28']
live_counter=Counter(((x['PeriodStartDate__c'] or '').replace('-','/'),cn[x['MasterContract__c']],x['Name'],str(Decimal(str(x['Total__c'])).normalize()) if x['Total__c'] is not None else None) for x in actual)
sheet_counter=Counter((r['Date'],r['Contract'],r['MonthlyName'],str(Decimal(r['Amount']).normalize()) if r['Amount'] is not None else None) for r in a)
summary['sheet1_multiset_matches_live']=sheet_counter==live_counter
assert summary['sheet1_multiset_matches_live']
(p/'supplied-reconciliation-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
for s in sheets:
    print('special rows',s['name'])
    for rr in s['rows']:
        if any(c['value'] in ['小計','総計'] for c in rr):print(rr)
