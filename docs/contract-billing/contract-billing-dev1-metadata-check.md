# dev1 メタデータ再点検結果

更新日: 2026-05-24

## 1. 点検対象

契約請求・Freee連携で使用する主要メタデータを点検対象とする。

- オブジェクト、項目
- ページレイアウト
- タブ、アプリケーション
- 権限セット
- リストビュー
- レポートタイプ
- レポート
- ダッシュボード
- Apexクラス、テストクラス
- バッチスケジュール

## 2. ローカル資産の確認結果

| 区分 | 確認結果 |
| --- | --- |
| オブジェクト・項目 | 契約期間、商品マスタ、請求、請求明細、契約月次明細、Freee連携ログの主要項目あり |
| ページレイアウト | 契約、契約期間、契約月次明細、請求、請求明細、商品マスタ、見積、見積明細のレイアウトあり |
| タブ・アプリ | 契約期間を含む主要タブあり。SAMURAIアプリに契約期間タブ追加済み |
| 権限セット | 営業、経理、システム管理者向け権限セットあり |
| リストビュー | 年契約更新確認、送付待ち、決済待ち、Freee未連携、Freee連携失敗、取消済みなどあり |
| レポートタイプ | 契約、契約期間、契約月次明細、請求系のカスタムレポートタイプあり |
| レポート | 月別売上予定、入金予定、未請求、決済待ち、MRR、ARR、契約更新予定、解約予定などあり |
| ダッシュボード | 契約請求ダッシュボードあり |
| Apex | 初回作成、更新請求、Freee請求作成、入金同期、取消、再作成、ログ管理あり |
| テスト | 主要テストクラスあり。年契約・初期費用の追加テストを追加 |

## 3. dev1反映済みの確認済み事項

| 区分 | 状態 |
| --- | --- |
| 英語ラベル日本語化 | dev1デプロイ成功 |
| 契約期間タブ追加 | dev1デプロイ済み |
| レポート/ダッシュボード | dev1デプロイ済み |
| サンプルデータ | dev1作成済み |
| 契約更新請求バッチ | dev1スケジュール済み。ただし日次2時と毎月11日2時の2本が存在するため整理候補 |
| Freee入金ステータス同期バッチ | dev1スケジュール済み |
| 主要Apexクラス | dev1存在確認済み |
| 権限セット | dev1存在確認済み |
| SAMURAIアプリ | dev1存在確認済み |
| 主要カスタムオブジェクト | dev1存在確認済み |

## 3.1 dev1 CLI確認結果

### 主要Apexクラス

以下のApexクラスはdev1で存在確認済み。

- `ContractRenewalInvoiceBatch`
- `ContractRenewalInvoiceBatchTest`
- `FreeeInvoiceCancelService`
- `FreeeInvoiceCreateQueueable`
- `FreeeInvoiceStatusSyncBatch`
- `FreeeInvoiceStatusSyncBatchTest`
- `InvoiceCancelService`
- `InvoiceRecreateService`
- `OppContractInvoiceService`
- `OppContractInvoiceServiceTest`

### 主要カスタムオブジェクト

以下のカスタムオブジェクトはdev1で存在確認済み。

- `ContractLineItem__c`
- `ContractPeriod__c`
- `Freee_Sync_Log__c`
- `Invoice__c`
- `InvoiceLine__c`
- `ProductMaster__c`

### 権限セット

以下の権限セットはdev1で存在確認済み。

- `SAMURAI_Contract_Billing_User`
- `SAMURAI_Sales_Contract_User`
- `SAMURAI_System_Admin`

### バッチスケジュール

dev1の `CronTrigger` で確認できた契約請求関連ジョブ。

| ジョブ名 | 状態 | Cron |
| --- | --- | --- |
| `ContractRenewalInvoiceBatch` | WAITING | `0 0 2 * * ?` |
| `ContractRenewalInvoiceBatch_毎月11日2時` | WAITING | `0 0 2 11 * ?` |
| `FreeeInvoiceStatusSyncBatch` | WAITING | `0 0 3 * * ?` |
| `Contract Monthly Line Batch - Monthly 11th` | WAITING | `0 0 1 11 * ?` |

契約更新請求バッチはコード上、11日以外は対象なしで終了するため、日次2時の登録でも業務データは作成されない。ただし運用上は `ContractRenewalInvoiceBatch_毎月11日2時` に寄せ、日次2時の `ContractRenewalInvoiceBatch` は削除候補とする。

