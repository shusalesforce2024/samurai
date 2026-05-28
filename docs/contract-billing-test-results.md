# 契約請求・Freee連携 実施テストパターンと結果

更新日: 2026-05-24

## 1. 実施結果サマリ

| 実行日 | 種別 | 対象 | 結果 | ID |
| --- | --- | --- | --- | --- |
| 2026-05-24 | Apex個別テスト | `OppContractInvoiceServiceTest` | 4/4 Pass | `707Ie00001G8J30` |
| 2026-05-24 | Apex主要テスト | 契約請求・Freee連携の主要テスト7クラス | 28/28 Pass | `707Ie00001G8R5I` |
| 2026-05-24 | Apex追加テスト | `OppContractInvoiceServiceTest`, `ContractRenewalInvoiceBatchTest`, `InvoiceCancelRecreateServiceTest` | 13/13 Pass | `707Ie00001G8Rrz` |
| 2026-05-24 | Apex主要回帰テスト | 契約請求・Freee連携の主要回帰テスト7クラス | 33/33 Pass | `707Ie00001G8SoL` |
| 2026-05-24 | Apex広域テスト | `RunLocalTests` 相当 | 71/71 Pass | `707Ie00001G8Ugh` |
| 2026-05-24 | Metadata dry-run | `manifest/package-contract-billing-release.xml` / NoTestRun | Succeeded | `0AfIe0000019l87KAA` |
| 2026-05-24 | Release readiness | 権限セット、主要Apex、バッチ、商品マスタ、Freee設定 | OK | なし |

## 2. 実行コマンド

```powershell
sf project deploy start --target-org dev1 --manifest manifest/package-contract-billing-release.xml --dry-run --test-level NoTestRun --wait 10
sf apex run test --target-org dev1 --test-level RunLocalTests --result-format human --wait 60
powershell -ExecutionPolicy Bypass -File scripts/check-contract-billing-release-readiness.ps1 -OrgAlias dev1
```

## 3. Apexテストクラス別の確認範囲

| テストクラス | 主な確認範囲 | 結果 |
| --- | --- | --- |
| `OppContractInvoiceServiceTest` | 受注済み取引から契約、契約期間、請求、請求明細、契約月次明細を作成する処理 | Pass |
| `ContractRenewalInvoiceBatchTest` | 月契約・年契約の更新請求作成、11日判定、更新停止スキップ | Pass |
| `FreeeInvoiceStatusSyncBatchTest` | Freee側の送付ステータス、決済ステータス、入金額、未入金額の同期 | Pass |
| `InvoiceCancelRecreateServiceTest` | 請求取消、再作成、Freee連携済み請求・明細の編集制御 | Pass |
| `InvoiceActionControllerTest` | 請求取消・再作成LWCから呼ばれるApex controller | Pass |
| `FreeeIntegrationTest` | Freee取引先、見積、請求連携、設定取得、ログ、成功・失敗処理 | Pass |
| `TriggerSyncServicesTest` | 取引確度同期、MRR同期、商品単価同期、権限チェック | Pass |
| `ContractMonthlyLineBatchTest` | 契約月次明細の月契約・年契約作成、重複防止、更新月判定 | Pass |
| 既存コミュニティ系テスト | 既存のログイン、セルフ登録、パスワード変更、マイルストーン処理 | Pass |

## 4. 実施済みApexテストパターン

### 初回契約・請求作成

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | 月契約の取引から契約、請求、請求明細を作成できる | `OppContractInvoiceServiceTest.createsContractInvoiceAndInvoiceLinesFromController` | Pass |
| 2 | 年契約で初期費用と月次売上予定を作成できる | `OppContractInvoiceServiceTest.createsAnnualContractWithInitialFeeAndMonthlyRevenueLines` | Pass |
| 3 | 税額の端数を切り上げで計算する | `OppContractInvoiceServiceTest.roundsTaxAmountUpWhenFractionOccurs` | Pass |
| 4 | Activate見積が複数ある場合はエラーにする | `OppContractInvoiceServiceTest.throwsErrorWhenMultipleAcceptedQuotationsExist` | Pass |
| 5 | 未受注の取引では初回作成できない | `OppContractInvoiceServiceTest.throwsErrorWhenOpportunityIsNotClosedWon` | Pass |
| 6 | すでに作成済みの場合は重複作成しない | `OppContractInvoiceServiceTest.throwsErrorWhenRecordsAlreadyCreated` | Pass |

