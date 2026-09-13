from pathlib import Path
from docx import Document
from docx.shared import Pt
from docx.enum.text import WD_BREAK
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

PATH = Path('docs/contracts/Stripe_CSV_Salesforce投入_見積書_ドラフト.docx')
d = Document(PATH)
if any(p.text.strip() == '10. 実現可能性の事前確認・懸念事項' for p in d.paragraphs):
    raise SystemExit('section already exists')

issuer = next(p for p in d.paragraphs if p.text.strip() == '発行者')

def set_font(run, size=9, bold=False):
    run.font.name = 'Yu Gothic'
    run._element.get_or_add_rPr().rFonts.set(qn('w:eastAsia'), 'Yu Gothic')
    run._element.rPr.rFonts.set(qn('w:ascii'), 'Arial')
    run._element.rPr.rFonts.set(qn('w:hAnsi'), 'Arial')
    run.font.size = Pt(size); run.bold = bold

created=[]
h=d.add_paragraph(); h.paragraph_format.space_after=Pt(4); set_font(h.add_run('10. 実現可能性の事前確認・懸念事項'),12,True); created.append(h._p)
p=d.add_paragraph(); p.paragraph_format.space_after=Pt(5); p.paragraph_format.line_spacing=1.05
set_font(p.add_run('現時点の判定：単一商品・日割り等がない標準的な請求は、CSV＋Excel＋Data Loaderで実現可能です。一方、請求明細の複雑性、請求ベースMRRと既存MRRの整合、既存Freee処理の除外方法は未確認であり、Sandbox確認結果により追加対応または方式変更が必要となる可能性があります。'),9.5,True); created.append(p._p)

rows=[
('高','Invoice CSVの情報不足','割引・日割り・追加課金・返金・複数商品を含む実データを抽出し、Invoice金額と再計算額を照合する。','標準条件外は例外化。例外が運用許容量を超える場合、Invoice Lines API取得を追加（8～16h）。'),
('高','請求のみでMRRを把握できるか','既存のMRR定義、ContractLineItem__c・月次明細、解約・数量変更の扱いと、対象月の請求ベース集計を比較する。','一致しない場合は契約期間・契約月次明細の投入、または既存MRRロジック改修を別途検討。'),
('高','Freee自動作成からの除外','請求管理元=Stripeの条件を、既存Flow・Apex・Batch・Scheduler・Validationが参照できるかSandboxで確認する。','既存処理の条件変更やテスト改修が必要な場合、28hの設定作業を超える可能性があるため追加見積り。'),
('高','Stripe Priceと商品マスタの一意対応','有効・無効Price、同一商品の複数Price、旧Price、通貨・請求周期を含む対応表を確認する。','一意に決まらない行は投入しない。商品対応表の整備は甲の確認を前提とし、大量補正は追加作業。'),
('中','CustomerとAccountの名寄せ','Stripe Customer ID保有状況、重複Customer、既存Accountとの対応、法人名変更をサンプル確認する。','曖昧一致は自動反映せず例外化。既存データの一括名寄せ・クレンジングは対象外。'),
('中','月1回運用による状態差分の欠落','月途中の契約開始・解約・数量変更・再契約がCSVにどの状態で残るか確認する。','月末スナップショットで履歴が失われる場合、取得日固定、差分保存またはイベント/API連携を追加検討。'),
('中','決済と請求の対応関係','複数回決済、失敗後再試行、一部返金、複数ChargeがあるInvoiceを確認する。','初期は最新状態のみ保持。決済履歴や複数Charge管理が必要なら専用設計を追加。'),
('中','税・通貨・端数の不一致','税込・税抜、消費税、外貨、丸め、クーポン、Credit Noteの扱いをMRR定義と照合する。','単価×数量と請求額が一致しない行は例外化。算定ルール追加は合意後に対応。'),
('中','Salesforce既存自動化との競合','Validation Rule、重複ルール、Flow、Apex、必須項目、共有・権限がUpsertを阻害しないか確認する。','Sandboxでエラーを収集。既存自動化の広範な改修は追加見積り。'),
('中','CSV仕様・データ量の変動','Stripe出力列、文字コード、最大件数、Excel行数、Data Loader処理時間を確認する。','テンプレートは合意時点のCSV仕様を前提とする。大容量化や列変更時はテンプレート改修が必要。'),
('中','過去データのバックフィル','MRR開始月、対象期間、過去Invoice・Subscriptionの取得可否と欠損を確認する。','本見積りは月次運用開始用を基本とし、大量の過去データ移行・補正は別途見積り。'),
('低','UTCから日本時間への変換','日付のみの項目と日時項目、月跨ぎになるレコードを確認する。','変換ルールをテンプレートへ固定し、境界日のサンプルで確認。')]

