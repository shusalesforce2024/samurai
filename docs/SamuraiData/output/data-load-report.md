# Salesforceデータ投入支援レポート

作成日: 2026-06-07  
最終更新: 2026-06-08

## 前提

| 項目 | 内容 |
|---|---|
| 使用ツール | Data Loader |
| 操作種別 | Insert |
| 環境 | 本番 |
| 入力フォルダ | `docs/SamuraiData` |
| 出力フォルダ | `docs/SamuraiData/output` |

## 対象オブジェクトとCSV

| # | オブジェクト | CSV | 件数 | CSV項目数 | 備考 |
|---:|---|---|---:|---:|---|
| 1 | `Account` | `Account.insert.csv` | 7,619 | 65 | 先行投入 |
| 2 | `ProductMaster__c` | `ProductMaster__c.insert.csv` | 35 | 12 | 先行投入 |
| 3 | `Contact` | `Contact.insert.csv` | 17,756 | 67 | `Account` 投入後のID反映が必要 |
| 4 | `Opportunity__c` | `Opportunity__c.insert.csv` | 483 | 24 | `Account` / `Contact` 投入後のID反映が必要 |
| 5 | `Contract__c` | `Contract__c.insert.csv` | 161 | 28 | 関連先ID反映後に投入 |
| 6 | `ContractPeriod__c` | `ContractPeriod__c.insert.csv` | 162 | 10 | `Contract__c` 投入後のID反映が必要 |
| 7 | `ContractLineItem__c` | `ContractLineItem__c.insert.csv` | 1,514 | 22 | 関連先ID反映後に投入 |

## 今回反映した補正ルール

| 対象 | 対応 | 検証結果 |
|---|---|---|
| `Contact.DMFaxConsent__c` | `希望する` / `希望しない` は `true` / `false` に変換しない。元値を保持 | `希望する` 475件、`希望しない` 456件、空白 16,825件 |
| `Contact.TelemarketingTarget__c` | `○` / `×` は `true` / `false` に変換しない。元値を保持 | `○` 1件、`×` 65件、空白 17,690件 |
| `ContractPeriod__c.PeriodEndDate__c` | 存在しない日付を補正 | `2027-4-31` は `2027-04-30`、`2027-2-31` は `2027-02-28` に補正済み |
| メール項目 | カンマ区切り、または `|` 区切りで複数ある場合は先頭を採用。全角 `＠` は半角 `@` に補正 | `Contact.Email` の複数値・全角＠残りは0件 |
| 電話項目 | カンマ区切り、または `|` 区切りで複数ある場合は先頭を採用。10桁/11桁はハイフン付き電話番号へ補正 | `Contact` の電話系項目の複数値残りは0件 |

## まだ確認が必要なデータ

| 対象 | 件数 | 内容 | 対応方針 |
|---|---:|---|---|
| `Contact.Phone` | 121 | 数字のみだが、桁数や先頭番号が不自然で安全に自動整形できない値が残っています。例: `0088`, `090331107052`, `354688809` | 手動確認。電話番号として正しい値に直すか、投入対象外にする |
| `Contact.Email` | 4 | 先頭メール採用後もメール形式として不正な値があります。例: `narise_otaki@sangetsu`、`ko-ogasawaraiacross-m.co.jp`、`§`、`http://yamamoto-sekkei/com` | 手動確認。正しいメールに直すか空白にする |
| 参照項目 | 複数 | `Contact.AccountId`、`Opportunity__c.Account__c`、`Contract__c.Account__c` などにSalesforce IDではない値が含まれます | 先行投入結果のSalesforce IDでCSVを更新する |
| 必須項目 | 複数 | `Contact.LastName`、`Opportunity__c.Name`、`Contract__c.Name`、`ContractLineItem__c.Name` などに空白候補があります | Data Loader投入前に補完する |
| 選択リスト | 複数 | Salesforce定義値と一致しない値があります | Salesforce側の選択リスト値、またはCSV値を合わせる |

## Salesforce ID反映フロー

今回のCSVはInsert前提です。Salesforce IDが未確定の参照項目は、Data Loader投入後の成功結果CSVをもとに後続CSVへ反映します。

## 本番投入用CSV

本番投入用CSVと手順書は、以下に整理しました。

```text
docs/SamuraiData/load/prod/
```

本番投入時は、必ず以下の手順書に沿って進めます。

```text
docs/SamuraiData/load/prod/production-data-load-runbook.md
```

