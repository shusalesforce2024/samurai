from pathlib import Path
import csv,json,re,sys
sys.stdout.reconfigure(encoding='utf-8')
p=Path(__file__).parent
report=p/'MRR課題・深掘り調査報告.md'
text=report.read_text(encoding='utf-8')
issues=[]
for line in text.splitlines():
    if re.match(r'\| M\d\d \|',line):
        cols=[x.strip() for x in line.strip('|').split('|')]
        assert len(cols)==6
        issues.append(dict(zip(['課題ID','優先度','課題','確認事実と影響','原因の確度','対応方針'],cols))|{'担当案':'川波・開発担当／SAMURAI業務責任者（要確定）','期限':'未定','状態':'調査済・修正未実施'})
assert len(issues)==12
with (p/'課題一覧.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(issues[0]));w.writeheader();w.writerows(issues)
broken=[]
for target in re.findall(r'\]\(([^)]+)\)',text):
    if not target.startswith(('http:','https:','#')) and not (p/target).exists(): broken.append(target)
assert not broken,broken
assert '\ufffd' not in text
tables=0
for block in re.split(r'\n\s*\n',text):
    rows=[line for line in block.splitlines() if line.startswith('|')]
    if not rows:continue
    n=rows[0].count('|')
    assert all(line.count('|')==n for line in rows),rows
    tables+=1
months=list(csv.DictReader((p/'report-monthly-reconciliation.csv').open(encoding='utf-8-sig')))
totalmonths=[x['Month'] for x in months if x['Report']=='Rendery Total MRR']
assert len(totalmonths)==40 and min(totalmonths)=='2024-06' and max(totalmonths)=='2027-09'
print(json.dumps({'issues':len(issues),'tables':tables,'broken_links':broken,'report_characters':len(text),'report_month_span':[min(totalmonths),max(totalmonths)]},ensure_ascii=False))
# Small companion notebook; calculations stay in the checked scripts.
notebook={'cells':[{'cell_type':'markdown','metadata':{},'source':['# Rendery MRR 調査の再計算\n','2026年9月13日の取得済み本番スナップショットを読み、課題候補とレポート照合を再計算する。Salesforceへの接続・更新は行わない。\n','同フォルダを作業ディレクトリとして実行する。金額は現状の再現値であり、正しいMRR確定値ではない。']},{'cell_type':'code','execution_count':None,'metadata':{},'outputs':[],'source':['from pathlib import Path\n','import runpy\n','runpy.run_path(str(Path("verify-and-summarize.py").resolve()), run_name="__main__")\n']},{'cell_type':'code','execution_count':None,'metadata':{},'outputs':[],'source':['import json\n','json.loads(Path("validation.json").read_text(encoding="utf-8"))\n']}],'metadata':{'kernelspec':{'display_name':'Python 3','language':'python','name':'python3'},'language_info':{'name':'python'}},'nbformat':4,'nbformat_minor':5}
(p/'再計算ノートブック.ipynb').write_text(json.dumps(notebook,ensure_ascii=False,indent=2),encoding='utf-8')