### 更新請求作成

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | 月契約は毎月11日に更新請求一式を作成する | `ContractRenewalInvoiceBatchTest.createsMonthlyRenewalInvoiceSetOnEleventh` | Pass |
| 2 | 年契約は次年度契約開始月の前月11日に年一括請求を作成する | `ContractRenewalInvoiceBatchTest.createsYearlyRenewalInvoiceInPreviousMonth` | Pass |
| 3 | 更新停止契約は更新請求を作成しない | `ContractRenewalInvoiceBatchTest.skipsRenewalStoppedContract` | Pass |
| 4 | 11日以外は更新請求を作成しない | `ContractRenewalInvoiceBatchTest.skipsWhenNotEleventh` | Pass |

### 契約月次明細作成

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | 有効化された月契約で当月分を作成する | `ContractMonthlyLineBatchTest.monthlyContractCreatesCurrentMonthWhenActivated` | Pass |
| 2 | 請求更新日後は翌月分を作成する | `ContractMonthlyLineBatchTest.monthlyContractCreatesNextMonthAfterBillingUpdateDay` | Pass |
| 3 | 請求更新日当日は翌月分を作成しない | `ContractMonthlyLineBatchTest.monthlyContractDoesNotCreateNextMonthOnBillingUpdateDay` | Pass |
| 4 | 再実行しても月次明細を重複作成しない | `ContractMonthlyLineBatchTest.monthlyContractCreatesNoDuplicateOnRerun` | Pass |
| 5 | 年契約の有効化時に12か月分を作成する | `ContractMonthlyLineBatchTest.yearlyContractCreatesTwelveLinesWhenActivated` | Pass |
| 6 | 年契約の更新月判定後に次年度12か月分を作成する | `ContractMonthlyLineBatchTest.yearlyContractCreatesNextTwelveLinesAfterRenewalMonthDayTen` | Pass |
| 7 | 年契約の更新月判定前は次年度分を作成しない | `ContractMonthlyLineBatchTest.yearlyContractDoesNotCreateNextYearBeforeRenewalMonthDayTen` | Pass |
| 8 | 請求がない有効契約はエラー扱いにする | `ContractMonthlyLineBatchTest.activatedContractWithoutInvoiceThrowsError` | Pass |
| 9 | 無効契約は対象外にする | `ContractMonthlyLineBatchTest.inactiveContractIsIgnored` | Pass |

### Freee連携

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | Freee設定を型付きで取得できる | `FreeeIntegrationTest.configServiceReturnsTypedConfig` | Pass |
| 2 | 見積テンプレートID不足を検知する | `FreeeIntegrationTest.configServiceRejectsMissingQuotationTemplateId` | Pass |
| 3 | 請求controllerで成功時に請求とログを更新する | `FreeeIntegrationTest.invoiceControllerSyncsSuccessAndWritesLog` | Pass |
| 4 | 請求facadeで失敗詳細を保存する | `FreeeIntegrationTest.invoiceFacadeStoresFailureDetails` | Pass |
| 5 | Freee請求書作成JSONを期待形式で組み立てる | `FreeeIntegrationTest.invoiceMapperBuildsExpectedJson` | Pass |
| 6 | 取引先controllerでFreee取引先を作成し取引先を更新する | `FreeeIntegrationTest.partnerControllerCreatesPartnerAndUpdatesAccount` | Pass |
| 7 | 既存Freee取引先がある場合は既存IDを利用する | `FreeeIntegrationTest.partnerControllerUsesExistingFreeePartnerWhenNameMatches` | Pass |
| 8 | 見積controllerで成功時に見積とログを更新する | `FreeeIntegrationTest.quotationControllerSyncsSuccessAndWritesLog` | Pass |
| 9 | 見積facadeで失敗詳細を保存する | `FreeeIntegrationTest.quotationFacadeStoresFailureDetails` | Pass |
| 10 | Freee見積作成JSONを期待形式で組み立てる | `FreeeIntegrationTest.quotationMapperBuildsExpectedJson` | Pass |
| 11 | serviceクラスがcalloutを送信できる | `FreeeIntegrationTest.serviceClassesSendCallouts` | Pass |
| 12 | controllerがnull IDを拒否する | `FreeeIntegrationTest.controllersRejectNullIds` | Pass |
| 13 | contextとログ補助クラスが直接利用できる | `FreeeIntegrationTest.contextAndLogSupportClassesWorkDirectly` | Pass |

