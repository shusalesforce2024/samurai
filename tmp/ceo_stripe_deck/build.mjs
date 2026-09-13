import fs from 'node:fs/promises';
import { Presentation, PresentationFile } from '@oai/artifact-tool';

const OUT = 'docs/presentations/Stripe_Salesforce_CEO説明資料.pptx';
const TMP = 'tmp/ceo_stripe_deck';
const W=1280,H=720;
const C={ink:'#111111',muted:'#62666D',panel:'#EDEDED',rule:'#B8BCC4',accent:'#6DCBF4',strong:'#3D8DFF',pale:'#EAF5FB',white:'#FFFFFF',warn:'#F5C451',risk:'#D95C5C'};
const FONT='Arial';

function box(slide,name,x,y,w,h,fill=C.panel,line='none',radius=false){
  return slide.shapes.add({geometry:radius?'roundRect':'rect',name,position:{left:x,top:y,width:w,height:h},fill,line:{style:'solid',fill:line,width:line==='none'?0:1},borderRadius:radius?'rounded-xl':undefined});
}
function text(slide,name,txt,x,y,w,h,size=24,bold=false,color=C.ink,align='left',valign='top'){
  const s=slide.shapes.add({geometry:'textbox',name,position:{left:x,top:y,width:w,height:h},fill:'none',line:{style:'solid',fill:'none',width:0}});
  s.text=txt; s.text.style={fontSize:size,bold,color,typeface:FONT,alignment:align,verticalAlignment:valign,autoFit:'shrinkText',wrap:'square'}; return s;
}
function title(slide,txt,n){ text(slide,'title',txt,54,35,1160,84,38,true); text(slide,'page',String(n).padStart(2,'0'),1190,668,42,20,13,false,C.muted,'right','bottom'); }
function notes(slide,body){ slide.speakerNotes.textFrame.setText(`${body}\n\n[Sources]\n- ${process.cwd()}\\docs\\contracts\\Stripe_CSV_Salesforce投入_見積書_ドラフト.docx\n- ${process.cwd()}\\docs\\contracts\\Stripe_CSV_Salesforce投入_業務委託契約書_ドラフト.docx`); }
function bullet(slide,txt,x,y,w,size=21,color=C.ink){ text(slide,'bullet-'+y,'•  '+txt,x,y,w,45,size,false,color); }

const p=Presentation.create({slideSize:{width:W,height:H}});

// 1 Cover
{
 const s=p.slides.add(); s.background.fill=C.white;
 box(s,'accent-field',824,0,456,720,C.pale,'none',false);
 box(s,'accent-bar',824,0,20,720,C.strong,'none',false);
 text(s,'kicker','CEOご説明資料',58,62,460,40,20,true,C.strong);
 text(s,'cover-title','Stripe請求データを\nSalesforceでMRR管理へ',58,155,700,180,54,true);
 text(s,'subtitle','月1回のCSV運用から始め、必要性を確認して自動化する段階導入',58,370,680,100,26,false,C.muted);
 text(s,'client','株式会社SAMURAI ARCHITECTS',58,600,550,35,18,true);
 text(s,'date','2026年8月24日',58,642,300,28,16,false,C.muted);
 text(s,'hero-number','154,000円',872,220,330,90,48,true,C.ink,'center','middle');
 text(s,'hero-label','税込・想定28時間',872,312,330,42,22,false,C.muted,'center');
 text(s,'hero-period','8/24 → 9/30',872,430,330,60,32,true,C.strong,'center');
 text(s,'hero-label2','検証を含む導入期間',872,494,330,38,20,false,C.muted,'center');
 notes(s,'本資料の目的は、初期投資を抑えて商品別・月別MRRを把握する導入案について、経営判断をいただくことです。');
}

// 2 Decision / outcome
{
 const s=p.slides.add(); s.background.fill=C.white; title(s,'結論：まず月1回のCSV運用で、MRR把握を実現します',2);
 text(s,'lead','常時API連携を先に作らず、実データで必要性を確認してから拡張します。',58,130,1120,62,26,false,C.muted);
 const xs=[58,455,852]; const heads=['早く始める','安全に取り込む','必要な分だけ拡張'];
 const bodies=['8/24～9/30\n約5週間で整備・検証','Stripe IDでUpsert\n重複と誤更新を防止','例外が多い場合のみ\nAPI／Webhookを追加'];
 for(let i=0;i<3;i++){box(s,'pillar-'+i,xs[i],240,340,300,i===1?C.pale:C.panel,'none',true); text(s,'num-'+i,`0${i+1}`,xs[i]+24,262,75,46,24,true,C.strong); text(s,'head-'+i,heads[i],xs[i]+24,330,285,48,28,true); text(s,'body-'+i,bodies[i],xs[i]+24,395,285,100,22,false,C.ink);}
 box(s,'outcome',58,580,1134,66,C.ink,'none',false); text(s,'outcome-text','到達点：Stripeと請求情報を合わせた「商品別・月別MRR」をSalesforceで確認できる',84,592,1080,42,24,true,C.white,'center','middle');
 notes(s,'提案の中核は段階導入です。初期は月1回の手動運用で、重複防止と照合を優先します。');
}

