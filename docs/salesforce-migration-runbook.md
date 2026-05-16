# Salesforce移行手順書

## 1. 前提

| 項目 | 内容 |
| --- | --- |
| 対象リポジトリ | `S:\SamuraiPOC\samurai` |
| SFDXソースパス | `force-app/main/default` |
| APIバージョン | `sfdx-project.json` は 64.0、`manifest/package2.xml` は 65.0 |
| 主な機能 | freee取引先作成、freee請求書作成、freee見積作成、商談から契約/請求作成、見積/請求明細の単価同期、商談MRR同期、商談確度同期 |
| 想定移行方式 | 事前dry-run、メタデータデプロイ、手動設定、テスト、疎通確認 |
| 注意点 | `manifest/package2.xml` には `Freee_Config__c` / `Freee_Account_Item_Mapping__c` と記載があるが、実資産は `Freee_Configs__c` / `Freee_Account_Item_Mappings__c`。package manifestを使う場合は修正が必要。 |

## 2. 移行対象資産サマリ

| 区分 | 対象 | 数量/内容 | 備考 |
| --- | --- | --- | --- |
| Apex Class | 業務クラス | 19 | freee連携、商談/契約/請求生成、同期サービス |
| Apex Test | テストクラス | 3 | `FreeeIntegrationTest`、`TriggerSyncServicesTest`、`OppContractInvoiceServiceTest` |
| Apex Trigger | トリガー | 4 | Opportunity、Quotation、QuotationLine、InvoiceLine |
| LWC | 画面アクション | 4 | freee取引先同期、freee請求同期、freee見積同期、商談から契約/請求作成 |
| Custom Object / Standard Object拡張 | オブジェクト定義 | 16 | Account、Contact、Contract、Product2拡張、各カスタムオブジェクト |
| Custom Field | 項目 | 270 | 各オブジェクト配下の `fields` |
| Layout | ページレイアウト | 13 | Account、Contact、Contract、Opportunity、Quotation、Invoice等 |
| List View | リストビュー | 33 | 各オブジェクト配下 |
| Custom Metadata Type | `Freee_Config__mdt` | 1 type / 1 record | 現行Apexは参照していない。`Freee_Configs__c` を参照している |
| Custom Metadata | `Freee_Account_Item_Mapping.sales` | 1 record | 現行Apexは `Freee_Account_Item_Mappings__c` をSOQL参照 |
| Named Credential | `Freee_iv`、`FreeeAPI` | 手動作成が必要 | ソース内にNamed Credential定義ファイルは存在しない |

## 3. オブジェクト別資産一覧

| オブジェクト | 項目数 | リストビュー数 | レイアウト数 | 用途 |
| --- | ---: | ---: | ---: | --- |
| Account | 51 | 5 | 1 | 取引先。freee取引先ID `Freee_Partner_Id__c` を保持 |
| Contact | 44 | 6 | 1 | 取引先責任者拡張 |
| Contract | 20 | 7 | 1 | 標準契約拡張 |
| ContractLineItem__c | 10 | 1 | 0 | 契約明細 |
| Contract__c | 20 | 2 | 2 | カスタム契約。商談から作成 |
| Event__c | 2 | 0 | 1 | イベント |
| Freee_Account_Item_Mappings__c | 3 | 0 | 0 | 請求書作成時の勘定科目キーとfreee勘定科目IDの対応 |
| Freee_Configs__c | 9 | 1 | 0 | freee連携設定。Apexが参照する本命設定オブジェクト |
| Freee_Config__mdt | 8 | 0 | 0 | カスタムメタデータ版freee設定。現行Apexでは未使用 |
| Freee_Sync_Log__c | 6 | 1 | 0 | freee API連携ログ |
| InvoiceLine__c | 10 | 1 | 1 | 請求明細 |
| Invoice__c | 22 | 1 | 1 | 請求書 |
| Opportunity__c | 26 | 2 | 1 | カスタム商談 |
| Product2 | 21 | 2 | 0 | 商品。単価 `UnitPrice__c` を明細に同期 |
| QuotationLine__c | 9 | 2 | 1 | 見積明細 |
| Quotation__c | 19 | 2 | 1 | 見積 |

## 4. タイムスケジュール

