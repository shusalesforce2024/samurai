# 契約請求 全体品質向上 修正候補一覧

作成日: 2026-06-23

## 結論

現時点のdev1実装は主要テストが通っているが、本番運用品質を上げるには以下の修正が必要。

最優先は以下の3点。

1. 本番リリース用マニフェストに、直近追加したfreee請求取込・契約月次明細先行作成の資産を追加する。
2. 旧設計の `ContractRenewalInvoiceBatch` を前提にしたスケジュール手順・チェックを廃止し、現行設計の3バッチ前提に修正する。
3. 請求移行Workだけでなく、日次のfreee入金ステータス同期でも入金額・未入金額の算出ルールを統一する。

## 実施結果

2026-06-23時点で、以下は対応済み。

| 対応 | 結果 |
|---|---|
| 日次のfreee入金ステータス同期の入金額・未入金額算出ルール統一 | 対応済み。`FreeeInvoiceStatusSyncService` で決済ステータスと請求金額から算出 |
| `FreeeInvoiceStatusSyncBatch` の取得項目追加 | 対応済み。`InvoiceAmount__c` をSELECTへ追加 |
| 既存データ補正用バックフィルスクリプト | 作成済み。`scripts/apex/backfill-freee-invoice-amounts.apex` |
| 本番リリース用マニフェスト不足 | 対応済み。freee請求取込、手動取込、Work一括反映、契約月次明細先行作成の資産を追加 |
| 旧スケジュールスクリプト | 対応済み。現行3バッチ登録、`ContractRenewalInvoiceBatch` 登録解除に変更 |
| リリース準備チェック | 対応済み。現行3バッチ必須、`ContractRenewalInvoiceBatch` 未登録をOKに変更 |

dev1検証結果:

| 検証 | 結果 |
|---|---|
| `FreeeInvoiceStatusSyncBatchTest` | 9/9 Pass |
| 契約月次明細、freee請求取込、Work一括反映、請求移行、入金同期の主要回帰 | 38/38 Pass |
| `scripts/check-contract-billing-release-readiness.ps1 -OrgAlias dev1` | OK |
| マニフェスト不足候補の再照合 | 全件追加済み |

## 修正候補

| 優先度 | 区分 | 修正すべき点 | 影響 | 対応方針 |
|---|---|---|---|---|
| P0 | リリース | `manifest/package-contract-billing-release.xml` に新規資産が不足している | 本番にfreee請求取込、手動取込画面、Work一括反映、契約月次明細先行作成がリリースされない | ApexClass、ApexPage、WebLink、ListView、必要に応じて権限セットを追加 |
| P0 | スケジュール | 本番の契約請求関連CronTriggerが0件 | 夜間自動処理が動かず、契約月次明細作成・freee請求取込・入金同期が止まる | 本番用スケジュール登録スクリプトを現行設計で作る |
| P0 | 運用設計 | `scripts/check-contract-billing-release-readiness.ps1` が `ContractRenewalInvoiceBatch` の登録を必須扱いしている | 現行設計と逆のチェックになり、正しい状態をNGにする | `ContractMonthlyLineBatch`、`FreeeInvoiceImportScheduler`、`FreeeInvoiceStatusSyncBatch` 必須、`ContractRenewalInvoiceBatch` 未登録をOKに変更 |
| P0 | 運用設計 | `scripts/schedule_contract_billing_batches.apex` と `scripts/apex/schedule-contract-billing-batches.apex` が旧更新請求バッチを登録する | 誤実行するとSalesforce側で更新請求が作られ、freee自動作成と二重請求になる | 旧スクリプトを廃止または現行3バッチ登録スクリプトに置換 |
| P1 | Apex | `FreeeInvoiceStatusSyncService` の入金額・未入金額算出が請求移行Workと不統一 | 移行Workでは「決済済み=請求金額」だが、日次同期ではfreeeの `paid_amount` 等が空だと空のままになる | 請求移行Workと同じ算出ルールに統一。`FreeeInvoiceStatusSyncBatch` のSELECTに `InvoiceAmount__c` を追加 |
| P1 | データ補正 | 既に取込済みの `Mig_FreeeInvoiceWork__c` / `Invoice__c` は新ルールで再計算されない | 過去取込済みデータの税額・入金額・未入金額が空または古い値のまま残る | 既存Work/請求を対象にした一回限りのバックフィルApexを作成し、実行前後件数を記録 |
| P1 | リリース安全性 | `ContractRenewalInvoiceBatch` がクラス・テスト・権限・マニフェストに残っている | 使わない旧更新請求バッチを誤ってスケジュール登録できる | コードを残すなら「通常運用では使用禁止」と明記し、マニフェスト・スケジュール手順からは外す |
| P1 | UAT | freee実レスポンスの税額フィールド名が十分に確認されていない | `total_vat` 等で取れないレスポンスがあると税額が明細補完頼みになる | 実APIレスポンスの代表サンプルを保存し、ヘッダ税額・明細税額の項目名を確認 |
| P2 | ドキュメント | `docs/contract-billing-dev1-metadata-check.md` に旧バッチ登録前提の記載が残っている | 後続作業者が古い状態を正と誤解する | 現行設計に合わせて「旧情報」として整理、または最新化 |
| P2 | テスト | 本番スケジュール登録後の自動実行確認テストが手順化されていない | バッチ登録後に翌朝何を見ればよいか曖昧になる | post-releaseチェックリストへSOQL、期待件数、NG時対応を追加 |
| P2 | 権限 | 新規ApexPage/WebLink/ListViewが権限セット・アプリ表示に含まれているか再点検が必要 | 経理が手動取込・一括反映を使えない可能性 | 権限セットとアプリナビゲーションの差分確認を実施 |