### Freee入金ステータス同期

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | 未入金のFreee請求を同期し、送付・決済・金額系項目をSalesforce請求へ反映する | `FreeeInvoiceStatusSyncBatchTest.syncsUnpaidFreeeInvoices` | Pass |

### 請求取消・再作成・編集制御

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | Salesforce請求を取消し、新規請求として再作成する | `InvoiceCancelRecreateServiceTest.cancelsAndRecreatesSalesforceInvoice` | Pass |
| 2 | Freee連携済み請求の業務項目編集をブロックする | `InvoiceCancelRecreateServiceTest.blocksBusinessEditAfterFreeeSync` | Pass |
| 3 | Freee連携済み請求の請求明細編集をブロックする | `InvoiceCancelRecreateServiceTest.blocksInvoiceLineEditAfterFreeeSync` | Pass |
| 4 | LWC controller経由で取消・再作成できる | `InvoiceActionControllerTest.cancelAndRecreateFromController` | Pass |

### トリガー・同期補助

| No | テストパターン | テストメソッド | 結果 |
| --- | --- | --- | --- |
| 1 | 取引ステージに応じて確度を同期する | `TriggerSyncServicesTest.opportunityStageProbabilitySyncsOnInsertAndUpdate` | Pass |
| 2 | 見積ヘッダ・明細から取引MRRを同期する | `TriggerSyncServicesTest.opportunityMrrSyncsFromQuotationHeadersAndLines` | Pass |
| 3 | 商品マスタ単価を見積明細・請求明細へ同期する | `TriggerSyncServicesTest.productUnitPriceSyncsQuotationAndInvoiceLines` | Pass |
| 4 | 権限チェック補助が標準テストユーザーで例外を出さない | `TriggerSyncServicesTest.securityUtilityChecksDoNotThrowForDefaultTestUser` | Pass |

## 5. RunLocalTestsでPassした全テストクラス

| テストクラス | 実行結果 |
| --- | --- |
| `ChangePasswordControllerTest` | Pass |
| `ForgotPasswordControllerTest` | Pass |
| `LightningSelfRegisterControllerTest` | Pass |
| `SiteLoginControllerTest` | Pass |
| `OppContractInvoiceServiceTest` | Pass |
| `SiteRegisterControllerTest` | Pass |
| `MyProfilePageControllerTest` | Pass |
| `TriggerSyncServicesTest` | Pass |
| `MicrobatchSelfRegControllerTest` | Pass |
| `CommunitiesSelfRegConfirmControllerTest` | Pass |
| `MilestoneTest` | Pass |
| `CommunitiesSelfRegControllerTest` | Pass |
| `FreeeIntegrationTest` | Pass |
| `InvoiceCancelRecreateServiceTest` | Pass |
| `FreeeInvoiceStatusSyncBatchTest` | Pass |
| `CommunitiesLandingControllerTest` | Pass |
| `CommunitiesLoginControllerTest` | Pass |
| `ContractMonthlyLineBatchTest` | Pass |
| `ContractRenewalInvoiceBatchTest` | Pass |
| `LightningLoginFormControllerTest` | Pass |
| `InvoiceActionControllerTest` | Pass |
| `LightningForgotPasswordControllerTest` | Pass |

## 6. メタデータ・設定系テスト結果

### manifest dry-run

| 項目 | 結果 |
| --- | --- |
| コマンド | `sf project deploy start --target-org dev1 --manifest manifest/package-contract-billing-release.xml --dry-run --test-level NoTestRun --wait 10` |
| Deploy ID | `0AfIe0000019l87KAA` |
| 結果 | Succeeded |
| 補足 | 修正版manifestで実施。日本語レイアウト名をXMLとして正しく読める状態に修正済み |

