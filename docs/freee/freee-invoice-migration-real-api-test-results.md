# freee請求移行 実API取得テスト結果

更新日: 2026-06-21
対象環境: dev1

## 結論

freee APIから実際に請求書データを取得できることを確認済み。

請求書一覧APIだけでは請求明細が返らないため、一覧で取得したfreee請求書IDをもとに請求書詳細APIを追加で呼び出し、Salesforceの移行Workオブジェクトへ請求・請求明細を作成する方式に修正した。

## 実施結果サマリ

| No | 確認内容 | 結果 | 備考 |
| --- | --- | --- | --- |
| 1 | freee請求書一覧APIの疎通 | Pass | HTTP 200、請求書12件取得 |
| 2 | freee請求書詳細APIの取得 | Pass | 一覧で取得したfreee請求書IDごとに詳細取得 |
| 3 | `Mig_FreeeInvoiceWork__c` 作成 | Pass | 12件作成 |
| 4 | `Mig_FreeeInvoiceLineWork__c` 作成 | Pass | 13件作成 |
| 5 | 請求明細金額の取得 | Pass | `amount_excluding_tax`、`unit_price`、`quantity`、`tax_rate` を取得 |
| 6 | 税額計算 | Pass | freee明細に税額がない場合、税抜金額 x 税率で算出 |
| 7 | 複数明細請求の合算検証 | Pass | 金額不一致の誤判定が解消済み |
| 8 | Apexテスト | Pass | `Mig_FreeeInvoiceMigrationTest` 100% Pass |

## 実行コマンド

```powershell
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-fetch-smoke-test.apex
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-cleanup-work.apex
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-fetch.apex
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-validate-all.apex
sf apex run test --target-org dev1 --tests Mig_FreeeInvoiceMigrationTest --result-format human --wait 20
```

## 取得結果

| 対象 | 件数 |
| --- | ---: |
| freee請求書一覧API取得件数 | 12 |
| `Mig_FreeeInvoiceWork__c` | 12 |
| `Mig_FreeeInvoiceLineWork__c` | 13 |

代表サンプル:

| freee請求書ID | 請求金額 | 検証結果 |
| --- | ---: | --- |
| `59458020` | 132,000 | 金額合算OK。契約・契約期間・商品マスタ確定待ち |

## 商品マスタ解決状況

| 商品解決ステータス | 件数 |
| --- | ---: |
| 確定済み | 1 |
| 候補あり | 3 |
| 要確認 | 9 |

## 現在のWorkステータス

| ステータス | 件数 | 意味 |
| --- | ---: | --- |
| 要確認 | 12 | API取得は成功。Salesforce側の契約・契約期間・商品マスタ確定が未完了 |

## 修正した主な内容

| ファイル | 内容 |
| --- | --- |
| `force-app/main/default/classes/Mig_FreeeInvoiceFetchBatch.cls` | 請求書一覧取得後、請求書詳細APIを呼び出すよう修正 |
| `force-app/main/default/classes/Mig_FreeeInvoiceWorkService.cls` | freee請求書ID抽出、明細金額・税額マッピングを修正 |
| `force-app/main/default/classes/Mig_FreeeInvoiceValidator.cls` | 複数明細時に全明細を合算して検証するよう修正 |
| `force-app/main/default/classes/Mig_FreeeInvoiceMigrationTest.cls` | 一覧APIと詳細APIのレスポンス差異をテストで再現 |
| `force-app/main/default/permissionsets/Mig_FreeeInvoiceMigrationAdmin.permissionset-meta.xml` | 移行Work項目の参照権限を追加 |

## 判定

freeeからSalesforce移行Workへの実データ取得は成功。

最新のApexテスト結果:

| テストクラス | 結果 | Test Run Id |
| --- | --- | --- |
| `Mig_FreeeInvoiceMigrationTest` | 100% Pass | `707Ie00001Jsq0e` |

本番移行前に必要な残作業は以下。

| 残作業 | 担当 | 備考 |
| --- | --- | --- |
| 請求Workに契約管理を紐づける | 移行担当 | `ResolvedContract__c` |
| 請求Workに契約期間を紐づける | 移行担当 | `ResolvedContractPeriod__c` |
| 請求明細Workに商品マスタを確定する | 移行担当 | `ConfirmedProductMaster__c` |
| 検証済みWorkから本番請求・請求明細を作成する | 移行担当 / Codex | `Mig_FreeeInvoiceFinalizeService` を使用 |
