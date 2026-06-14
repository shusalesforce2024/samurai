# 本番データ投入手順

最終更新: 2026-06-08

## 目的

本番環境へSamurai移行データを安全に投入するための手順です。

prt01で成功した投入手順をもとに、本番用CSVを `docs/SamuraiData/load/prod` 配下へ整理しています。

## フォルダ構成

| パス | 用途 |
|---|---|
| `docs/SamuraiData/load/prod/01_ProductMaster__c.insert.csv` | Data Loaderで直接Insertする商品マスタCSV |
| `docs/SamuraiData/load/prod/02_Account.insert.csv` | Data Loaderで直接Insertする取引先CSV |
| `docs/SamuraiData/load/prod/source/` | 本番ID反映前の参照名ベースCSV |
| `docs/SamuraiData/load/prod/generated/` | 本番ID反映後に作成するData Loader投入CSV |
| `docs/SamuraiData/load/prod/maps/` | 本番投入後に取得するID一覧CSV |
| `docs/SamuraiData/load/prod/results/` | Data Loaderの成功/失敗結果CSV |
| `docs/SamuraiData/load/prod/csv_manifest.csv` | 本番用CSV一覧、件数、直接投入可否の確認表 |

## 本番投入の全体設計

本番ではSalesforce IDがprt01と異なるため、prt01投入済みCSVをそのまま使わないでください。

投入前に `csv_manifest.csv` を確認し、`DirectDataLoader = Yes` のCSVだけをそのままData Loaderへ投入します。

投入順は以下です。

| 順番 | オブジェクト | CSV | 直接投入 | 投入後に必要な作業 |
|---:|---|---|---|---|
| 1 | 商品マスタ | `01_ProductMaster__c.insert.csv` | 可 | 商品マスタID一覧を `maps/prod_productmaster_after_insert.csv` に保存 |
| 2 | 取引先 | `02_Account.insert.csv` | 可 | 取引先ID一覧を `maps/prod_account_after_insert.csv` に保存 |
| 3 | 取引先責任者 | `generated/03_Contact.insert.csv` | ID反映後に可 | Contact成功結果とID一覧を保存 |
| 4 | 取引 | `generated/04_Opportunity__c.insert.csv` | ID反映後に可 | 取引ID一覧を保存 |
| 5 | 契約管理 | `generated/05_Contract__c.insert.csv` | ID反映後に可 | 契約ID一覧を保存 |
| 6 | 契約期間 | `generated/06_ContractPeriod__c.insert.csv` | ID反映後に可 | 契約期間ID一覧を保存 |
| 7 | 契約月次明細 | `generated/07_ContractLineItem__c.insert.csv` | ID反映後に可 | 最終件数と親参照未設定0件を確認 |

## 事前確認

- 本番投入はInsertで実施します。
- Insert対象に `Id` 列は含めません。
- Data Loaderの文字コードはUTF-8を使用します。
- `DMFaxConsent__c` と `TelemarketingTarget__c` は今回のContact投入CSVから除外します。
- `Freee_Item_Id__c` は必須ではないため、空欄のまま投入可能です。
- 既存データがある場合、取引先名・メール・契約名などで重複が発生する可能性があります。

## 1. 商品マスタ投入

Data Loaderで以下をInsertします。

```text
docs/SamuraiData/load/prod/01_ProductMaster__c.insert.csv
```

想定件数:

```text
35件
```

投入後、成功結果CSVを `results/` に保存し、以下の形式で商品マスタID一覧を `maps/` に保存します。

```text
maps/prod_productmaster_after_insert.csv
```

必要列:

```text
Id,Name
```

## 2. 取引先投入

Data Loaderで以下をInsertします。

```text
docs/SamuraiData/load/prod/02_Account.insert.csv
```

想定件数:

```text
7,639件
```

このCSVには、元データの取引先7,619件と、契約管理の親参照解決に必要だった追加取引先20件を含めています。

投入後、成功結果CSVを `results/` に保存し、以下の形式で取引先ID一覧を `maps/` に保存します。

```text
maps/prod_account_after_insert.csv
```

必要列:

```text
Id,Name
```

## 3. 取引先責任者CSV生成と投入

元CSV:

```text
source/03_Contact.source.csv
```

生成先:

```text
generated/03_Contact.insert.csv
```

生成ルール:

| 項目 | ルール |
|---|---|
| `AccountId` | `source.AccountName` を `maps/prod_account_after_insert.csv` の `Name` で照合し、`Id` に変換 |
| `LastName` | 空欄の場合は `Name` または `FirstName` から補完 |
| `Email` | prt01で不正だった2件は空欄化済み |
| `DMFaxConsent__c` | 投入しない |
| `TelemarketingTarget__c` | 投入しない |

投入時に重複エラーが発生し、重複を許可して投入する場合:

1. 失敗CSVを `results/` に保存する。
2. `DUPLICATES_DETECTED` とそれ以外を分ける。
3. Contact標準重複ルールを一時的に無効化する。
4. 失敗分だけ再投入する。
5. Contact標準重複ルールを必ず有効に戻す。

prt01では初回17,756件中214件が失敗し、重複ルール一時停止後の再投入で214件すべて成功しました。

## 4. 取引CSV生成と投入

元CSV:

```text
source/04_Opportunity__c.source.csv
```

生成先:

```text
generated/04_Opportunity__c.insert.csv
```

生成ルール:

| 項目 | ルール |
|---|---|
| `Account__c` | 取引先名を本番Account IDへ変換 |
| `Contact__c` | 取引先内の担当者名で本番Contact IDへ変換。曖昧な場合は空欄 |
| `ContractUpdate__c` | 初期値は `月` |
| `StageName__c` | 旧ステージを現行API値へ変換 |
| `LostReason__c` | 現行API値へ変換。未定義値は空欄 |

prt01ではContact参照の曖昧・未一致33件を空欄にして、取引483件すべて成功しました。

## 5. 契約管理CSV生成と投入

元CSV:

```text
source/05_Contract__c.source.csv
```

生成先:

```text
generated/05_Contract__c.insert.csv
```

生成ルール:

| 項目 | ルール |
|---|---|
| `Name` | 自動採番のため投入しない |
| `Account__c` | 取引先名を本番Account IDへ変換 |
| `ContractUpdate__c` | メモ欄を見て判定 |
| `AnnualBillingMonthType__c` | 年更新の場合は `利用開始前月` |
| `Status__c` | `解約カイヤク` は `解約` へ正規化 |
| `ContractName__c` | 表示用契約名として保持 |

契約更新の判定:

| 条件 | `ContractUpdate__c` |
|---|---|
| メモに `年払`、`年払い`、`年間`、`年一括`、`年額`、`一括払い`、`一括払` がある | `年` |
| メモに `半年払`、`半年払い`、`半年契約`、`半年分` がある | `月` |
| メモまたはステータスが解約 | `月` |
| 上記以外 | `月` |

重要:

契約管理投入時は、`ContractTrigger` が契約月次明細を自動作成しようとして失敗するため、投入中のみ一時停止します。

手順:

1. `ContractTrigger` を一時停止版で本番へデプロイする。
2. 契約管理CSVをInsertする。
3. `ContractTrigger` を元の実装へ戻して本番へデプロイする。

この復旧確認は必須です。

## 6. 契約期間CSV生成と投入

元CSV:

```text
source/06_ContractPeriod__c.source.csv
```

生成先:

```text
generated/06_ContractPeriod__c.insert.csv
```

生成ルール:

| 項目 | ルール |
|---|---|
| `Name` | 自動採番のため投入しない |
| `Contract__c` | 契約名 + 開始日で本番Contract IDへ変換 |
| `ContractUpdate__c` | 親契約の `ContractUpdate__c` を反映 |
| `FreeeSyncStatus__c` | 空欄の場合は `未連携` |
| `InvoiceCreationStatus__c` | 空欄の場合は `未作成` |
| `IsInitialPeriod__c` | 空欄の場合は `true` |

## 7. 契約月次明細CSV生成と投入

元CSV:

```text
source/07_ContractLineItem__c.source.csv
```

生成先:

```text
generated/07_ContractLineItem__c.insert.csv
```

生成ルール:

| 項目 | ルール |
|---|---|
| `Name` | 契約名 + `_` + `yyyy/MM` |
| `MasterContract__c` | 契約名と対象月から本番Contract IDへ変換 |
| `ContractPeriod__c` | 対象月をカバーする本番ContractPeriod IDへ変換 |
| `Account__c` | 親契約のAccountを採用 |
| `Month__c` | `yyyy/MM` 形式にゼロ埋め |
| `ContractYearMonth__c` | `yyyy/MM` 形式にゼロ埋め |
| `ProductMaster__c` | 商品名がある場合は本番ProductMaster IDへ変換 |

prt01では、複数の契約期間が同じ月をカバーする59件について、開始日が最も新しい契約期間を採用しました。

投入前に、以下が0件であることを確認してください。

```text
MasterContract__c が空欄
ContractPeriod__c が空欄
```

## 最終確認

投入完了後、以下を確認します。

| 確認対象 | 期待値 |
|---|---:|
| `ProductMaster__c` | 35件 |
| `Account` | 7,639件 + 本番既存件数 |
| `Contact` | 17,756件 + 本番既存件数 |
| `Opportunity__c` | 483件 + 本番既存件数 |
| `Contract__c` | 161件 |
| `ContractPeriod__c` | 162件 |
| `ContractLineItem__c` | 1,514件 |
| 契約月次明細の親契約未設定 | 0件 |
| 契約月次明細の契約期間未設定 | 0件 |

## 進捗管理

本番投入時は、各ステップ完了ごとに以下を更新してください。

| ステップ | 完了条件 | 進捗率 |
|---|---|---:|
| 商品マスタ投入完了 | 35件成功 | 0.1% |
| 取引先投入完了 | 7,639件成功 | 27.6% |
| 取引先責任者投入完了 | 17,756件成功 | 91.6% |
| 取引投入完了 | 483件成功 | 93.4% |
| 契約管理投入完了 | 161件成功 | 94.0% |
| 契約期間投入完了 | 162件成功 | 94.6% |
| 契約月次明細投入完了 | 1,514件成功 | 100.0% |

母数は27,750件です。

## 都度更新ルール

本番作業中にエラーや追加補正が発生した場合は、必ずこの手順書を更新します。

更新対象:

- 失敗理由
- 補正内容
- 再投入CSV名
- Job ID
- 成功件数/失敗件数
- 次回本番投入で同じエラーを避けるための注意点
