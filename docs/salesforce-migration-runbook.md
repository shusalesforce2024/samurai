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

## 12. 当日作業チェックリスト

この章を上から順番に実施する。各行のチェック欄に結果を記録し、NGが出た場合は次工程へ進まない。

| チェック | No | 作業 | 実施内容 | 完了条件 | 予定時間 |
| --- | ---: | --- | --- | --- | --- |
| [ ] | 1 | 作業開始宣言 | 関係者へ「Salesforce移行作業を開始します」と連絡する | 関係者が作業開始を認識している | 5分 |
| [ ] | 2 | 対象org確認 | `sf org display --target-org <target-org>` を実行する | 表示された Username / Org ID が移行先と一致 | 5分 |
| [ ] | 3 | ブランチ/作業フォルダ確認 | `pwd` と `git status --short` を確認する | `S:\SamuraiPOC\samurai` 配下で作業している | 5分 |
| [ ] | 4 | 未反映変更確認 | `git status --short` の内容を確認する | 移行対象外の変更が混ざっていない | 10分 |
| [ ] | 5 | dry-run実行 | 13章のdry-runコマンドを実行する | Deploy Status が `Succeeded` | 30-60分 |
| [ ] | 6 | 本番デプロイ実行 | 13章の本番デプロイコマンドを実行する | Deploy Status が `Succeeded` | 30-60分 |
| [ ] | 7 | Apexテスト確認 | Deploy結果またはApex Test結果を確認する | 失敗テスト0件、カバレッジ75%以上 | 15分 |
| [ ] | 8 | Named Credential設定 | 14章に従い `Freee_iv` と `FreeeAPI` を作成/確認する | 2件とも有効、認証済み | 40-80分 |
| [ ] | 9 | freee設定レコード作成 | 15章に従い `Freee_Configs__c` を作成/確認する | 設定レコードが1件以上存在 | 15分 |
| [ ] | 10 | 勘定科目マッピング作成 | 16章に従い `Freee_Account_Item_Mappings__c` を作成/確認する | 請求で使うキー分の有効レコードが存在 | 20分 |
| [ ] | 11 | 権限付与 | 17章に従い対象ユーザへ権限を付与する | 対象ユーザでレコード参照/アクション実行可能 | 45分 |
| [ ] | 12 | 画面アクション配置 | 18章に従いLWCアクションを配置する | 対象画面にボタンが表示される | 30分 |
| [ ] | 13 | 疎通確認 | 19章の業務シナリオを実行する | 全シナリオOK | 60-120分 |
| [ ] | 14 | ログ確認 | `Freee_Sync_Log__c` と同期ステータスを確認する | 成功/失敗ログが期待通り記録される | 15分 |
| [ ] | 15 | 完了判定 | 関係者へ結果を共有し、Go判定を得る | 業務担当/管理者が承認 | 15分 |
| [ ] | 16 | 作業完了連絡 | 「Salesforce移行作業が完了しました」と連絡する | 完了連絡済み | 5分 |

## 13. コマンド実行手順

### 13.1 作業フォルダへ移動

```powershell
cd S:\SamuraiPOC\samurai
```

確認:

```powershell
pwd
git status --short
```

判定:

| 結果 | 対応 |
| --- | --- |
| `pwd` が `S:\SamuraiPOC\samurai` | OK |
| 想定外の変更がある | 作業責任者へ確認。移行対象外ならデプロイ対象に含めない |
| `ContractUpdate__c` 等の未追跡ファイルがある | 今回の移行対象か確認。対象外なら触らない |

### 13.2 org確認

```powershell
sf org display --target-org <target-org>
```

例:

```powershell
sf org display --target-org shu.kawanami@samuraiarchitects.com.dev1
```

確認項目:

| 項目 | 確認内容 |
| --- | --- |
| Username | 移行対象ユーザであること |
| Org ID | 移行先orgのOrg IDであること |
| Connected Status | Connectedであること |
| Instance URL | 想定環境であること |