| No | 時刻目安 | 作業 | 予定時間 | 担当 | 成果物/完了条件 |
| ---: | --- | --- | --- | --- | --- |
| 1 | T-5営業日 | 移行対象org、接続ユーザ、権限、メンテナンス時間を確認 | 30分 | Salesforce管理者 | 対象orgと実施時間が確定 |
| 2 | T-5営業日 | freee API認証方式、Client ID/Secret、会社ID、テンプレートID、勘定科目IDを確認 | 60分 | 業務/外部連携担当 | 設定値一覧が確定 |
| 3 | T-4営業日 | ソース整備、manifest確認、`package2.xml` のオブジェクト名不一致を修正するか、`force-app/main/default` でdeployする方針に決定 | 45分 | 開発者 | デプロイ対象が確定 |
| 4 | T-3営業日 | 移行先Sandboxへdry-run | 60分 | 開発者 | コンパイルエラーなし、テスト実行可能 |
| 5 | T-3営業日 | Apexテスト実行、カバレッジ75%以上確認 | 60分 | 開発者 | org全体/対象クラスのカバレッジ基準クリア |
| 6 | T-2営業日 | 手動設定のリハーサル。Named Credential、権限、クイックアクション配置を確認 | 90分 | Salesforce管理者 | 手動設定チェックリスト完了 |
| 7 | T-1営業日 | 移行直前バックアップ。変更セット/メタデータ取得、既存設定値控え | 60分 | Salesforce管理者 | ロールバック用控えを取得 |
| 8 | 当日 09:00 | 本番作業開始、メンテナンス周知、対象ユーザ作業停止 | 15分 | PM/管理者 | 作業開始承認 |
| 9 | 当日 09:15 | メタデータデプロイ | 45分 | 開発者 | Deploy成功 |
| 10 | 当日 10:00 | 手動設定実施 | 90分 | Salesforce管理者 | Named Credential、設定レコード、権限、画面アクション完了 |
| 11 | 当日 11:30 | Apexテスト実行、主要シナリオ疎通 | 90分 | 開発者/業務担当 | freee取引先/見積/請求/契約請求作成の正常確認 |
| 12 | 当日 13:00 | 業務ユーザ受入確認 | 60分 | 業務担当 | 画面操作、データ作成、エラー表示確認 |
| 13 | 当日 14:00 | リリース判定 | 30分 | PM/管理者 | Go/No-Go判定 |
| 14 | 当日 14:30 | 作業完了連絡、監視開始 | 30分 | PM/管理者 | 完了連絡、ログ監視開始 |
| 15 | 当日 15:00-翌営業日 | freee同期ログ、Apex例外、ユーザ問い合わせ監視 | 120分 | 運用担当 | 重大障害なし |

## 5. デプロイ順序

| 順序 | 作業 | コマンド/操作 | 予定時間 | 注意点 |
| ---: | --- | --- | --- | --- |
| 1 | org接続確認 | `sf org display --target-org <target>` | 5分 | 接続ユーザにデプロイ権限が必要 |
| 2 | 事前検証 | `sf project deploy start --source-dir force-app/main/default --target-org <target> --dry-run --test-level RunLocalTests --wait 60` | 30-60分 | `classes` のみでは依存オブジェクト不足で失敗する可能性が高い |
| 3 | 本番デプロイ | `sf project deploy start --source-dir force-app/main/default --target-org <target> --test-level RunLocalTests --wait 60` | 30-60分 | 本番はテスト実行必須 |
| 4 | 失敗時確認 | Deploy result の Component Failures / Test Failures を確認 | 15-60分 | カスタムオブジェクト名、項目名、権限不足を優先確認 |
| 5 | 成功確認 | `sf project deploy report --target-org <target> --use-most-recent` | 5分 | Deploy IDを記録 |

## 6. 手動設定手順

