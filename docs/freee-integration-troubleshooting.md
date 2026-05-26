# Freee連携 トラブルシュート表

更新日: 2026-05-24

## 確認する主な場所
| 種別 | 確認先 |
| --- | --- |
| 連携ログ | `Freee_Sync_Log__c` |
| Freee設定 | `Freee_Configs__c`、`Freee_Config__mdt` |
| 取引先同期 | `Account.Freee_Partner_Id__c` |
| 見積連携 | `Quotation__c` のFreee ID、番号、URL、同期ステータス |
| 請求連携 | `Invoice__c` のFreee ID、番号、URL、送付ステータス、決済ステータス |
| 商品ID | `ProductMaster__c.Freee_Item_Id__c` |

## トラブル別対応
| 事象 | 主な原因 | 確認箇所 | 対応 |
| --- | --- | --- | --- |
| Freee認証エラー | Named Credential、認証期限、権限不足 | 認証設定、連携ログ | 再認証し、同じ処理を再実行する |
| Freee事業所IDエラー | company_idが未設定または本番値でない | Freee設定 | 本番Freeeの事業所IDに修正する |
| 請求書テンプレートエラー | template_idが未設定またはFreee側に存在しない | Freee設定、Freee管理画面 | Freee側テンプレートIDを確認して修正する |
| 取引先IDなし | Salesforce取引先にFreee取引先IDがない | Account | Freee取引先同期を実行してから再連携する |
| 商品ID不一致 | 商品マスタのFreee商品IDが空または誤り | ProductMaster__c | Freee商品IDを修正して再連携する |
| 請求明細がFreeeに作成されない | 請求明細の商品、数量、単価、税額が不正 | InvoiceLine__c | 請求明細を確認し、必要なら請求再作成する |
| 金額が想定と違う | 値引き率、税端数、年一括/按分商品の設定違い | 見積明細、請求明細、商品マスタ | 商品マスタと請求明細を確認する。Freee連携済みは取消・再作成を使う |
| 送付ステータスが反映されない | 夜間同期未実行、Freee側状態未変更、対象外請求 | Invoice__c、Apex Jobs | 未入金請求が同期対象になっているか確認する |
| 決済ステータスが反映されない | Freee側で決済済みになっていない、同期失敗 | Invoice__c、Freee_Sync_Log__c | Freee側状態とログを確認し、同期バッチを再実行する |
| 請求取消に失敗する | Freee側状態、権限、APIエラー | Invoice__c、Freee_Sync_Log__c | Freee側の取消可否を確認し、必要ならFreeeで手動取消後にSalesforceを更新する |
| 請求再作成できない | 元請求の取消状態不備、必須項目不足 | Invoice__c、InvoiceLine__c | 元請求を取消済みにし、請求明細の必須項目を確認する |
| Freee連携済み請求を編集できない | Validation Ruleで業務項目編集を制御 | Invoice__c、InvoiceLine__c | 正常仕様。変更が必要な場合は取消・再作成で対応する |

## エスカレーション時に残す情報
| 項目 | 内容 |
| --- | --- |
| 発生日時 |  |
| 操作ユーザー |  |
| 対象取引先 |  |
| 対象見積/請求 |  |
| Freee請求書ID |  |
| エラーメッセージ |  |
| Freee同期ログURL |  |
| 再実行可否 |  |
| 業務影響 |  |

