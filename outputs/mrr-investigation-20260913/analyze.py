from pathlib import Path
import json, csv, collections, itertools, re, calendar, sys
from decimal import Decimal

ROOT=Path(__file__).resolve().parent
sys.stdout.reconfigure(encoding='utf-8')
def load(name):
    o=json.loads((ROOT/(name+'.json')).read_text(encoding='utf-8-sig'))
    assert o['status']==0 and o['result']['done'], name
    r=o['result']['records']; assert len(r)==o['result']['totalSize'], name
    assert len({x['Id'] for x in r})==len(r), name
    return r
def dec(x): return Decimal(str(x)) if x is not None else Decimal(0)
def total(rows,field='RevenueAmount__c'): return sum((dec(x.get(field)) for x in rows),Decimal(0))
def group(rows,key):
    out=collections.defaultdict(list)
    for row in rows: out[key(row)].append(row)
    return out
def save(name,rows):
    if not rows: (ROOT/(name+'.csv')).write_text('',encoding='utf-8-sig'); return
    cols=list(dict.fromkeys(k for row in rows for k in row))
    with (ROOT/(name+'.csv')).open('w',newline='',encoding='utf-8-sig') as f:
        w=csv.DictWriter(f,fieldnames=cols); w.writeheader(); w.writerows(rows)
def dump(name,obj): (ROOT/(name+'.json')).write_text(json.dumps(obj,ensure_ascii=False,indent=2,default=str),encoding='utf-8')

datasets={n:load(n) for n in ['contracts','monthly','periods','invoices','invoice-lines','opportunities','quotations','quotation-lines','products']}
c,m,p,i,il,o,q,ql,pr=(datasets[n] for n in datasets)
ci={x['Id']:x for x in c}; pi={x['Id']:x for x in p}; ii={x['Id']:x for x in i}; oi={x['Id']:x for x in o}; qi={x['Id']:x for x in q}; pri={x['Id']:x for x in pr}
mc=group(m,lambda x:x['MasterContract__c']); ic=group(i,lambda x:x['ParentContract__c']); pc=group(p,lambda x:x['Contract__c'])
def month(x): return (x.get('PeriodStartDate__c') or '')[:7]
def cat(x): return ci.get(x.get('MasterContract__c'),{}).get('ProductCategory__c')
def active(c,mo):
    if not mo: return False
    end=mo+'-'+str(calendar.monthrange(int(mo[:4]),int(mo[5:7]))[1])
    return c.get('Status__c') in ['Activated','更新予定','更新済','Expired','解約'] and bool(c.get('StartDate__c')) and c['StartDate__c']<=end and (not c.get('EndDate__c') or c['EndDate__c']>=mo+'-01') and (c['Status__c'] not in ['Expired','解約'] or bool(c.get('EndDate__c')))
def annotated(x):
    co=ci.get(x['MasterContract__c'],{})
    return dict(x,ContractNumber=co.get('Name'),ContractName=co.get('ContractName__c'),ContractStatus=co.get('Status__c'),AccountName=(co.get('Account__r') or {}).get('Name'),ProductName=pri.get(x.get('ProductMaster__c'),{}).get('Name'))
profile=[]
for name,rows in datasets.items():
    profile.append({'dataset':name,'rows':len(rows),'unique_ids':len({x['Id'] for x in rows}),'min_created':min((x.get('CreatedDate') or '' for x in rows),default=''),'max_created':max((x.get('CreatedDate') or '' for x in rows),default='')})
save('source-profile',profile)
summary={'source_counts':{n:len(r) for n,r in datasets.items()},'contract_status':dict(collections.Counter(x['Status__c'] for x in c))}
monthly_summary=[]
for (mo,category),rows in sorted(group(m,lambda x:(month(x),cat(x) or '未設定')).items()):
    mr=[x for x in rows if x['MRR_Target__c']]
    monthly_summary.append(dict(Month=mo,Category=category,Rows=len(rows),MRRRows=len(mr),RawMRR=total(mr),ActivePeriodMRR=total([x for x in mr if active(ci.get(x['MasterContract__c'],{}),mo)]),InitialMRR=total([x for x in mr if x['InitialFee__c']]),DraftMRR=total([x for x in mr if ci.get(x['MasterContract__c'],{}).get('Status__c')=='Draft']),NullRevenueRows=sum(x['RevenueAmount__c'] is None for x in mr)))
save('monthly-summary',monthly_summary)