t=d.add_table(rows=1,cols=4); t.style='Table Grid'; t.alignment=WD_TABLE_ALIGNMENT.CENTER; t.autofit=False
widths=[700,2150,3100,3210]
headers=['優先度','懸念点','確認・判定方法','対応方針／見積への影響']
for ci,(cell,text) in enumerate(zip(t.rows[0].cells,headers)):
    cell.width=Pt(widths[ci]/20); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
    pr=cell._tc.get_or_add_tcPr(); w=pr.find(qn('w:tcW')); w.set(qn('w:w'),str(widths[ci])); w.set(qn('w:type'),'dxa')
    sh=OxmlElement('w:shd'); sh.set(qn('w:fill'),'E7E6E6'); pr.append(sh)
    cell.paragraphs[0].paragraph_format.space_after=Pt(0); set_font(cell.paragraphs[0].add_run(text),7.5,True)
hdr=OxmlElement('w:tblHeader'); hdr.set(qn('w:val'),'true'); t.rows[0]._tr.get_or_add_trPr().append(hdr)
grid=t._tbl.tblGrid
for c in list(grid): grid.remove(c)
for width in widths:
    c=OxmlElement('w:gridCol'); c.set(qn('w:w'),str(width)); grid.append(c)
tw=t._tbl.tblPr.find(qn('w:tblW')); tw.set(qn('w:w'),str(sum(widths))); tw.set(qn('w:type'),'dxa')
for data in rows:
    cells=t.add_row().cells
    cant=OxmlElement('w:cantSplit'); t.rows[-1]._tr.get_or_add_trPr().append(cant)
    for ci,(cell,text) in enumerate(zip(cells,data)):
        cell.width=Pt(widths[ci]/20); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER
        pr=cell._tc.get_or_add_tcPr(); w=pr.find(qn('w:tcW')); w.set(qn('w:w'),str(widths[ci])); w.set(qn('w:type'),'dxa')
        mar=OxmlElement('w:tcMar')
        for side,val in [('top',75),('start',85),('bottom',75),('end',85)]:
            z=OxmlElement('w:'+side); z.set(qn('w:w'),str(val)); z.set(qn('w:type'),'dxa'); mar.append(z)
        pr.append(mar); cell.paragraphs[0].paragraph_format.space_after=Pt(0); cell.paragraphs[0].paragraph_format.line_spacing=1.0
        set_font(cell.paragraphs[0].add_run(text),7.3,ci==0 and text=='高')
created.append(t._tbl)

note=d.add_paragraph(); note.paragraph_format.space_before=Pt(5); note.paragraph_format.space_after=Pt(3)
set_font(note.add_run('着手判定：'),9.5,True); set_font(note.add_run('上記「高」の3項目は、実データサンプルとSandboxの既存処理を確認したうえで方式を確定します。確認の結果、当初方式で目的達成できない場合は、実装前に代替案、追加工数、費用および納期を提示し、甲の承認後に対応します。'),9.5)
created.append(note._p)

for el in created:
    issuer._p.addprevious(el)
d.save(PATH)
print(PATH.resolve())