本番用フォルダの構成:

| パス | 用途 |
|---|---|
| `01_ProductMaster__c.insert.csv` | Data Loaderで直接Insertする商品マスタCSV |
| `02_Account.insert.csv` | Data Loaderで直接Insertする取引先CSV。契約参照解決用の追加取引先20件を含む |
| `source/` | 本番ID反映前の参照名ベースCSV |
| `generated/` | 本番投入時に、本番IDを反映して作成するData Loader投入CSV |
| `maps/` | 本番投入後に取得するID一覧CSV |
| `results/` | Data Loaderの成功/失敗結果CSV |

注意:

- prt01投入済みCSVにはprt01のSalesforce IDが含まれるため、そのまま本番へ投入しないでください。
- 本番へ直接投入できるのは、現時点では `01_ProductMaster__c.insert.csv` と `02_Account.insert.csv` です。
- `Contact` 以降は、本番で先行投入したレコードのID一覧を取得してから、`generated/` 配下にData Loader投入CSVを作成します。
- 本番作業中に追加補正が発生した場合は、`production-data-load-runbook.md` を都度更新します。

## 取引先責任者の重複許可投入手順

本番投入時に `Contact` のInsertで重複検知エラーが発生し、それでも重複を許可して投入する場合は、以下の手順で対応します。

prt01検証では、初回投入17,756件のうち214件が失敗し、内訳は `DUPLICATES_DETECTED` 212件、`INVALID_EMAIL_ADDRESS` 2件でした。重複検知ルールを一時停止し、失敗214件のみを再投入した結果、214件すべて成功し、最終Contact件数は17,756件になりました。

| 順番 | 作業 | 内容 | 注意点 |
|---:|---|---|---|
| 1 | 失敗結果CSVを取得 | Data LoaderまたはSalesforce CLIのBulk結果から失敗CSVを取得する | 失敗理由、投入項目、元データを必ず残す |
| 2 | 失敗理由を分類 | `DUPLICATES_DETECTED` と、それ以外の形式エラーを分ける | 重複以外のエラーはそのまま再投入しても失敗する |
| 3 | 再投入CSVを作成 | 失敗CSVから再投入対象だけをCSV化する | ヘッダーはSalesforce API参照名にする |
| 4 | 不正値を補正 | メール形式エラーなど、投入不可の値は空欄または正しい値へ補正する | prt01では不正メール2件を空欄にして再投入 |
| 5 | Contact重複ルールを一時停止 | `Contact.Standard_Contact_Duplicate_Rule` を一時的に無効化する | 作業前に元設定を控える。投入後に必ず戻す |
| 6 | 失敗分のみInsert | 再投入CSVをData LoaderでInsertする | 全件再投入ではなく、失敗分だけ投入する |
| 7 | 件数確認 | Contact総件数、成功件数、失敗件数を確認する | 本番では投入前後の件数を記録する |
| 8 | Contact重複ルールを戻す | `Contact.Standard_Contact_Duplicate_Rule` を有効化する | 一時停止のまま残さない |

本番実施時の判断基準:

- 重複を許可する対象は、ユーザー確認済みの失敗分のみとします。
- `DUPLICATES_DETECTED` 以外のエラーは、原因を補正してから再投入します。
- `INVALID_EMAIL_ADDRESS` は、正しいメールアドレスが分からない場合はEmailを空欄にして投入します。
- 重複ルールの無効化は一時対応とし、再投入完了後すぐに有効へ戻します。
- 再投入前CSV、失敗結果CSV、成功結果CSVは、本番作業証跡として保存します。

prt01で作成した参考ファイル:

| ファイル | 用途 |
|---|---|
| `docs/SamuraiData/load/prt01/750BS00000Dv14jYAB-failed-records.csv` | 初回Contact投入の失敗結果CSV |
| `docs/SamuraiData/load/prt01/Contact.failed.750BS00000Dv14jYAB.md` | 失敗214件の一覧 |
| `docs/SamuraiData/load/prt01/Contact.retry214.prt01.insert.csv` | 失敗214件の再投入CSV |

## prt01投入実績

実施日: 2026-06-08  
対象環境: `prt01`  
操作種別: Insert

投入進捗は、移行対象データと契約投入時に追加作成した不足取引先20件を含めて算出しています。