# Candidate groups: multiple lines alone are not proof of duplicated revenue.
for mode,fields in [('same-contract-product',['MasterContract__c','ProductMaster__c']),('same-contract-source',['MasterContract__c','ProductMaster__c','QuotationLine__c'])]:
    groups=group(m,lambda x:(month(x),)+tuple(x.get(f) for f in fields))
    rows=[]
    for key,items in groups.items():
        if len(items)<2 or not key[0] or not key[2]: continue
        rows.append({'Month':key[0],'Contract':ci.get(key[1],{}).get('Name'),'ContractName':ci.get(key[1],{}).get('ContractName__c'),'Product':pri.get(key[2],{}).get('Name'),'Count':len(items),'MRRRows':sum(x['MRR_Target__c'] for x in items),'MRRSum':total([x for x in items if x['MRR_Target__c']]),'Amounts':'|'.join(str(x['RevenueAmount__c']) for x in items),'SourceIds':'|'.join(str(x['QuotationLine__c']) for x in items),'InvoiceIds':'|'.join(str(x['RelatedInvoice__c']) for x in items),'RecordIds':'|'.join(x['Id'] for x in items)})
    save(mode,rows); summary[mode]={'groups':len(rows),'rows':sum(x['Count'] for x in rows)}

# Same account + same month + same product across contracts, both named and empty products distinguished.
cross=[]
for key,rows in group(m,lambda x:(ci.get(x['MasterContract__c'],{}).get('Account__c'),month(x),x['ProductMaster__c'])).items():
    cs={x['MasterContract__c'] for x in rows}
    if len(cs)<2 or not key[0] or not key[1] or not key[2]: continue
    cross.append({'AccountId':key[0],'AccountName':(ci[next(iter(cs))].get('Account__r') or {}).get('Name'),'Month':key[1],'Product':pri.get(key[2],{}).get('Name'),'Contracts':'|'.join(sorted(ci[z]['Name'] for z in cs)),'Count':len(rows),'MRRSum':total([x for x in rows if x['MRR_Target__c']]),'RecordIds':'|'.join(x['Id'] for x in rows)})
save('cross-contract-product-candidates',cross); summary['cross_contract']={'groups':len(cross),'rows':sum(x['Count'] for x in cross)}
contract_candidates=[]
for account,rows in group(c,lambda x:x['Account__c']).items():
    nonmig=[x for x in rows if not x['ContractName__c'].startswith('Mig_')]
    if len(nonmig)<2: continue
    for co in rows:
        contract_candidates.append({'AccountId':account,'AccountName':(co.get('Account__r') or {}).get('Name'),'Contract':co['Name'],'ContractName':co['ContractName__c'],'Status':co['Status__c'],'Start':co['StartDate__c'],'End':co['EndDate__c'],'MRR':co['MRR__c'],'Source':co['CreationSource__c'],'MonthlyRows':len(mc[co['Id']]),'Invoices':len(ic[co['Id']]),'Periods':len(pc[co['Id']])})
save('multiple-contract-candidates',contract_candidates)
summary['multiple_contract_accounts']=len({x['AccountId'] for x in contract_candidates})

targetc=[x for x in c if any(s in ((x.get('Account__r') or {}).get('Name','')+x['ContractName__c']) for s in ['野村不動産','デザインアーク','創建ホーム'])]
targetids={x['Id'] for x in targetc}
save('target-monthly-details',[annotated(x) for x in m if x['MasterContract__c'] in targetids])
targetsummary=[]
for co in targetc:
    row={k:co[k] for k in ['Id','Name','ContractName__c','Account__c','Status__c','MRR__c','StartDate__c','EndDate__c','ContractUpdate__c','CreationSource__c','Oppotunity__c','SourceQuotation__c','CreatedDate']}
    row.update(AccountName=(co.get('Account__r') or {}).get('Name'),Invoices=len(ic[co['Id']]),Periods=len(pc[co['Id']]),MonthlyRows=len(mc[co['Id']]))
    for mo in ['2026-04','2026-05','2026-06','2026-07','2026-08','2026-09','2026-10']:
        rows=[x for x in mc[co['Id']] if month(x)==mo and x['MRR_Target__c']]
        row[mo]=total(rows); row[mo+'_rows']=len(rows)
    targetsummary.append(row)
save('target-contract-summary',targetsummary)

