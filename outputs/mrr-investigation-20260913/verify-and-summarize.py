exec(compile((__import__('pathlib').Path(__file__).parent/'analyze-reports.py').read_text(encoding='utf-8').split('print(json.dumps(extra')[0], 'analyze-reports.py','exec'))
from datetime import datetime,timezone,timedelta
checks=[]
for name,rows in [('current',current),('total',total_report)]:
    r=json.loads((ROOT/('run-rendery-'+name+'.json')).read_text(encoding='utf-8'))
    ag=r['factMap']['T!T']['aggregates']
    assert r['allData'] and int(ag[-1]['value'])==len(rows)
    assert abs(dec(ag[0]['value'])-total(rows,'Total__c'))<Decimal('.01')
    checks.append({'check':name+' row count and total','passed':True,'rows':len(rows),'total':str(total(rows,'Total__c').quantize(Decimal('.01')))})
    by_month=group(rows,month)
    for g in r['groupingsDown']['groupings']:
        mo=str(g['value'])[:7].replace('/','-')
        assert mo in by_month,(name,mo)
        actual=r['factMap'][g['key']+'!T']['aggregates']
        assert abs(dec(actual[0]['value'])-total(by_month[mo],'Total__c'))<Decimal('.01'),(name,mo)
    checks.append({'check':name+' all monthly totals','passed':True,'groups':len(by_month)})
ar=json.loads((ROOT/'run-active-contracts.json').read_text(encoding='utf-8'))
assert ar['factMap']['T!T']['aggregates'][0]['value']==sum(x['Status__c']=='Activated' for x in c)
checks.append({'check':'active contract count','passed':True,'count':143})
apex=load('apex'); differences=[]
for cls in apex:
    source=ROOT.parent.parent/'force-app/main/default/classes'/ (cls['Name']+'.cls')
    same=source.read_text(encoding='utf-8-sig').strip().replace('\r','')==cls['Body'].strip().replace('\r','')
    differences.append({'Name':cls['Name'],'SameAsLocal':same,'LastModifiedDate':cls['LastModifiedDate']})
assert all(x['SameAsLocal'] for x in differences)
save('code-comparison',differences)
def normalize(s): return re.sub(r'[\s　]','',re.sub(r'[（(][^）)]*[）)]','',s).replace('株式会社','').replace('有限会社',''))
alias=[]
for key,rows in group(c,lambda x:normalize((x.get('Account__r') or {}).get('Name',''))).items():
    if key and len({x['Account__c'] for x in rows})>1:
        for co in rows: alias.append({'NormalizedName':key,'AccountId':co['Account__c'],'AccountName':co['Account__r']['Name'],'Contract':co['Name'],'ContractName':co['ContractName__c'],'Status':co['Status__c']})
save('account-alias-candidates',alias)
flags=[annotated(x)|{'ProductMRR':pri[x['ProductMaster__c']]['MRR_Target__c']} for x in m if x['ProductMaster__c'] in pri and x['MRR_Target__c']!=pri[x['ProductMaster__c']]['MRR_Target__c']]
save('monthly-product-flag-mismatch',flags)
longnames=[{'Contract':x['Name'],'ContractName':x['ContractName__c'],'Length':len(x['ContractName__c']+'_2026/10'),'Category':x['ProductCategory__c']} for x in c if x['Status__c']=='Activated' and len(x['ContractName__c']+'_2026/10')>80]
save('batch-name-length-risk',longnames)
rel=[x for x in anomalies if x['Issue'] in ['period_contract_mismatch','invoice_contract_mismatch']]
save('relation-mismatches',rel)
latest={}
for name,rows in [('current',current),('total',total_report)]:
    latest[name]={mo:summarize_rows([x for x in rows if month(x)==mo]) for mo in ['2026-04','2026-06','2026-07','2026-08','2026-09']}
expected=[x for x in c if x['Status__c']=='Activated' and active(x,'2026-09')]
missing=[x for x in expected if not any(month(z)=='2026-09' for z in mc[x['Id']])]
summary.update({'flag_mismatch_rows':len(flags),'alias_candidate_names':len({x['NormalizedName'] for x in alias}),'september_expected_contracts_by_status_dates':len(expected),'september_missing_contracts':len(missing),'september_missing_categories':dict(collections.Counter(x['ProductCategory__c'] or '未設定' for x in missing)),'name_length_risk_contracts':len(longnames),'contract_opportunity_linked':sum(x['Oppotunity__c'] in oi for x in c),'contract_opportunity_different':sum(x['Oppotunity__c'] in oi and x['MRR__c']!=oi[x['Oppotunity__c']]['MRR__c'] for x in c),'current_report_outside_contract_period_rows':sum(not active(ci[x['MasterContract__c']],month(x)) for x in current),'total_revenue_different_rows':sum(x['Total__c']!=x['RevenueAmount__c'] for x in m)})
dump('analysis-summary',summary);dump('validation',checks);dump('latest-report-summary',latest)
print(json.dumps(summary,ensure_ascii=False,indent=2,default=str));print(json.dumps(checks,ensure_ascii=False,indent=2,default=str));print('longnames',json.dumps(longnames,ensure_ascii=False));print('refs',json.dumps(rel,ensure_ascii=False,default=str))