| 順番 | オブジェクト | 投入CSV | 投入件数 | 成功 | 失敗 | Job ID | 備考 |
|---:|---|---|---:|---:|---:|---|---|
| 1 | `ProductMaster__c` | `docs/SamuraiData/load/prt01/ProductMaster__c.prt01.insert.csv` | 35 | 35 | 0 | `750BS00000Dv0wjYAB` | 選択リスト値を正規化 |
| 2 | `Account` | `docs/SamuraiData/load/prt01/Account.prt01.insert.csv` | 7,619 | 7,619 | 0 | `750BS00000DuzhFYAR` | 既存Account 3,858件を事前削除 |
| 3 | `Contact` | `docs/SamuraiData/load/prt01/Contact.prt01.insert.csv` | 17,756 | 17,542 | 214 | `750BS00000Dv14jYAB` | 重複212件、メール形式2件が初回失敗 |
| 4 | `Contact` | `docs/SamuraiData/load/prt01/Contact.retry214.prt01.insert.csv` | 214 | 214 | 0 | `750BS00000Dv1vxYAB` | Contact重複ルールを一時停止し、投入後に復旧 |
| 5 | `Opportunity__c` | `docs/SamuraiData/load/prt01/Opportunity__c.prt01.insert.csv` | 483 | 483 | 0 | `750BS00000Dvc2gYAB` | 旧ステージを現行選択リスト値へ変換 |
| 6 | `Account` | `docs/SamuraiData/load/prt01/Account.contract-missing.prt01.insert.csv` | 20 | 20 | 0 | `750BS00000DvdjVYAR` | 契約管理の必須Account参照解決用に追加 |
| 7 | `Contract__c` | `docs/SamuraiData/load/prt01/Contract__c.prt01.retry-resolved.insert.csv` | 161 | 161 | 0 | `750BS00000Dve9JYAR` | ContractTriggerを一時停止し、投入後に復旧 |
| 8 | `ContractPeriod__c` | `docs/SamuraiData/load/prt01/ContractPeriod__c.prt01.insert.csv` | 162 | 162 | 0 | `750BS00000DveXVYAZ` | 親契約IDと契約更新区分を反映 |
| 9 | `ContractLineItem__c` | `docs/SamuraiData/load/prt01/ContractLineItem__c.prt01.insert.csv` | 1,514 | 1,514 | 0 | `750BS00000DvfADYAZ` | 対象年月を `yyyy/MM` に正規化 |

最終進捗:

| 指標 | 件数 |
|---|---:|
| 投入対象合計 | 27,750 |
| 成功投入合計 | 27,750 |
| 最終失敗件数 | 0 |
| 進捗率 | 100% |

最終件数確認:

| オブジェクト | prt01件数 | 備考 |
|---|---:|---|
| `ProductMaster__c` | 35 | 移行投入分 |
| `Account` | 7,639 | 移行7,619件 + 契約参照解決用20件 |
| `Contact` | 17,756 | 移行投入分 |
| `Opportunity__c` | 485 | 既存2件 + 移行483件 |
| `Contract__c` | 161 | 移行投入分 |
| `ContractPeriod__c` | 162 | 移行投入分 |
| `ContractLineItem__c` | 1,514 | 移行投入分 |

主な補正・判断:

- `ProductMaster__c.BillingTiming__c` は `毎月マイツキ`、`年一括ネンイッカツ`、`初回のみショカイノミ` をそれぞれ `毎月`、`年一括`、`初回のみ` へ正規化しました。
- `ProductMaster__c.ProductType__c` は `初期費用ショキヒヨウ` 系の値を `初期費用` へ正規化しました。
- `Contact` の初回失敗214件は、重複検知212件とメール形式エラー2件でした。メール形式エラー2件はEmailを空欄にして再投入しました。
- `Opportunity__c.StageName__c` は旧ステータス名から現行の選択リストAPI値へ変換しました。
- `Contract__c.ContractUpdate__c` はメモ欄を参照し、年払い系は `年`、半年払い・解約系は `月` としました。
- `Contract__c.Name` は自動採番のため投入CSVから除外し、表示用名称は `ContractName__c` に保持しました。
- `Contract__c` 投入時は、既存トリガーが契約作成時に月次明細を自動生成しようとして失敗するため、`ContractTrigger` を一時停止し、投入後に元へ戻しました。
- `ContractLineItem__c.Month__c` と `ContractYearMonth__c` は `2026/01` のように月をゼロ埋めしました。
- `ContractLineItem__c` の親契約・契約期間参照未設定は最終確認で0件です。

