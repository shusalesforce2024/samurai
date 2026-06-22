# 契約請求 残確認ポイント テスト結果

実施日: 2026-06-23

## 結論

dev1では、契約月次明細の先行作成、freee請求取込、本反映、契約月次明細への関連請求反映、レポート参照項目の表示まで主要フローはテスト合格。

ただし、本番環境では契約請求関連のスケジュール済みバッチが0件だったため、このままでは夜間自動運用は回らない。  
本番運用開始前に、必要なバッチを本番でスケジュール登録する必要がある。

## テスト対象

| No | 確認ポイント | 確認方法 | 結果 | 判定 |
|---:|---|---|---|---|
| 1 | freee側で作成された請求をSalesforceへ取り込めること | Apexテスト、dev1実データ確認 | 取込Workが作成され、反映済みデータを確認 | 合格 |
| 2 | Work取込後、要確認を運用で判別できること | Apexテスト、dev1 Workステータス確認 | テストでは要確認維持を確認。dev1実データでは要確認0件 | 合格 |
| 3 | 契約・契約期間・契約月次明細へ紐づくこと | dev1実データSOQL確認 | 反映済みWorkに契約・契約期間・作成請求あり。契約月次明細に関連請求あり | 合格 |
| 4 | 契約月次明細レポートで送付・決済ステータスを確認できること | dev1 ContractLineItem__c確認 | 関連請求 送付ステータス、決済ステータスが表示される | 合格 |
| 5 | 年契約の12か月分契約月次明細に同じ請求が紐づくこと | Apexテスト | 期間内の契約月次明細全件へRelatedInvoice__c反映を確認 | 合格 |
| 6 | Salesforce更新請求バッチが停止していること | dev1 CronTrigger確認 | ContractRenewalInvoiceBatchの登録なし | 合格 |
| 7 | dev1で必要バッチが登録されていること | dev1 CronTrigger確認 | 3件登録済み | 合格 |
| 8 | 本番で必要バッチが登録されていること | prod CronTrigger確認 | 0件 | 不合格 |

## dev1 Apexテスト結果

実行コマンド:

```bash
sf apex run test --target-org dev1 --tests ContractMonthlyLineBatchTest --tests FreeeInvoiceImportServiceTest --tests FreeeInvoiceWorkBulkActionControllerTest --tests Mig_FreeeInvoiceMigrationTest --result-format human --wait 30
```

結果:

| 項目 | 値 |
|---|---:|
| Tests Ran | 27 |
| Pass Rate | 100% |
| Fail Rate | 0% |
| Test Run Id | 707Ie00001Khqli |

## dev1 スケジュール確認

| バッチ | 状態 | Cron | 判定 |
|---|---|---|---|
| ContractMonthlyLineBatch_毎月11日1時30分 | WAITING | `0 30 1 11 * ?` | 合格 |
| FreeeInvoiceImportScheduler_毎日2時30分 | WAITING | `0 30 2 * * ?` | 合格 |
| FreeeInvoiceStatusSyncBatch | WAITING | `0 0 3 * * ?` | 合格 |
| ContractRenewalInvoiceBatch | 登録なし | - | 合格 |

## dev1 Work状態確認

| ステータス | 件数 |
|---|---:|
| 反映済み | 2 |
| 対象外 | 10 |
| 要確認 | 0 |
| 反映可能 | 0 |

補足: 詳細確認時点では、最新データに1件の反映可能Workが存在していたが、集計確認時点では0件。画面またはバッチ処理により状態が更新された可能性があるため、UAT時は対象データを固定して確認する。

## dev1 契約月次明細確認

`ContractLineItem__c` で `RelatedInvoice__c != null` のレコードを確認。  
関連請求から以下の参照項目が表示されることを確認した。

| 項目 | 確認結果 |
|---|---|
| 関連請求 | 値あり |
| 関連請求 送付ステータス | 送付待ち |
| 関連請求 決済ステータス | 決済待ち |

これにより、契約月次明細レポート上でfreee由来の送付・決済状態を確認できる。

## 本番確認結果

| 確認内容 | 結果 | 判定 |
|---|---:|---|
| 契約請求関連CronTrigger件数 | 0 | 不合格 |
| Mig_FreeeInvoiceWork__c 反映済み | 129 | 参考 |
| Mig_FreeeInvoiceWork__c 対象外 | 1 | 参考 |
| ContractLineItem__c RelatedInvoice__cあり | 1 | 参考 |

## 本番運用開始前に必要な対応

本番で以下のバッチをスケジュール登録する。

| 必須 | バッチ | 推奨スケジュール | 目的 |
|---|---|---|---|
| 必須 | ContractMonthlyLineBatch | 毎月11日 1:30 | MRR/ARR・将来売上用の契約月次明細を先行作成 |
| 必須 | FreeeInvoiceImportScheduler | 毎日 2:30 | freeeで作成された請求書をSalesforceへ取り込む |
| 必須 | FreeeInvoiceStatusSyncBatch | 毎日 3:00 | freeeの送付・決済ステータスをSalesforce請求へ同期 |
| 停止維持 | ContractRenewalInvoiceBatch | 登録しない | Salesforce側で更新請求を作る旧バッチのため、freee自動作成・自動送付と二重請求になる |

## 追加UATで確認すべきこと

以下はSalesforce単体テストでは完全には確認できないため、freee実設定を含むUATで確認する。

| No | UAT観点 | 判定基準 |
|---:|---|---|
| 1 | freee側で初回請求書から自動作成・自動送付設定が正しく引き継がれること | 次回請求がfreeeで自動作成され、送付予定状態になる |
| 2 | freee自動作成請求にSalesforce側で契約・契約期間を特定できる情報が残ること | 取引先、請求日、対象期間、件名・備考等から一意に契約期間を解決できる |
| 3 | Workが要確認になった場合、経理が画面上で原因を判断できること | 検証メッセージ、取引先、契約、契約期間、商品候補が確認できる |
| 4 | 本番スケジュール登録後、翌朝に自動処理結果を確認できること | CronTriggerがWAITING、AsyncApexJobが成功、Work/請求/契約月次明細が想定通り更新される |