### 13.3 dry-run

初回移行または移行先にカスタムオブジェクトが未配置の場合、`classes` のみでは失敗する。必ず `force-app/main/default` 全体でdry-runする。

```powershell
sf project deploy start --source-dir force-app/main/default --target-org <target-org> --dry-run --test-level RunLocalTests --wait 60
```

例:

```powershell
sf project deploy start --source-dir force-app/main/default --target-org shu.kawanami@samuraiarchitects.com.dev1 --dry-run --test-level RunLocalTests --wait 60
```

成功条件:

| 項目 | 成功条件 |
| --- | --- |
| Deploy Status | `Succeeded` |
| Component Failures | 0件 |
| Test Failures | 0件 |
| Apex Coverage | 75%以上 |

失敗時:

| エラー例 | 原因 | 対応 |
| --- | --- | --- |
| `Invalid type: Quotation__c` | カスタムオブジェクトが未配置、またはclassesのみdeployしている | `force-app/main/default` 全体でdeployする |
| `No such column UnitPrice__c on Product2` | Product2拡張項目が未配置 | Product2メタデータを含めてdeploy |
| `INVALID_CROSS_REFERENCE_KEY` | 参照先メタデータやレイアウト対象が存在しない | 依存オブジェクト/項目/レコードタイプを確認 |
| `Apex test failure` | テストデータまたはロジック不整合 | 失敗テスト名、行番号、エラー文を記録して修正 |
| `INSERT_UPDATE_DELETE_NOT_ALLOWED_DURING_MAINTENANCE` | Salesforceメンテナンス中 | メンテナンス終了後に再実行 |

### 13.4 本番デプロイ

dry-run成功後に実施する。

```powershell
sf project deploy start --source-dir force-app/main/default --target-org <target-org> --test-level RunLocalTests --wait 60
```

Deploy IDを控える:

| 項目 | 記録 |
| --- | --- |
| Deploy ID |  |
| 実行者 |  |
| 開始時刻 |  |
| 終了時刻 |  |
| 結果 |  |

### 13.5 Deploy結果確認

```powershell
sf project deploy report --target-org <target-org> --use-most-recent
```

## 14. Named Credential設定手順

ソース内にNamed Credentialメタデータは存在しないため、移行先orgで手動作成する。

### 14.1 `Freee_iv`

| 項目 | 設定値/方針 |
| --- | --- |
| Label | `Freee_iv` |
| Name | `Freee_iv` |
| URL | freee請求書/見積APIのベースURL。例: `https://api.freee.co.jp/api/1` |
| 認証方式 | freee APIの契約/運用に合わせる。OAuth 2.0推奨 |
| 用途 | `callout:Freee_iv/invoices`、`callout:Freee_iv/quotations` |

画面操作:

| No | 操作 |
| ---: | --- |
| 1 | Salesforce設定を開く |
| 2 | Quick Findで `Named Credentials` を検索 |
| 3 | 新規Named Credentialを作成 |
| 4 | Label/Nameに `Freee_iv` を入力 |
| 5 | URLにfreee APIベースURLを入力 |
| 6 | 認証方式、External Credential、Principalを設定 |
| 7 | 保存 |
| 8 | 認証が必要な場合は認証フローを完了 |

確認:

| 確認項目 | OK条件 |
| --- | --- |
| Named Credential名 | `Freee_iv` と完全一致 |
| Apex参照 | `FreeeInvoiceService`、`FreeeQuotationService` で使用 |
| API URL | `/invoices` と `/quotations` が後続パスとして成立 |

### 14.2 `FreeeAPI`

| 項目 | 設定値/方針 |
| --- | --- |
| Label | `FreeeAPI` |
| Name | `FreeeAPI` |
| URL | freee APIベースURL。例: `https://api.freee.co.jp` |
| 認証方式 | freee APIの契約/運用に合わせる。OAuth 2.0推奨 |
| 用途 | `callout:FreeeAPI/api/1/partners` |