### release readinessチェック

| 確認項目 | 結果 | 補足 |
| --- | --- | --- |
| `SAMURAI_Sales_Contract_User` 権限セット | OK | 営業用 |
| `SAMURAI_Contract_Billing_User` 権限セット | OK | 経理用 |
| `SAMURAI_System_Admin` 権限セット | OK | システム管理者用 |
| 主要Apexクラス | OK | 初回作成、更新請求、Freee連携、取消、再作成 |
| `FreeeInvoiceStatusSyncBatch` スケジュール | OK | `WAITING / 0 0 3 * * ?` |
| `ContractRenewalInvoiceBatch` 月次スケジュール | OK | `ContractRenewalInvoiceBatch_毎月11日2時 / WAITING / 0 0 2 11 * ?` |
| `ContractRenewalInvoiceBatch` 重複スケジュール | OK | 重複日次スケジュールなし |
| `ProductMaster__c` データ | OK | UAT/本番前に商品マスタが必要 |
| `Freee_Configs__c` データ | OK | Freee連携前に設定が必要 |

## 7. 未実施・UAT確認対象

以下はApex自動テストではなく、UATまたは本番後チェックで確認する。

| 確認対象 | 理由 | 確認先 |
| --- | --- | --- |
| 実Freee環境への請求書作成 | ApexテストではHTTP calloutをモックしているため | UAT、本番後チェック |
| Freee側で手動送付した後の実ステータス反映 | 実Freee状態変更が必要なため | UAT、本番後チェック |
| 営業・経理ユーザーの実画面操作 | 権限セットとページレイアウトの体感確認が必要なため | UATチェックリスト |
| レポート・ダッシュボードの表示妥当性 | データの見え方、グラフの使いやすさ確認が必要なため | UATチェックリスト |
| 商品マスタCSVの本番データ投入 | データ自体はユーザー作業のため | 商品マスタCSV入力チェック観点 |

## 8. 2026-05-28 追加シナリオテスト結果

未実施UAT分をdev1で追加確認した。

| 実行日 | 種別 | 対象 | 結果 | ID |
| --- | --- | --- | --- | --- |
| 2026-05-28 | Apex主要シナリオテスト | 契約請求・Freee連携の主要9テストクラス | 58/58 Pass | `707Ie00001HCDGM` |
| 2026-05-28 | 修正デプロイ | `FreeeInvoiceStatusSyncService`, `FreeeInvoiceStatusSyncBatchTest` | Succeeded | `0AfIe0000019p2yKAA` |
| 2026-05-28 | 実Freee同期UAT | 実Freee請求書ID付き請求8件 | 8/8 Success | なし |

追加で検出した不具合:

| 内容 | 原因 | 対応 | 結果 |
| --- | --- | --- | --- |
| Freee入金ステータス同期を複数件で実行すると、2件目以降が `You have uncommitted work pending` になる | 1件ごとにFreee連携ログを保存してから次のcalloutへ進んでいた | ログ保存をcalloutループ後にまとめるよう修正し、複数件同期テストを追加 | 修正済み。対象テスト8/8 Pass、実データ8件同期成功 |

追加UAT結果:

| 対象 | 結果 | 補足 |
| --- | --- | --- |
| 営業権限 | 条件付きPass | dev1に営業専用ユーザーがないため、権限セットのオブジェクト/Apex/Visualforceアクセス確認で代替 |
| 経理権限 | 条件付きPass | dev1に経理専用ユーザーがないため、権限セットのオブジェクト/Apex/Visualforceアクセス確認で代替 |
| 実Freeeステータス同期 | Pass | 8件すべて `Freee_Sync_Status__c = Success` |
| レポート/ダッシュボード | Pass | 契約請求レポート16件、契約請求ダッシュボード1件を確認 |
| 商品マスタデータ | NG | dev1の商品マスタ3件すべて `Freee_Item_Id__c` が未設定。本番相当の請求書作成前に補完が必要 |