// 3 Process flow
{
 const s=p.slides.add(); s.background.fill=C.white; title(s,'運用は4ステップ。Salesforceを経営管理の起点にします',3);
 text(s,'lead','Stripeは決済状態、Salesforceは契約・請求・MRRを管理します。',58,126,980,48,25,false,C.muted);
 const items=[['1','Stripe CSV出力','顧客・契約・請求・決済'],['2','Excel変換・検証','商品・金額・例外を確認'],['3','Data Loader Upsert','外部IDで重複を防止'],['4','Salesforce照合','件数・金額・MRRを確認']];
 for(let i=0;i<4;i++){
   const x=58+i*292; if(i<3) box(s,'connector-'+i,x+254,326,48,6,C.rule,'none',false);
   box(s,'step-'+i,x,230,250,245,i===3?C.pale:C.panel,'none',true);
   text(s,'stepnum-'+i,items[i][0],x+20,248,52,52,26,true,C.white,'center','middle'); box(s,'stepbadge-'+i,x+20,248,52,52,C.strong,'none',true); text(s,'stepnumtop-'+i,items[i][0],x+20,248,52,52,26,true,C.white,'center','middle');
   text(s,'steph-'+i,items[i][1],x+20,325,208,62,25,true); text(s,'stepb-'+i,items[i][2],x+20,395,208,56,18,false,C.muted);
 }
 text(s,'scope-label','初期対象外',58,540,180,34,18,true,C.muted);
 text(s,'scope','常時API連携 ／ Webhook ／ 決済履歴専用オブジェクト ／ Contact・Opportunityの自動作成',58,580,1120,56,21,false,C.ink);
 notes(s,'毎月同じ手順でCSVを取り込み、成功・エラーCSVを保存します。曖昧な名寄せや金額不一致は自動反映しません。');
}

// 4 Investment and scope
{
 const s=p.slides.add(); s.background.fill=C.white; title(s,'投資は154,000円。28時間で設定・運用・検証まで含みます',4);
 text(s,'lead','追加開発は、実データで必要性が確認された場合のみ別途判断します。',58,126,1080,48,25,false,C.muted);
 const metrics=[['154,000円','税込総額'],['28時間','想定工数'],['約5週間','8/24～9/30']];
 for(let i=0;i<3;i++){const x=58+i*397; box(s,'m-'+i,x,210,350,150,i===0?C.pale:C.panel,'none',true);text(s,'mv-'+i,metrics[i][0],x+18,235,314,60,38,true,i===0?C.strong:C.ink,'center','middle');text(s,'ml-'+i,metrics[i][1],x+18,304,314,32,18,false,C.muted,'center');}
 const work=[['Salesforce設定','6h'],['Excelテンプレート','8h'],['Data Loader・手順書','6h'],['Sandbox試験・照合','8h']];
 for(let i=0;i<4;i++){const y=410+i*50; text(s,'work-'+i,work[i][0],72,y,430,34,20,i===3); box(s,'barbg-'+i,520,y+6,560,20,C.panel,'none',false); box(s,'bar-'+i,520,y+6,work[i][1]==='8h'?560:420,20,i===3?C.strong:C.accent,'none',false); text(s,'hour-'+i,work[i][1],1100,y,70,32,20,true,C.ink,'right');}
 text(s,'add','条件付き追加：Invoice Lines API取得 8～16時間',72,628,760,32,18,true,C.muted);
 notes(s,'費用内訳は設定6時間、Excel8時間、Data Loader・手順書6時間、Sandbox試験8時間です。');
}

// 5 Risks and ask
{
 const s=p.slides.add(); s.background.fill=C.white; title(s,'承認前に確認するのは3点。問題があれば実装前に止めます',5);
 text(s,'lead','高リスク項目はSandboxで確認し、方式変更・追加費用は事前承認制とします。',58,126,1120,48,25,false,C.muted);
 const risks=[['複雑な請求明細','割引・日割り・返金等がCSVで再現できるか','例外が多い場合のみAPI追加'],['請求だけでMRR管理','既存MRRと対象月の集計が一致するか','不一致なら月次明細を追加'],['既存Freee処理の除外','Stripe契約を既存自動化から除外できるか','改修が必要なら別途見積り']];
 for(let i=0;i<3;i++){const y=205+i*116; box(s,'risk-'+i,58,y,1134,92,i===0?C.pale:C.panel,'none',true); text(s,'riskno-'+i,`0${i+1}`,78,y+20,56,45,23,true,C.strong); text(s,'riskh-'+i,risks[i][0],150,y+14,280,34,23,true); text(s,'riskq-'+i,risks[i][1],450,y+14,430,58,18,false,C.ink); text(s,'riska-'+i,risks[i][2],900,y+14,265,58,18,true,C.ink);}
 box(s,'askbar',58,584,1134,76,C.ink,'none',false); text(s,'ask','ご承認事項：154,000円（税込）・8/24～9/30で、検証付きの初期導入に着手',78,597,1094,48,25,true,C.white,'center','middle');
 notes(s,'経営判断としては初期導入への着手承認をお願いします。高リスク3点は実装前に確認し、追加費用が発生する場合は事前に提示します。');
}

await fs.mkdir(TMP,{recursive:true});
for(const [i,s] of p.slides.items.entries()){
  const png=await p.export({slide:s,format:'png',scale:1}); await fs.writeFile(`${TMP}/slide-${i+1}.png`,new Uint8Array(await png.arrayBuffer()));
  const lay=await s.export({format:'layout'}); await fs.writeFile(`${TMP}/slide-${i+1}.layout.json`,await lay.text());
}
const montage=await p.export({format:'webp',montage:true,scale:1}); await fs.writeFile(`${TMP}/montage.webp`,new Uint8Array(await montage.arrayBuffer()));
const pptx=await PresentationFile.exportPptx(p); await pptx.save(OUT);
console.log(OUT);