確認:

| 確認項目 | OK条件 |
| --- | --- |
| Named Credential名 | `FreeeAPI` と完全一致 |
| Apex参照 | `FreeePartnerService` で使用 |
| API URL | `/api/1/partners` が後続パスとして成立 |

注意:

| 注意点 | 内容 |
| --- | --- |
| `Freee_iv` と `FreeeAPI` のURL差 | Apexの後続パスが異なるため、URL末尾に `/api/1` を含めるかどうかを必ず確認する |
| 認証ユーザ | 本番運用で期限切れになりにくい連携用ユーザ/連携用認証を使う |
| Secret管理 | Client SecretやRefresh Tokenを手順書に直接記載しない。安全な保管場所から当日参照する |

## 15. `Freee_Configs__c` 設定レコード作成手順

Apexは `Freee_Config__mdt` ではなく `Freee_Configs__c` を参照する。必ず `Freee_Configs__c` に設定レコードを作成する。

### 15.1 作成方法

| 方法 | 手順 |
| --- | --- |
| 画面 | App Launcherで `Freee Configs` または `Freee_Configs__c` を開き、新規作成 |
| Data Loader | `Freee_Configs__c` にCSV insert |
| Developer Console | Anonymous Apexでinsert |

### 15.2 入力項目

| 項目API名 | 必須 | 入力例 | 説明 |
| --- | --- | --- | --- |
| `Name` | 推奨 | `Default` | `FreeePartnerFacade` は `Name='Default'` を優先取得 |
| `Company_Id__c` | 必須 | `12562039` | freee会社ID |
| `Template_Id__c` | 必須 | `4411743` | freee請求書テンプレートID |
| `Quotation_Template_Id__c` | 見積では必須 | freee見積テンプレートID | 未設定だと見積作成でエラー |
| `Invoice_Base_Url__c` | 必須 | `https://secure.freee.co.jp/invoices/` | Salesforce上に保存するfreee請求/見積URL生成用 |
| `Payment_Type__c` | 任意 | `transfer` | 未設定時はmapperで `transfer` |
| `Tax_Entry_Method__c` | 必須 | `out` / `exclusive` 等 | freee仕様に合わせる |
| `Tax_Fraction__c` | 必須 | `omit` / `round_down` 等 | freee仕様に合わせる |
| `Withholding__c` | 任意 | `out` 等 | 現行mapperでは直接使用なし |
| `Withholding_Tax_Entry_Method__c` | 任意 | `out` | 未設定時は `out` |

### 15.3 Anonymous Apex例

値は本番用に置き換えてから実行する。

```apex
insert new Freee_Configs__c(
    Name = 'Default',
    Company_Id__c = '12562039',
    Template_Id__c = '4411743',
    Quotation_Template_Id__c = '<freee見積テンプレートID>',
    Invoice_Base_Url__c = 'https://secure.freee.co.jp/invoices/',
    Payment_Type__c = 'transfer',
    Tax_Entry_Method__c = 'out',
    Tax_Fraction__c = 'omit',
    Withholding_Tax_Entry_Method__c = 'out'
);
```

確認SOQL:

```sql
SELECT Id, Name, Company_Id__c, Template_Id__c, Quotation_Template_Id__c,
       Invoice_Base_Url__c, Payment_Type__c, Tax_Entry_Method__c,
       Tax_Fraction__c, Withholding_Tax_Entry_Method__c
FROM Freee_Configs__c
ORDER BY CreatedDate ASC
```

成功条件:

| 条件 | 内容 |
| --- | --- |
| レコード件数 | 1件以上 |
| `Company_Id__c` | 空でない、数値文字列 |
| `Template_Id__c` | 空でない、数値文字列 |
| `Quotation_Template_Id__c` | 見積連携する場合は空でない、数値文字列 |
| `Invoice_Base_Url__c` | 空でない |