| No | 設定対象 | 手順 | 予定時間 | 確認方法 |
| ---: | --- | --- | --- | --- |
| 1 | Named Credential `Freee_iv` | 設定 > Named Credentials で `Freee_iv` を作成。請求/見積API用のfreee接続先URLを設定 | 20分 | Apex `FreeeInvoiceService` が `callout:Freee_iv/invoices`、`FreeeQuotationService` が `callout:Freee_iv/quotations` を使用 |
| 2 | Named Credential `FreeeAPI` | 設定 > Named Credentials で `FreeeAPI` を作成。取引先API用URLを設定 | 20分 | Apex `FreeePartnerService` が `callout:FreeeAPI/api/1/partners` を使用 |
| 3 | 認証情報 | freee APIの認証方式に合わせ、External Credential / 認証プロバイダ / OAuth設定 / 認証済みプリンシパルを設定 | 30-60分 | Named Credentialから認証テスト、またはApex疎通で確認 |
| 4 | リモートサイト設定 | Named Credentialのみで不足するorg方針の場合、freee APIドメインをRemote Site Settingsへ登録 | 10分 | calloutがUnauthorized以外の応答になること |
| 5 | `Freee_Configs__c` レコード | アプリランチャーまたはデータローダで設定レコードを1件作成。`Name=Default` 推奨 | 15分 | `FreeeConfigService.getConfig()` が1件取得できる |
| 6 | `Freee_Account_Item_Mappings__c` レコード | 請求書の `Freee_Account_Item_Picklist__c` 値ごとに、`Key__c`、`Freee_Account_Item_Id__c`、`Is_Active__c=true` を作成 | 20分 | 請求書作成時に勘定科目ID未設定エラーが出ない |
| 7 | 権限セット/プロファイル | 対象ユーザに各オブジェクト/項目/Apex/LWCの権限を付与 | 45分 | ユーザでレコード参照、更新、アクション実行が可能 |
| 8 | Lightningアクション配置 | Object Managerのページレイアウト/Lightning Record PageでLWC Record Actionを配置 | 30分 | Account、Opportunity__c、Invoice__c、Quotation__c の画面にボタン表示 |
| 9 | タブ/アプリ表示 | 必要に応じてカスタムオブジェクトタブ、アプリナビゲーションを追加 | 20分 | 業務ユーザが一覧/レコードに到達できる |
| 10 | 共有設定 | OWD、ロール、共有ルール、所有者設定を本番運用に合わせる | 30分 | 対象ユーザで必要レコードが参照可能 |
| 11 | ページレイアウト割当 | プロファイルごとに移行後レイアウトが割り当たっているか確認 | 20分 | freee項目、同期ステータス、URLが表示される |
| 12 | 既存データ補正 | 既存Accountに `Freee_Partner_Id__c`、Product2に `UnitPrice__c` 等を必要に応じて投入 | 60分以上 | 主要シナリオで入力不足エラーが出ない |

## 7. freee連携設定詳細

| 設定 | 必須 | 値/例 | 設定場所 | 使用箇所 |
| --- | --- | --- | --- | --- |
| `Freee_iv` | 必須 | freee請求書/見積APIのベースURL | Named Credential | `FreeeInvoiceService`, `FreeeQuotationService` |
| `FreeeAPI` | 必須 | freee APIベースURL | Named Credential | `FreeePartnerService` |
| `Company_Id__c` | 必須 | freee会社ID | `Freee_Configs__c` | 請求/見積/取引先作成リクエスト |
| `Template_Id__c` | 必須 | freee請求書テンプレートID | `Freee_Configs__c` | 請求書作成 |
| `Quotation_Template_Id__c` | 見積連携では必須 | freee見積テンプレートID | `Freee_Configs__c` | 見積作成 |
| `Invoice_Base_Url__c` | 必須 | `https://secure.freee.co.jp/invoices/` | `Freee_Configs__c` | freee請求/見積URL生成 |
| `Payment_Type__c` | 任意 | `transfer` または `direct_debit` | `Freee_Configs__c` または `Invoice__c` | 請求書作成 |
| `Tax_Entry_Method__c` | 必須 | freee仕様に合わせる | `Freee_Configs__c` | 請求/見積作成 |
| `Tax_Fraction__c` | 必須 | freee仕様に合わせる | `Freee_Configs__c` | 請求/見積作成 |
| `Withholding_Tax_Entry_Method__c` | 任意 | 未設定時は `out` | `Freee_Configs__c` | 請求/見積作成 |
| 勘定科目キー | 必須 | `Sales` など | `Freee_Account_Item_Mappings__c.Key__c` | 請求書mapper |
| freee勘定科目ID | 必須 | freee側のaccount_item_id | `Freee_Account_Item_Mappings__c.Freee_Account_Item_Id__c` | 請求書mapper |

## 8. 業務別疎通確認