## 4. 追加で確認が必要な事項

| No | 確認事項 | 理由 | 担当 |
| --- | --- | --- | --- |
| 1 | 営業/経理ユーザーでの実ログイン確認 | 権限セットは存在するが、実ユーザー割当後の操作確認が必要 | ユーザー/Codex補助 |
| 2 | Freee実接続 | 認証・事業所ID・テンプレートID・勘定科目IDが環境依存 | ユーザー |
| 3 | 商品マスタ実データ | データ投入は未実施 | ユーザー |
| 4 | 更新時Freee自動作成 | テスト時はQueueable実行を抑止しているためUAT確認が必要 | ユーザー/Codex補助 |
| 5 | レポートの業務表示 | レポート自体はあるが、表示項目・グラフが運用に合うか確認が必要 | ユーザー |
| 6 | 契約更新請求バッチスケジュール整理 | 完了。日次2時の重複ジョブは削除し、毎月11日2時のジョブのみ残す | Codex |

## 5. 残リスク

- Freee実接続は、Named Credential、認証、事業所ID、テンプレートID、Freee勘定科目マッピングの正しさに依存する。現行の見積書・請求書連携では商品マスタのFreee品目IDは使用しない。
- Salesforce Platform PlusユーザーでLWCアクション、Apex実行、対象オブジェクト/項目参照がすべて通るかは実ユーザーで確認する。
- レポートは作成済みだが、経理/営業が実際に見たい粒度に合わせた列順・条件調整が残る可能性がある。
## 2026-05-24 スケジュール整理・リリース前チェック結果

重複していた日次 `ContractRenewalInvoiceBatch` は削除済み。dev1で現在残す契約更新請求バッチは以下。

| ジョブ名 | 状態 | Cron | 次回実行 |
| --- | --- | --- | --- |
| `ContractRenewalInvoiceBatch_毎月11日2時` | WAITING | `0 0 2 11 * ?` | 2026-06-11 02:00 JST相当 |

削除に使用したスクリプト:

- `scripts/apex/cleanup-contract-renewal-duplicate-schedule.apex`

リリース前チェックは以下で実行可能。

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-contract-billing-release-readiness.ps1 -OrgAlias dev1
```

dev1実行結果は、権限セット・主要Apex・バッチスケジュール・商品マスタ・Freee設定がすべて `OK`。
## 2026-05-24 最終メタデータ差分レビュー

確認対象:

- `manifest/package-contract-billing-release.xml`
- `force-app/main/default/classes`
- `force-app/main/default/lwc`
- `force-app/main/default/objects/ContractLineItem__c`
- `force-app/main/default/objects/InvoiceLine__c`
- `force-app/main/default/objects/QuotationLine__c`
- `force-app/main/default/permissionsets`

確認結果:

| 観点 | 結果 |
| --- | --- |
| manifestにワイルドカードが残っていない | OK |
| manifestに `Product2` / `Product2__c` が含まれていない | OK |
| Apex/LWCに `Product2` / `Product2__c` 参照がない | OK |
| 見積明細、請求明細、契約月次明細の商品参照が `ProductMaster__c` に寄っている | OK |
| `SAMURAI_System_Admin` 権限セットXMLがパース可能 | OK |
| dev1 manifest dry-run | Succeeded |

dev1 dry-run:

| 実行日 | コマンド概要 | 結果 | Deploy ID |
| --- | --- | --- | --- |
| 2026-05-24 | `sf project deploy start --target-org dev1 --manifest manifest/package-contract-billing-release.xml --dry-run --test-level NoTestRun --wait 10` | Succeeded | `0AfIe0000019l87KAA` |

自動チェックスクリプト結果:

| 実行日 | コマンド概要 | 結果 |
| --- | --- | --- |
| 2026-05-24 | `powershell -ExecutionPolicy Bypass -File scripts/check-contract-billing-release-readiness.ps1 -OrgAlias dev1` | OK。権限セット、主要Apex、バッチスケジュール、ProductMaster__c、Freee_Configs__cを確認 |

補足:

- ローカルには過去に取得した標準 `Product2` フォルダが残っているが、今回のリリースmanifestには含めていない。
- `ContractLineItem__c.Product2__c`、`InvoiceLine__c.Product2__c`、`QuotationLine__c.Product2__c` のローカルメタデータは削除し、今回の設計では `ProductMaster__c` を使用する。
