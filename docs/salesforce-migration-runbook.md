# Salesforce 本番リリース手順書

## 1. 前提

| 項目 | 内容 |
| --- | --- |
| 対象アプリケーション | SAMURAI |
| リポジトリ | `C:\Users\ShuKawanami(川波嵩)\OneDrive - 株式会社Dirbato\ドキュメント\Samurai\samurai` |
| リリース用 manifest | `manifest/package-samurai.xml` |
| デプロイ方式 | manifest 指定デプロイ |
| 事前検証済み環境 | `full01` |
| 事前検証結果 | dry-run 成功、Apex Test 19/19 成功 |
| 直近 dry-run Deploy ID | `0AfRB000001EqEH0A0` |

本リリースでは `package-samurai.xml` だけを使用する。`manifest/package.xml` と `manifest/package2.xml` は不要な manifest として削除済み。

## 2. 今回の主な修正点

| 区分 | 修正内容 |
| --- | --- |
| Manifest | `manifest/package-samurai.xml` を本番リリース用 manifest として整理 |
| CustomApplication | `SAMURAI` を manifest に追加 |
| 契約オブジェクト | 標準 `Contract` は対象外、カスタム `Contract__c` を対象に維持 |
| Profile | システム管理者プロファイル `Admin` を取得し、manifest に追加 |
| 標準/FSL依存 | 不要な標準オブジェクト拡張、標準項目、FSL FieldSet、未使用 CustomMetadata を削除 |
| 依存メタデータ | FlexiPage、QuickAction、CustomTab、UtilityBar、ContentAsset `Samurai` を追加 |
| Contract__c メタデータ | full01 でエラーになる不要な `xsi:nil` 行を削除 |
| Admin Profile | full01 に存在しない UserPermission を削除 |
| Apex | `ContractUpdate__c` 必須化に対応し、商談から契約へ値を引き継ぐよう修正 |
| Apex Test | full01 の必須項目、callout テスト、期待値差分に合わせて修正 |

## 3. リリース対象の注意点

| 項目 | 方針 |
| --- | --- |
| `Contract__c` | 必須。manifest に含める |
| `Contract` | 不要。manifest に含めない |
| `SAMURAI` Application | 必須。`CustomApplication` として含める |
| `Admin` Profile | 必須。`Profile` として含める |
| `SAMURAI_UtilityBar` | 必須。`FlexiPage` として含める |
| QuickAction | `Invoice__c.FreeeInvoiceAction`、`Opportunity__c.ContractInvoiceAction`、`Quotation__c.FreeeQuotationAction` を含める |
| Tabs | SAMURAI アプリで使うカスタムオブジェクトタブを含める |
| ContentAsset | `Samurai` を含める |
| Named Credential | ソースに含まれていないため、本番環境で手動設定する |

## 4. 事前確認

作業前に以下を確認する。

```powershell
cd "C:\Users\ShuKawanami(川波嵩)\OneDrive - 株式会社Dirbato\ドキュメント\Samurai\samurai"
git status --short
git log -1 --oneline
sf org display --target-org <production-org>
```

確認観点:

| 項目 | OK条件 |
| --- | --- |
| Git状態 | 本番リリース対象の変更だけが含まれている |
| 最新commit | リリース対象commitである |
| 接続先org | 本番環境の Username / Org ID / Instance URL と一致 |
| CLI接続 | Connected 状態 |
| manifest | `manifest/package-samurai.xml` が存在する |
| 不要manifest | `manifest/package.xml`、`manifest/package2.xml` が存在しない |

## 5. 事前 dry-run

本番リリース前に、必ず本番環境に対して dry-run を実行する。

```powershell
sf project deploy start --manifest manifest/package-samurai.xml --target-org <production-org> --dry-run --test-level RunLocalTests --wait 60
```

成功条件:

| 項目 | OK条件 |
| --- | --- |
| Deploy Status | `Succeeded` |
| Components | 100% 成功 |
| Component Failures | 0件 |
| Apex Tests | 全件成功 |
| Test Failures | 0件 |

参考: `full01` では以下の結果で成功済み。

| 項目 | 結果 |
| --- | --- |
| Deploy ID | `0AfRB000001EqEH0A0` |
| Components | `271/271` |
| Apex Tests | `19/19` |
| Test Failures | `0` |

## 6. 本番デプロイ

dry-run 成功後に、本番デプロイを実行する。

```powershell
sf project deploy start --manifest manifest/package-samurai.xml --target-org <production-org> --test-level RunLocalTests --wait 60
```

デプロイ完了後、結果を確認する。

```powershell
sf project deploy report --target-org <production-org> --use-most-recent
```

Deploy ID、開始時刻、終了時刻、テスト結果を作業記録に残す。

## 7. 失敗時の確認ポイント