## 16. `Freee_Account_Item_Mappings__c` 設定手順

請求書作成時、`Invoice__c.Freee_Account_Item_Picklist__c` の値をキーに `Freee_Account_Item_Mappings__c` を検索する。

### 16.1 必須レコード

| 項目API名 | 必須 | 入力例 | 説明 |
| --- | --- | --- | --- |
| `Name` | 必須 | `Sales mapping` | 任意の管理名 |
| `Key__c` | 必須 | `Sales` | `Invoice__c.Freee_Account_Item_Picklist__c` と一致させる |
| `Freee_Account_Item_Id__c` | 必須 | `1033096369` | freee勘定科目ID |
| `Is_Active__c` | 必須 | `true` | trueのみ検索対象 |

### 16.2 Anonymous Apex例

```apex
insert new Freee_Account_Item_Mappings__c(
    Name = 'Sales mapping',
    Key__c = 'Sales',
    Freee_Account_Item_Id__c = '1033096369',
    Is_Active__c = true
);
```

確認SOQL:

```sql
SELECT Id, Name, Key__c, Freee_Account_Item_Id__c, Is_Active__c
FROM Freee_Account_Item_Mappings__c
ORDER BY CreatedDate ASC
```

成功条件:

| 条件 | 内容 |
| --- | --- |
| `Key__c` | 請求書で使う選択リスト値と完全一致 |
| `Freee_Account_Item_Id__c` | 空でない、freee側に存在 |
| `Is_Active__c` | true |

## 17. 権限設定手順

### 17.1 権限セット作成方針

推奨は、既存プロファイルを直接変更せず、権限セットを作成して対象ユーザに割り当てる。

| 権限セット名案 | 対象ユーザ | 目的 |
| --- | --- | --- |
| `Freee Integration User` | 営業/請求担当 | freee同期アクション利用 |
| `Freee Integration Admin` | 管理者/運用担当 | freee設定、マッピング、ログ確認 |

### 17.2 `Freee Integration User`

| 対象 | 権限 |
| --- | --- |
| Account | Read, Edit |
| Opportunity__c | Read, Create, Edit |
| Quotation__c | Read, Create, Edit |
| QuotationLine__c | Read, Create, Edit |
| Invoice__c | Read, Create, Edit |
| InvoiceLine__c | Read, Create, Edit |
| Contract__c | Read, Create |
| Product2 | Read |
| Freee_Sync_Log__c | Read, Create |
| Apex Classes | `FreeeInvoiceController`, `FreeeQuotationController`, `FreeePartnerController`, `OppContractInvoiceController` へのアクセス |

### 17.3 `Freee Integration Admin`

| 対象 | 権限 |
| --- | --- |
| Freee_Configs__c | Read, Create, Edit |
| Freee_Account_Item_Mappings__c | Read, Create, Edit |
| Freee_Sync_Log__c | Read, Create |
| Named Credential関連 | 管理者権限または該当設定権限 |

### 17.4 権限確認

対象ユーザでログインし、以下を確認する。

| 確認 | OK条件 |
| --- | --- |
| Account画面 | freee取引先同期ボタンが見える |
| Invoice__c画面 | freee請求同期ボタンが見える |
| Quotation__c画面 | freee見積同期ボタンが見える |
| Opportunity__c画面 | 契約/請求作成ボタンが見える |
| Freee_Sync_Log__c | 管理者がログを参照できる |

## 18. Lightning画面アクション配置手順

LWCは `lightning__RecordAction` として作成されている。対象オブジェクトのレコードページ/ページレイアウトに配置する。

| LWC | Apex Controller | 配置対象 | 用途 |
| --- | --- | --- | --- |
| `freeePartnerSyncAction` | `FreeePartnerController.syncPartner` | Account | freee取引先作成 |
| `freeeInvoiceAction` | `FreeeInvoiceController.createInvoice` | Invoice__c | freee請求書作成 |
| `freeeQuotationAction` | `FreeeQuotationController.createQuotation` | Quotation__c | freee見積作成 |
| `opportunityContractInvoiceAction` | `OppContractInvoiceController.createContractAndInvoice` | Opportunity__c | 商談から契約/請求作成 |