## マニフェスト不足候補

`manifest/package-contract-billing-release.xml` で未検出だった主な資産。

### ApexClass

- `ContractMonthlyLineBatch`
- `ContractMonthlyLineBatchTest`
- `FreeeInvoiceImportService`
- `FreeeInvoiceImportServiceTest`
- `FreeeInvoiceImportScheduler`
- `FreeeInvoiceImportManualController`
- `FreeeInvoiceWorkBulkActionController`
- `FreeeInvoiceWorkBulkActionControllerTest`

### ApexPage

- `FreeeInvoiceImportManual`
- `FreeeInvoiceWorkBulkFinalize`
- `FreeeInvoiceWorkBulkValidate`

### ListView

- `Mig_FreeeInvoiceWork__c.ReadyToImport`
- `Mig_FreeeInvoiceWork__c.NeedsReview`
- `Mig_FreeeInvoiceWork__c.ImportedWorks`
- `Mig_FreeeInvoiceWork__c.ErrorWorks`

### WebLink

- `Mig_FreeeInvoiceWork__c.FreeeInvoiceWorkBulkFinalize`
- `Mig_FreeeInvoiceWork__c.FreeeInvoiceWorkBulkValidate`

## 本番スケジュールの正しい期待状態

| バッチ | 期待状態 | 推奨スケジュール |
|---|---|---|
| `ContractMonthlyLineBatch` | 登録する | 毎月11日 1:30 |
| `FreeeInvoiceImportScheduler` | 登録する | 毎日 2:30 |
| `FreeeInvoiceStatusSyncBatch` | 登録する | 毎日 3:00 |
| `ContractRenewalInvoiceBatch` | 登録しない | - |

## 推奨修正順

1. `FreeeInvoiceStatusSyncService` の入金額・未入金額算出を請求移行Workと統一する。
2. 既存取込済みWork/請求のバックフィル方針とスクリプトを作る。
3. 本番リリース用マニフェストを最新化する。
4. 旧スケジュール登録スクリプトとリリースチェックを現行設計に直す。
5. dev1で対象テスト、dry-run、スケジュール確認を実施する。
6. 本番リリース後に3バッチを登録し、翌朝の実行結果を確認する。

## 追加実施結果（2026-06-23）

### 最優先リスクへの対応

本番運用前の横断チェックで、契約月次明細作成バッチが1件の不備契約によって全体停止する可能性を確認した。MRR/ARR・将来売上レポートの基礎データ作成に影響するため、請求関連に閉じない最優先リスクとして改修した。

対応内容:

- `ContractMonthlyLineBatch` で、請求または既存契約月次明細がない契約はスキップするように変更した。
- Activated時処理で、作成元情報がない契約でも契約更新自体を失敗させないようにした。
- Scheduled実行で、同一スコープ内に不備契約が含まれても、作成可能な契約は処理継続するようにした。
- `ContractMonthlyLineBatchTest` に、不備契約スキップと正常契約継続処理のテストを追加した。
- `scripts/apex/backfill-freee-invoice-amounts.apex` を、税額未設定時の明細税額合計補完にも対応させた。

検証結果:

- dev1 deploy: 成功。Deploy ID `0AfIe000001A3TUKA0`
- `ContractMonthlyLineBatchTest`: 11/11 Pass
- 主要回帰テスト: 39/39 Pass。Test Run Id `707Ie00001KhrAU`
- dev1 readiness check: 全項目OK
