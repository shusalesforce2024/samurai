# 契約請求・Freee連携 本番リリース手順書

更新日: 2026-05-24

## 目的
契約、契約期間、契約月次明細、請求、請求明細、商品マスタ、Freee連携、権限、リストビュー、レポート、ダッシュボードを本番環境へ安全にリリースする。

## リリース対象
リリース対象manifestは次を使用する。

```powershell
manifest/package-contract-billing-release.xml
```

商品マスタは標準 `Product2` ではなく、カスタムオブジェクト `ProductMaster__c` を使用する。manifest、Apex、LWC、主要権限セットに `Product2` / `Product2__c` を含めない。

## 事前確認
| No | 確認内容 | 判定 |
| --- | --- | --- |
| 1 | dev1でUATが完了している |  |
| 2 | dev1でApexテストが成功している |  |
| 3 | `manifest/package-contract-billing-release.xml` に漏れや不要物がない |  |
| 4 | Product2参照がリリース対象に残っていない |  |
| 5 | 商品マスタCSVの投入内容が確定している |  |
| 6 | Freee設定、事業所ID、テンプレートID、商品IDが確定している |  |
| 7 | 営業、経理、システム管理者の権限セット割当方針が確定している |  |
| 8 | バッチスケジュール登録方針が確定している |  |
| 9 | リリース判定表で「リリース可」または「条件付き可」になっている |  |

## dev1最終確認コマンド
```powershell
sf project deploy start --target-org dev1 --manifest manifest/package-contract-billing-release.xml --dry-run --test-level NoTestRun --wait 10
sf apex run test --target-org dev1 --test-level RunLocalTests --result-format human --wait 60
powershell -ExecutionPolicy Bypass -File scripts/check-contract-billing-release-readiness.ps1 -OrgAlias dev1
```

## 本番dry-runコマンド
本番org aliasを `<production-org>` に置き換えて実行する。

```powershell
sf project deploy start --target-org <production-org> --manifest manifest/package-contract-billing-release.xml --dry-run --test-level RunLocalTests --wait 120
```

dry-runで確認すること:

- Deploy結果が `Succeeded` であること
- Apexテストが全件Passしていること
- 不要なProduct2関連メタデータが含まれていないこと
- 権限セット、レイアウト、タブ、リストビュー、レポート、ダッシュボードがdeploy対象に含まれていること
- 失敗時はエラー内容を記録し、修正後にdry-runを再実行すること

## 本番リリースコマンド
dry-run成功後に実行する。

```powershell
sf project deploy start --target-org <production-org> --manifest manifest/package-contract-billing-release.xml --test-level RunLocalTests --wait 120
```

記録する内容:

| 項目 | 値 |
| --- | --- |
| 作業日 |  |
| 作業者 |  |
| 本番org alias |  |
| dry-run Deploy ID |  |
| 本番 Deploy ID |  |
| Apexテスト結果 |  |
| リリース判定 |  |
| 残課題 |  |

## リリース後設定
### 権限セット割当
| 利用者 | プロファイル | 権限セット |
| --- | --- | --- |
| 営業 | Salesforce Platform Plus | SAMURAI 営業 |
| 経理 | Salesforce Platform Plus | SAMURAI 経理 |
| システム管理者 | Salesforce | SAMURAI システム管理者 |

### バッチスケジュール
本番反映後、システム管理者ユーザーでスケジュール登録する。

```powershell
sf apex run --target-org <production-org> --file scripts/apex/schedule-contract-billing-batches.apex
```

確認するスケジュール:

- 契約更新請求作成: 毎月11日 2:00
- Freee入金ステータス同期: 毎日夜間

## 切り戻し方針
メタデータの切り戻しは、原則として前回安定版のgitタグまたはバックアップmanifestを使って再deployする。

緊急時の影響停止:

1. `ContractRenewalInvoiceBatch` と `FreeeInvoiceStatusSyncBatch` のスケジュールを停止する。
2. 営業・経理ユーザーからFreee連携系権限セットを一時的に外す。
3. 必要に応じて請求、請求明細、契約期間の画面アクションを非表示にする。
4. Freee側に作成済み請求書がある場合、業務承認を得て取消処理を行う。
5. データは原則削除せず、取消・無効化・メモ追記で履歴を残す。

## dev1確認結果
| 実行日 | 対象 | 結果 | ID |
| --- | --- | --- | --- |
| 2026-05-24 | manifest dry-run / NoTestRun | Succeeded | `0AfIe0000019l87KAA` |
| 2026-05-24 | 主要回帰Apexテスト | 33/33 Pass | `707Ie00001G8SoL` |
| 2026-05-24 | 追加Apexテスト | 13/13 Pass | `707Ie00001G8Rrz` |
| 2026-05-24 | RunLocalTests相当 | 71/71 Pass | `707Ie00001G8Ugh` |