| No | シナリオ | 事前データ | 操作 | 期待結果 | 予定時間 |
| ---: | --- | --- | --- | --- | --- |
| 1 | Accountからfreee取引先作成 | Accountに `Freee_Partner_Id__c` が未設定 | Account画面のfreee取引先同期アクション実行 | freee取引先IDがAccountへ保存 | 15分 |
| 2 | Invoice__cからfreee請求書作成 | Accountにfreee取引先ID、Invoice/InvoiceLine、勘定科目マッピング | 請求書画面のfreee請求同期アクション実行 | `Freee_Invoice_Id__c`、番号、URL、同期ステータスが更新 | 20分 |
| 3 | Quotation__cからfreee見積作成 | Accountにfreee取引先ID、Quotation/QuotationLine、見積テンプレートID | 見積画面のfreee見積同期アクション実行 | `Freee_Quotation_Id__c`、番号、URL、同期ステータスが更新 | 20分 |
| 4 | Opportunity__cから契約/請求作成 | `StageName__c=Closed Won`、Accepted見積、見積明細 | 商談画面の契約/請求作成アクション実行 | `Contract__c`、`Invoice__c`、`InvoiceLine__c` が作成 | 20分 |
| 5 | Product2単価同期 | Product2に `UnitPrice__c` | QuotationLine/InvoiceLineで商品選択 | 明細 `Unit_Price__c` に商品単価が反映 | 10分 |
| 6 | 商談MRR同期 | Opportunity__cに紐づくQuotation/QuotationLine | 見積/見積明細を作成・更新 | Opportunity__c.MRR__cが合計金額に同期 | 10分 |
| 7 | 異常系ログ確認 | freee APIエラーを発生させるテストデータ | freee連携アクション実行 | `Freee_Sync_Log__c` と同期メッセージにエラー詳細が残る | 15分 |

## 9. 権限確認表

| 権限対象 | 必要権限 | 対象ユーザ | 備考 |
| --- | --- | --- | --- |
| Account | 参照、更新 | freee取引先同期利用者 | `Freee_Partner_Id__c` 更新が必要 |
| Invoice__c | 参照、作成、更新 | 請求担当 | freee請求同期で更新 |
| InvoiceLine__c | 参照、作成、更新 | 請求担当 | 請求明細参照、単価同期 |
| Quotation__c | 参照、作成、更新 | 営業/見積担当 | freee見積同期で更新 |
| QuotationLine__c | 参照、作成、更新 | 営業/見積担当 | 見積明細参照、単価同期 |
| Opportunity__c | 参照、作成、更新 | 営業 | 確度/MRR同期、契約/請求作成 |
| Contract__c | 参照、作成 | 営業/契約担当 | 商談から作成 |
| Freee_Configs__c | 参照、作成、更新 | 管理者のみ | 一般ユーザは原則参照のみ |
| Freee_Account_Item_Mappings__c | 参照、作成、更新 | 管理者のみ | 一般ユーザは原則参照のみ |
| Freee_Sync_Log__c | 参照、作成 | 管理者/運用担当 | Apexが作成 |
| Apex Class | 実行アクセス | アクション利用者 | 各Controller/Facade/Service |

## 10. 既知の確認ポイント

| No | 確認ポイント | 理由 | 推奨対応 |
| ---: | --- | --- | --- |
| 1 | `Freee_Config__mdt` と `Freee_Configs__c` が併存 | カスタムメタデータは存在するがApexはカスタムオブジェクトを参照 | 運用設定は `Freee_Configs__c` に投入。将来統一を検討 |
| 2 | `Freee_Account_Item_Mapping.sales` と `Freee_Account_Item_Mappings__c` が併存 | カスタムメタデータとカスタムオブジェクトの名前が異なる | 現行Apexに合わせ `Freee_Account_Item_Mappings__c` レコードを作成 |
| 3 | Named Credentialのソースがない | `callout:` はApexにあるがメタデータ定義は未格納 | 本番/各Sandboxで手動作成またはメタデータ化 |
| 4 | `package2.xml` のCustomObject名が実資産名と不一致 | package manifest deploy時に取りこぼし/失敗の恐れ | `force-app/main/default` デプロイかmanifest修正 |
| 5 | `classes` のみdeployは失敗しやすい | Apexが未配置のカスタムオブジェクト/項目に依存 | 初回移行はobjects込みでdeploy |
| 6 | freee同期は二重送信防止あり | `Sent_To_Freee__c=true` またはfreee IDありでエラー | 疎通テストは未同期レコードで実施 |
| 7 | 請求/見積URL生成 | `Invoice_Base_Url__c` をもとにURLを生成 | 請求は `/invoices/`、見積は置換で `/quotations/` になる前提を確認 |

## 11. ロールバック方針

| ケース | 対応 | 予定時間 |
| --- | --- | --- |
| メタデータデプロイ失敗 | Deploy結果を確認し、未適用なら修正後再実行 | 30-120分 |
| 手動設定ミス | Named Credential、設定レコード、権限を修正 | 15-60分 |
| freee疎通失敗 | Named Credential認証、会社ID、テンプレートID、勘定科目IDを確認 | 30-90分 |
| 業務影響あり | LWCアクションをレイアウトから一時撤去、対象ユーザ権限を外す | 15-30分 |
| データ誤作成 | 作成された `Contract__c`、`Invoice__c`、`InvoiceLine__c`、freee側データを業務判断で取消/削除 | 30分以上 |

