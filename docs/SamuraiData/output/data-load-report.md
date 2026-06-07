# Salesforceデータ投入支援レポート

作成日: 2026-06-07
最終更新: 2026-06-07 16:31

## 前提

| 項目 | 内容 |
|---|---|
| 使用ツール | Data Loader |
| 操作種別 | Upsert |
| 環境 | 本番 |
| 入力フォルダ | `docs/SamuraiData` |
| 出力フォルダ | `docs/SamuraiData/output` |

## 対象オブジェクトとCSV

| 投入順案 | オブジェクト | CSV | 件数 | CSV項目数 | Upsert外部ID候補 |
|---:|---|---|---:|---:|---|
| 1 | `Account` | `Account.upsert.csv` | 7,619 | 66 | `Freee_Partner_Id__c` |
| 2 | `ProductMaster__c` | `ProductMaster__c.upsert.csv` | 35 | 13 | なし |
| 3 | `Contact` | `Contact.upsert.csv` | 17,756 | 68 | なし |
| 4 | `Opportunity__c` | `Opportunity__c.upsert.csv` | 483 | 25 | なし |
| 5 | `Contract__c` | `Contract__c.upsert.csv` | 161 | 29 | なし |
| 6 | `ContractPeriod__c` | `ContractPeriod__c.upsert.csv` | 162 | 11 | なし |
| 7 | `ContractLineItem__c` | `ContractLineItem__c.upsert.csv` | 1,514 | 23 | なし |

## 重要な判定

現時点のCSVは、電話番号・日付/日時・チェックボックス・数値の基本形式をSalesforce向けに補正済みです。ただし、本番Upsertにそのまま使うのはまだ推奨しません。

主な理由:

- `Account` 以外はUpsertに使える外部ID候補がExcel上で確認できません。
- 多くの参照項目がSalesforce IDではなく、名称や番号で入っています。
- `Contact.LastName`、`Contract__c.Name`、`Opportunity__c.Name`、`ContractLineItem__c.Name` など必須項目に空白があります。
- `Contact.Email` に複数メールアドレスや不正形式が含まれます。
- `Opportunity__c` の選択リスト値にSalesforce定義外の値があります。

## 自動補正した内容

| 対象 | 補正内容 | 件数 |
|---|---|---:|
| 電話番号 | 10桁/11桁の数字のみ電話番号を `03-1234-5678` / `090-1234-5678` 形式へ変換 | 1,804 |
| `DMFaxConsent__c` | `希望する` / `希望しない` を `true` / `false` へ変換 | 931 |
| `TelemarketingTarget__c` | `○` / `×` を `true` / `false` へ変換 | 66 |
| 日付項目 | 日時入りの日付項目を `yyyy-MM-dd` へ変換 | 243 |
| 日時項目 | 日時項目は `yyyy-MM-ddTHH:mm:ss.000Z` 形式へ変換 | 対象値をCSVへ反映 |
| 数値/通貨/パーセント | カンマ、円記号、%記号を除去し数値形式へ変換 | 対象値をCSVへ反映 |

## 形式面の残課題

| 対象 | 件数 | 内容 |
|---|---:|---|
| `Contact.Phone` | 75 | 桁数が短い/特殊な数字のみ電話番号が残っています。誤変換防止のため自動補正していません。 |
| `ContractPeriod__c.PeriodEndDate__c` | 2 | `2027-4-31`, `2027-2-31` は存在しない日付です。 |
| `Contact.Email` | 20 | 複数メールアドレスまたは不正形式です。 |

## 主な品質課題

| 種別 | 件数 | 主な対象 |
|---|---:|---|
| 選択リスト未定義値 | 61 | `Opportunity__c`, `ProductMaster__c`, `Contract__c`, `Contact` |
| 参照項目がSalesforce IDではない | 136 | `Account.OwnerId`, `Contact.AccountId`, `Opportunity__c.Account__c`, `Opportunity__c.Contact__c`, `Contract__c.Account__c`, `ContractLineItem__c.Account__c` |
| メール形式不正/複数メール | 20 | `Contact.Email` |
| 必須項目空白 | 4種類 | `Contact.LastName`, `Opportunity__c.Name`, `Contract__c.Name`, `ContractLineItem__c.Name` |
| 重複候補 | 複数 | `Name`, `Email` 等 |

詳細は `data_quality_issues.csv` を参照してください。

## Data Loader投入前に必要な対応

1. Upsertキーを確定する
   - `Account`: `Freee_Partner_Id__c` を使うか確認してください。
   - その他オブジェクト: 外部ID項目を追加する、またはInsert/Updateへ操作を分ける必要があります。

2. 参照項目をID化する
   - `Contact.AccountId` は取引先名ではなく、`Account.Id` または外部ID参照に変換してください。
   - `Opportunity__c.Account__c`, `Opportunity__c.Contact__c`, `Contract__c.Account__c`, `ContractLineItem__c.Account__c` も同様です。

3. 必須項目を補完する
   - `Contact.LastName` が空の場合は、`Name` から姓に相当する値を入れるなどのルールが必要です。
   - 契約・取引・契約月次明細の `Name` 空白も補完が必要です。

4. 選択リスト値を変換する
   - Salesforceの定義値に完全一致させてください。

5. メールアドレスを正規化する
   - 複数メールがある場合、主メール1件にするか、別項目/別レコード化するかを決めてください。

## 出力ファイル

- `mapping_report.csv`: Excel列とSalesforce項目のマッピング一覧
- `data_quality_issues.csv`: 品質課題一覧
- `csv_plan.csv`: CSV別の件数・外部ID候補・未解決列
- `*.upsert.csv`: Data Loader向け暫定CSV

## 推奨

本番投入前に、同じCSVをSandboxへ投入して検証してください。特に参照関係とUpsertキーが解決するまで、本番Data LoaderでのUpsert実行は止めた方が安全です。