migids={x['Id'] for x in c if x['ContractName__c'].startswith('Mig_freee')}
migrows=[x for x in m if x['MasterContract__c'] in migids]
summary['migration']={'contracts':len(migids),'status':dict(collections.Counter(ci[x]['Status__c'] for x in migids)),'monthly_rows':len(migrows),'mrr_rows':sum(x['MRR_Target__c'] for x in migrows),'all_months_mrr_sum_not_current_mrr':total([x for x in migrows if x['MRR_Target__c']]),'invoices':sum(x['ParentContract__c'] in migids for x in i)}
save('migration-monthly-details',[annotated(x) for x in migrows])
anomalies=[]
for x in m:
    co=ci.get(x['MasterContract__c'],{}); pe=pi.get(x['ContractPeriod__c']); inv=ii.get(x['RelatedInvoice__c'])
    reasons=[]
    if not co: reasons.append('parent_contract_missing')
    if pe and pe['Contract__c']!=x['MasterContract__c']: reasons.append('period_contract_mismatch')
    if not pe: reasons.append('period_missing')
    if inv and inv['ParentContract__c']!=x['MasterContract__c']: reasons.append('invoice_contract_mismatch')
    if co and x['Account__c']!=co['Account__c']: reasons.append('account_mismatch')
    if x['MRR_Target__c'] and x['RevenueAmount__c'] is None: reasons.append('mrr_amount_null')
    if x['MRR_Target__c'] and x['InitialFee__c']: reasons.append('initial_in_mrr')
    if not x['ProductMaster__c']: reasons.append('product_missing')
    if not month(x): reasons.append('month_missing')
    if x['ContractYearMonth__c'] and month(x).replace('-','/')!=x['ContractYearMonth__c']: reasons.append('month_label_mismatch')
    for reason in reasons: anomalies.append(dict(annotated(x),Issue=reason))
save('monthly-anomalies',anomalies); summary['monthly_anomalies']=dict(collections.Counter(x['Issue'] for x in anomalies))

# Recompute opportunity totals; proposed normalized scenario is not a confirmed correct MRR.
qo=group(q,lambda x:x['Oppotunity__c']); lq=group(ql,lambda x:x['Quotation__c'])
opp_analysis=[]
for op in o:
    quotes=qo[op['Id']]
    if not quotes: continue
    lines=[ln for qt in quotes for ln in lq[qt['Id']]]
    accepted=[qt for qt in quotes if qt['Quotation_Status__c']=='Accepted']
    valid=[]; nullproducts=0
    for qt in accepted:
        for ln in lq[qt['Id']]:
            product=pri.get(ln['ProductMaster__c'])
            if not product: nullproducts+=1; continue
            if product['MRR_Target__c'] and product['ProductType__c']!='初期費用' and product['BillingTiming__c']!='初回のみ': valid.append(ln)
    normalized=sum((dec(ln['Line_Amount__c'])/(12 if op['ContractUpdate__c']=='年' else 1) for ln in valid),Decimal(0))
    opp_analysis.append({'Id':op['Id'],'Name':op['Name'],'Stage':op['StageName__c'],'Category':op['ProductCategory__c'],'Cycle':op['ContractUpdate__c'],'StoredMRR':op['MRR__c'],'QuoteCount':len(quotes),'AcceptedCount':len(accepted),'AllQuoteTotal':total(quotes,'TotalAmount__c'),'AllLineTotal':total(lines,'Line_Amount__c'),'AcceptedRecurringMonthlyScenario':normalized,'DifferenceToScenario':dec(op['MRR__c'])-normalized,'AcceptedMissingProducts':nullproducts,'NonAcceptedLineTotal':total([ln for qt in quotes if qt not in accepted for ln in lq[qt['Id']]],'Line_Amount__c'),'ExcludedAcceptedLineTotal':total([ln for qt in accepted for ln in lq[qt['Id']] if ln not in valid],'Line_Amount__c')})
save('opportunity-mrr-comparison',opp_analysis)
summary['opportunity_comparison']={'with_quotes':len(opp_analysis),'multiple_quotes':sum(x['QuoteCount']>1 for x in opp_analysis),'multiple_accepted':sum(x['AcceptedCount']>1 for x in opp_analysis),'scenario_diff_count':sum(x['DifferenceToScenario']!=0 for x in opp_analysis),'annual_with_quotes':sum(x['Cycle']=='年' for x in opp_analysis)}
save('opportunity-no-quote',[x for x in o if not qo[x['Id']] and dec(x['MRR__c'])!=0])
save('contract-opportunity-mrr-differences',[{'Contract':co['Name'],'ContractMRR':co['MRR__c'],'OpportunityId':co['Oppotunity__c'],'OpportunityMRR':oi[co['Oppotunity__c']]['MRR__c']} for co in c if co['Oppotunity__c'] in oi and co['MRR__c']!=oi[co['Oppotunity__c']]['MRR__c']])

dump('analysis-summary',summary)
print(json.dumps(summary,ensure_ascii=False,indent=2,default=str))
print('TARGETS');print(json.dumps(targetsummary,ensure_ascii=False,indent=2,default=str))
