exec(compile((__import__('pathlib').Path(__file__).parent/'analyze.py').read_text(encoding='utf-8').split("print(json.dumps(summary")[0], 'analyze.py','exec'))
def fy(d): return bool(d) and '2026-03-01'<=d[:10]<='2027-02-28'
current=[x for x in m if cat(x)=='Rendery' and ci[x['MasterContract__c']]['Status__c']=='Activated' and fy(x['PeriodStartDate__c'])]
total_report=[x for x in m if 'Rendery' in pri.get(x['ProductMaster__c'],{}).get('Name','') and fy(x['CreatedDate'])]
def summarize_rows(rows):
    return dict(Rows=len(rows),Total=total(rows,'Total__c'),MRRFlagRevenue=total([x for x in rows if x['MRR_Target__c']]),NonMRRTotal=total([x for x in rows if not x['MRR_Target__c']],'Total__c'),InitialTotal=total([x for x in rows if x['InitialFee__c']],'Total__c'),DraftTotal=total([x for x in rows if ci[x['MasterContract__c']]['Status__c']=='Draft'],'Total__c'),MigrationTotal=total([x for x in rows if x['MasterContract__c'] in migids],'Total__c'),NoProductTotal=total([x for x in rows if not x['ProductMaster__c']],'Total__c'))
rs=[]
for name,rows in [('Rendery月別契約中MRR',current),('Rendery Total MRR',total_report)]:
    for mo,items in sorted(group(rows,month).items()):rs.append(dict(Report=name,Month=mo,**summarize_rows(items)))
save('report-monthly-reconciliation',rs)
ts=[]
for co in targetc:
    for mo,rows in sorted(group(mc[co['Id']],month).items()):
        ts.append(dict(Contract=co['Name'],ContractName=co['ContractName__c'],Month=mo,**summarize_rows(rows),CurrentReportTotal=total([x for x in rows if x in current],'Total__c'),TotalReportTotal=total([x for x in rows if x in total_report],'Total__c')))
save('target-report-contributions',ts)
extra={'rendery_current':summarize_rows(current),'rendery_total':summarize_rows(total_report)}
for name,rows in [('current',current),('total',total_report)]:
    rpath=ROOT/('run-rendery-'+name+'.json')
    if rpath.exists():
        r=json.loads(rpath.read_text(encoding='utf-8-sig'))
        extra[name+'_report_api']={'allData':r.get('allData'),'fact_total':r.get('factMap',{}).get('T!T'),'reportMetadata':r.get('reportMetadata',{}).get('aggregates')}
save('rendery-current-report-rows',[annotated(x) for x in current])
save('rendery-total-report-rows',[annotated(x) for x in total_report])
save('active-contracts-missing-september',[dict(Contract=co['Name'],ContractName=co['ContractName__c'],Category=co['ProductCategory__c'],Start=co['StartDate__c'],End=co['EndDate__c'],MRR=co['MRR__c'],Cycle=co['ContractUpdate__c']) for co in c if co['Status__c']=='Activated' and active(co,'2026-09') and not any(month(x)=='2026-09' for x in mc[co['Id']])])
save('report-excluded-period-candidates',[annotated(x) for x in current if not active(ci[x['MasterContract__c']],month(x))])
save('total-versus-revenue-differences',[annotated(x) for x in m if x['Total__c']!=x['RevenueAmount__c']])
save('annual-contract-profile',[dict(Contract=co['Name'],ContractName=co['ContractName__c'],MRR=co['MRR__c'],Start=co['StartDate__c'],End=co['EndDate__c'],MonthlyRows=len(mc[co['Id']]),MonthlyDistinctMonths=len({month(x) for x in mc[co['Id']]}),Invoices=len(ic[co['Id']])) for co in c if co['ContractUpdate__c']=='年' and co['Status__c']=='Activated'])
save('same-product-multiple-accounts',[dict(ProductName=pri.get(key[1],{}).get('Name'),Month=key[0],Accounts='|'.join(sorted({ci[x['MasterContract__c']]['Account__r']['Name'] for x in rows})),Contracts='|'.join(sorted({ci[x['MasterContract__c']]['Name'] for x in rows})),Amount=key[2]) for key,rows in group([x for x in m if x['MasterContract__c'] in targetids],lambda x:(month(x),x['ProductMaster__c'],x['Total__c'])).items() if key[1] and len({ci[x['MasterContract__c']]['Account__c'] for x in rows})>1])
dump('report-analysis',extra)
print(json.dumps(extra,ensure_ascii=False,indent=2,default=str)); print(json.dumps(rs,ensure_ascii=False,indent=2,default=str));print(json.dumps(ts,ensure_ascii=False,indent=2,default=str))