画面操作:

| No | 操作 |
| ---: | --- |
| 1 | Setup > Object Manager を開く |
| 2 | 対象オブジェクトを選択 |
| 3 | Buttons, Links, and Actions でLWC Record Actionが存在するか確認 |
| 4 | Page Layouts または Lightning Record Pages を開く |
| 5 | Salesforce Mobile and Lightning Experience Actions に対象アクションを配置 |
| 6 | 保存、必要に応じてActivate |
| 7 | 対象ユーザでレコードページを開き、ボタン表示を確認 |

配置チェック:

| チェック | 対象 | OK条件 |
| --- | --- | --- |
| [ ] | Account | `freeePartnerSyncAction` が表示される |
| [ ] | Invoice__c | `freeeInvoiceAction` が表示される |
| [ ] | Quotation__c | `freeeQuotationAction` が表示される |
| [ ] | Opportunity__c | `opportunityContractInvoiceAction` が表示される |

## 19. 疎通確認手順詳細

### 19.1 freee取引先作成

| 項目 | 内容 |
| --- | --- |
| 対象画面 | Account |
| 前提 | `Freee_Partner_Id__c` が空 |
| 操作 | freee取引先同期アクションを実行 |
| 成功条件 | `Account.Freee_Partner_Id__c` にfreee取引先IDが保存される |
| 失敗時確認 | Named Credential `FreeeAPI`、`Freee_Configs__c.Company_Id__c`、Apex権限 |

確認SOQL:

```sql
SELECT Id, Name, Freee_Partner_Id__c
FROM Account
WHERE Id = '<対象AccountId>'
```

### 19.2 freee請求書作成

| 項目 | 内容 |
| --- | --- |
| 対象画面 | Invoice__c |
| 前提 | Accountに `Freee_Partner_Id__c`、Invoiceに `Billing_Date__c`、`Freee_Account_Item_Picklist__c`、InvoiceLineが存在 |
| 操作 | freee請求同期アクションを実行 |
| 成功条件 | `Freee_Invoice_Id__c`、`Freee_Invoice_Number__c`、`Freee_Invoice_URL__c`、`Freee_Sync_Status__c=Success`、`Sent_To_Freee__c=true` |
| 失敗時確認 | `Freee_iv`、`Freee_Configs__c`、`Freee_Account_Item_Mappings__c`、明細の数量/単価/税率 |

確認SOQL:

```sql
SELECT Id, Subject__c, Freee_Invoice_Id__c, Freee_Invoice_Number__c,
       Freee_Invoice_URL__c, Freee_Sync_Status__c, Freee_Sync_Message__c,
       Sent_To_Freee__c, Retry_Count__c
FROM Invoice__c
WHERE Id = '<対象InvoiceId>'
```

### 19.3 freee見積作成

| 項目 | 内容 |
| --- | --- |
| 対象画面 | Quotation__c |
| 前提 | Accountに `Freee_Partner_Id__c`、Quotationに `Issue_Date__c`、QuotationLineが存在、`Quotation_Template_Id__c` 設定済み |
| 操作 | freee見積同期アクションを実行 |
| 成功条件 | `Freee_Quotation_Id__c`、`Freee_Quotation_Number__c`、`Freee_Quotation_URL__c`、`Freee_Sync_Status__c=Success`、`Sent_To_Freee__c=true` |
| 失敗時確認 | `Freee_iv`、`Quotation_Template_Id__c`、Accountのfreee取引先ID、明細の数量/単価/税率 |

確認SOQL:

```sql
SELECT Id, Subject__c, Freee_Quotation_Id__c, Freee_Quotation_Number__c,
       Freee_Quotation_URL__c, Freee_Sync_Status__c, Freee_Sync_Message__c,
       Sent_To_Freee__c, Retry_Count__c
FROM Quotation__c
WHERE Id = '<対象QuotationId>'
```

### 19.4 商談から契約/請求作成

| 項目 | 内容 |
| --- | --- |
| 対象画面 | Opportunity__c |
| 前提 | `StageName__c=Closed Won`、`Account__c`、`StartDate__c` が設定済み |
| 前提 | 対象商談に `Quotation_Status__c=Accepted` の見積が1件以上あり、見積明細が存在 |
| 操作 | 契約/請求作成アクションを実行 |
| 成功条件 | `Contract__c` 1件、`Invoice__c` 1件、`InvoiceLine__c` が見積明細数分作成 |
| 失敗時確認 | 既存契約/請求の重複、Accepted見積の有無、見積明細の入力値 |

確認SOQL:

```sql
SELECT Id, ContractName__c, Oppotunity__c, Status__c
FROM Contract__c
WHERE Oppotunity__c = '<対象OpportunityId>'
```

```sql
SELECT Id, Subject__c, ParentOpportunity__c, ParentContract__c,
       Freee_Account_Item_Picklist__c, TotalAmount__c
FROM Invoice__c
WHERE ParentOpportunity__c = '<対象OpportunityId>'
```

```sql
SELECT Id, Invoice__c, Description__c, Quantity__c, Unit_Price__c, Tax_Rate__c, Line_Amount__c
FROM InvoiceLine__c
WHERE Invoice__c = '<対象InvoiceId>'
ORDER BY CreatedDate ASC
```

### 19.5 同期ログ確認

```sql
SELECT Id, Target_Record_Id__c, Result__c, Status_Code__c,
       Error_Message__c, CreatedDate
FROM Freee_Sync_Log__c
ORDER BY CreatedDate DESC
LIMIT 20
```

判定:

| 状態 | 判定 |
| --- | --- |
| `Result__c=Success` | 正常 |
| `Result__c=Failed` | `Error_Message__c` と対象レコードの `Freee_Sync_Message__c` を確認 |
| ログがない | `Freee_Sync_Log__c` 作成権限、Apex例外発生箇所を確認 |

## 20. 当日記録欄

| 項目 | 記録 |
| --- | --- |
| 作業日 |  |
| 対象org |  |
| Target Org Username |  |
| Org ID |  |
| 作業開始 |  |
| 作業終了 |  |
| 作業者 |  |
| 承認者 |  |
| Deploy ID |  |
| dry-run結果 |  |
| 本番deploy結果 |  |
| Apexテスト結果 |  |
| カバレッジ |  |
| freee取引先疎通 |  |
| freee請求疎通 |  |
| freee見積疎通 |  |
| 商談から契約/請求作成 |  |
| 残課題 |  |

## 21. 連絡テンプレート

### 21.1 作業開始

```text
Salesforce移行作業を開始します。
対象org: <org名>
予定時間: <開始時刻> - <終了予定時刻>
作業中は対象機能の利用を控えてください。
```

### 21.2 dry-run成功

```text
Salesforce移行 dry-run が成功しました。
Deploy ID: <Deploy ID>
次に本番デプロイへ進みます。
```

### 21.3 本番デプロイ成功

```text
Salesforceメタデータデプロイが成功しました。
Deploy ID: <Deploy ID>
これから手動設定と疎通確認を実施します。
```

### 21.4 作業完了

```text
Salesforce移行作業が完了しました。
実施内容:
- メタデータデプロイ
- freee連携設定
- 権限/画面アクション設定
- 主要シナリオ疎通確認

結果: 正常
残課題: <あれば記載>
```

### 21.5 中断/延期

```text
Salesforce移行作業を中断します。
理由: <理由>
影響: <影響>
次回対応: <対応方針>
再開予定: <日時>
```