| エラー/症状 | 主な原因 | 対応 |
| --- | --- | --- |
| 標準 `Contract` 関連エラー | 標準契約を誤って manifest に含めている | `Contract` を除外し、`Contract__c` のみ対象にする |
| `SAMURAI` アプリが表示されない | `CustomApplication` またはタブ/FlexiPage不足 | `SAMURAI`、CustomTab、`SAMURAI_UtilityBar` を確認 |
| QuickAction 参照エラー | FlexiPage/Layout が未取得の QuickAction を参照 | QuickAction 3件が manifest に含まれることを確認 |
| Profile の UserPermission エラー | 本番に存在しない権限が `Admin.profile-meta.xml` に含まれる | full01 対応済みの `Admin.profile-meta.xml` を使用 |
| `ContractUpdate__c` 必須エラー | テストデータまたは契約作成処理に必須項目が不足 | `Opportunity__c.ContractUpdate__c` と `Contract__c.ContractUpdate__c` を確認 |
| callout テスト失敗 | DML 後 callout のテスト構成不備 | `Test.startTest()` / `Test.stopTest()` の範囲を確認 |
| Named Credential エラー | 本番側の手動設定不足 | `Freee_iv`、`FreeeAPI` を作成/認証する |

## 8. 手動設定

Named Credential はメタデータに含まれていないため、本番環境で手動設定する。

| No | 設定対象 | 内容 | 確認方法 |
| ---: | --- | --- | --- |
| 1 | `Freee_iv` | freee 請求書/見積 API 用 Named Credential | `FreeeInvoiceService`、`FreeeQuotationService` の callout が成功する |
| 2 | `FreeeAPI` | freee 取引先 API 用 Named Credential | `FreeePartnerService` の callout が成功する |
| 3 | `Freee_Configs__c` | `Name='Default'` を推奨。会社ID、テンプレートID、税設定などを登録 | `FreeeConfigService.getConfig()` が取得できる |
| 4 | `Freee_Account_Item_Mappings__c` | `Key__c`、`Freee_Account_Item_Id__c`、`Is_Active__c=true` を登録 | 請求書作成時に勘定科目IDエラーが出ない |
| 5 | 権限 | 対象ユーザにオブジェクト/項目/Apex/LWC 実行権限を付与 | 対象ユーザで各アクションを実行できる |

## 9. リリース後疎通確認

| No | シナリオ | 事前条件 | 期待結果 |
| ---: | --- | --- | --- |
| 1 | Account から freee 取引先作成 | Account に `Freee_Partner_Id__c` が未設定 | freee 取引先IDが Account に保存される |
| 2 | Invoice__c から freee 請求書作成 | Account、Invoice、InvoiceLine、勘定科目マッピングが揃っている | freee 請求ID、番号、URL、同期ステータスが更新される |
| 3 | Quotation__c から freee 見積作成 | Account、Quotation、QuotationLine、見積テンプレートIDが揃っている | freee 見積ID、番号、URL、同期ステータスが更新される |
| 4 | Opportunity__c から契約/請求作成 | `StageName__c=Closed Won`、`ContractUpdate__c`、Accepted 見積、見積明細が揃っている | `Contract__c`、`Invoice__c`、`InvoiceLine__c` が作成される |
| 5 | Product2 単価同期 | Product2 に `UnitPrice__c` が設定されている | 明細の `Unit_Price__c` に単価が反映される |
| 6 | エラーログ確認 | freee API エラーを起こすテストデータを用意 | `Freee_Sync_Log__c` と同期メッセージに詳細が残る |

## 10. ロールバック方針

| ケース | 対応 |
| --- | --- |
| デプロイ失敗 | Deploy result の Component Failures / Test Failures を確認し、修正後に再実行 |
| 手動設定ミス | Named Credential、設定レコード、権限を修正 |
| freee 疎通失敗 | 認証、会社ID、テンプレートID、勘定科目ID、Named Credential URL を確認 |
| 業務影響あり | 対象 LWC アクションをレイアウトから一時撤去、必要に応じて対象ユーザ権限を外す |
| データ誤作成 | Salesforce 側の `Contract__c`、`Invoice__c`、`InvoiceLine__c` と freee 側データを業務判断で取消/削除 |

## 11. 作業記録

| 項目 | 記録 |
| --- | --- |
| 作業日 |  |
| 作業者 |  |
| 対象org |  |
| Target Org Username |  |
| Org ID |  |
| Git commit |  |
| dry-run Deploy ID |  |
| dry-run 結果 |  |
| 本番 Deploy ID |  |
| 本番 Deploy 結果 |  |
| Apex Test 結果 |  |
| 手動設定完了 |  |
| 疎通確認完了 |  |
| 残課題 |  |

## 12. 連絡テンプレート

### 作業開始

```text
Salesforce 本番リリース作業を開始します。
対象: SAMURAI
対象org: <org名>
予定時間: <開始時刻> - <終了予定時刻>
作業中は対象機能の利用を控えてください。
```

### dry-run 成功

```text
Salesforce 本番リリース dry-run が成功しました。
Deploy ID: <Deploy ID>
Components: <成功数>/<総数>
Apex Tests: <成功数>/<総数>
次に本番デプロイへ進みます。
```

### 本番デプロイ成功

```text
Salesforce 本番リリースが成功しました。
Deploy ID: <Deploy ID>
これから手動設定と疎通確認を実施します。
```

### 作業完了

```text
Salesforce 本番リリース作業が完了しました。
対象: SAMURAI
Deploy ID: <Deploy ID>
疎通確認: 完了
残課題: <なし/内容>
```
