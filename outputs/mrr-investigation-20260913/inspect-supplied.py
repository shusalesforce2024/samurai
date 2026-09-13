from pathlib import Path
import zipfile,xml.etree.ElementTree as ET,json,sys
sys.stdout.reconfigure(encoding='utf-8')
src=Path('C:/Users/ShuKawanami(川波嵩)/OneDrive - 株式会社Dirbato/ドキュメント/Samurai/Rendery      MRR-2026-09-03-19-19-25.xlsx')
p=Path(__file__).parent
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
with zipfile.ZipFile(src) as z:
    shared=[]
    if 'xl/sharedStrings.xml' in z.namelist():
        shared=[''.join(n.itertext()) for n in ET.fromstring(z.read('xl/sharedStrings.xml')).findall('s:si',ns)]
    rel={x.attrib['Id']:x.attrib['Target'] for x in ET.fromstring(z.read('xl/_rels/workbook.xml.rels'))}
    sheets=[]
    for sheet in ET.fromstring(z.read('xl/workbook.xml')).findall('s:sheets/s:sheet',ns):
        target=rel[sheet.attrib['{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id']]
        path=target.lstrip('/') if target.startswith('/') else 'xl/'+target
        xml=ET.fromstring(z.read(path)); rows=[]
        for row in xml.findall('s:sheetData/s:row',ns):
            cells=[]
            for c in row:
                v=c.find('s:v',ns); value=v.text if v is not None else None
                if c.get('t')=='s':value=shared[int(value)] if value is not None else None
                if c.get('t')=='inlineStr':value=''.join(c.find('s:is',ns).itertext())
                if value is not None:cells.append({'cell':c.get('r'),'value':value,'style':c.get('s'),'formula':c.findtext('s:f',None,ns)})
            if cells:rows.append(cells)
        links=[x.attrib for x in xml.findall('s:hyperlinks/s:hyperlink',ns)]
        entry={'name':sheet.attrib['name'],'path':path,'dimension':xml.find('s:dimension',ns).attrib if xml.find('s:dimension',ns) is not None else None,'rows':rows,'hyperlinks':links}
        sheets.append(entry)
        print(json.dumps({'name':entry['name'],'dimension':entry['dimension'],'nonempty_rows':len(rows),'first_rows':rows[:15],'last_rows':rows[-3:],'hyperlinks':links[:8]},ensure_ascii=False))
    (p/'supplied-workbook-cells.json').write_text(json.dumps(sheets,ensure_ascii=False,indent=2),encoding='utf-8')