## 推奨投入順

| 順番 | 作業 | CSV | 投入前に必要な対応 | 投入後に取得・更新するID |
|---:|---|---|---|---|
| 0 | 既存参照先の確認 | なし | `OwnerId`、`Event__c`、`Pricebook2__c` など、今回投入しない参照先が本番に存在するか確認する | 既存レコードのSalesforce IDを控える |
| 1 | 商品マスタ投入 | `ProductMaster__c.insert.csv` | `Id` はマッピングしない。選択リスト値を確認する | `ProductMaster__c.Id` |
| 2 | 取引先投入 | `Account.insert.csv` | `Id` はマッピングしない。`OwnerId` は本番ユーザーIDへ変換するか、マッピングしない | `Account.Id` |
| 3 | 取引先責任者投入 | `Contact.insert.csv` | `AccountId` を手順2の `Account.Id` へ変換する。`Event__c` は既存イベントIDへ変換するか、マッピングしない | `Contact.Id` |
| 4 | 取引投入 | `Opportunity__c.insert.csv` | `Account__c` を `Account.Id`、`Contact__c` を `Contact.Id` へ変換する | `Opportunity__c.Id` |
| 5 | 契約管理投入 | `Contract__c.insert.csv` | `Account__c` を `Account.Id` へ変換する。`Oppotunity__c` を使う場合は `Opportunity__c.Id` へ変換する | `Contract__c.Id` |
| 6 | 契約期間投入 | `ContractPeriod__c.insert.csv` | `Contract__c` を手順5の `Contract__c.Id` へ変換する | `ContractPeriod__c.Id` |
| 7 | 契約月次明細投入 | `ContractLineItem__c.insert.csv` | `Account__c`、`Contact__c`、`MasterContract__c`、`ContractPeriod__c`、`ProductMaster__c` を各投入後のIDへ変換する | `ContractLineItem__c.Id` |

補足:

- `RelatedInvoice__c`、`QuotationLine__c`、`SourceQuotation__c` など、今回の投入順内で作成しない参照先は、原則マッピングしないか、既存Salesforce IDへ変換してから投入してください。
- 親子関係を正確に作るには、各手順のData Loader成功結果CSVを保存し、次手順のCSVへ `Id` を反映してから進めてください。
- 既存データが本番にある場合、Insertでは重複作成されます。投入前に取引先名、メール、契約名などで重複確認してください。

注意:

- Data LoaderのInsertでは、参照項目に表示名を入れても通常は解決されません。Salesforce ID、または外部ID参照形式に変換してください。
- 既存レコードが本番に存在する場合、Insertでは重複作成のリスクがあります。投入前にキー候補で重複確認してください。
- 初回Insert後に同じデータを修正する場合は、Data Loader成功結果CSVの `Id` をCSVへ反映し、以後はUpdateで対応してください。
- Insert用CSVから `Id` 列は除外済みです。Data Loaderでは `Id` をマッピングしないでください。
- `DMFaxConsent__c` と `TelemarketingTarget__c` は元値保持の指示に従っています。Salesforce側の項目型がチェックボックスの場合、`希望する/希望しない` や `○/×` は投入できないため、項目型または投入対象項目の確認が必要です。

## 出力ファイル

| ファイル | 用途 |
|---|---|
| `*.insert.csv` | Data Loader Insert用CSV |
| `mapping_report.csv` | Excel列とSalesforce項目のマッピング一覧 |
| `data_quality_issues.csv` | 品質課題一覧 |
| `csv_plan.csv` | CSV別の操作種別、件数、項目数、除外項目 |
| `summary.json` | 入力Excelの概要 |

注意: `*.upsert.csv` は旧出力ファイルです。今回の本番投入では `*.insert.csv` を使用してください。

## 投入前チェックリスト

- [ ] `Contact.Phone` の数字のみ残件121件を確認する。
- [ ] `Contact.Email` の形式不正4件を確認する。
- [ ] Data Loader成功結果CSVをもとに、参照項目のSalesforce IDを更新する。
- [ ] Insert対象が本番既存レコードと重複しないか確認する。
- [ ] Contact投入で重複を許可する場合、失敗分だけを再投入し、Contact重複ルールを投入後に必ず有効へ戻す。
- [ ] 選択リスト値がSalesforce定義値と一致しているか確認する。
- [ ] Sandboxで同じCSVを使ってテスト投入し、エラーCSVを確認する。
