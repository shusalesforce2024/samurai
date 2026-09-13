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
| 商品マスタデータ | Pass | dev1の商品マスタ3件を確認。現行のFreee見積書・請求書連携では `Freee_Item_Id__c` は不要 |

## 9. 2026-07-23 Freee請求取込時の契約自動補完

### 検証結果

| 項目 | 結果 |
| --- | --- |
| 対象環境 | `dev1` |
| 検証方式 | メタデータdry-run + RunSpecifiedTests |
| Deploy ID | `0AfdL00000e7tf3SAA` |
| メタデータ | 54/54 成功 |
| Apexテスト | 31/31 Pass |
| テスト失敗 | 0 |
| 総合判定 | Pass |

### 主な確認シナリオ

| No | シナリオ | 結果 |
| --- | --- | --- |
| 1 | 有効な自動作成ルールから月契約、契約期間、契約月次明細を作成する | Pass |
| 2 | 同じWorkを再処理しても契約、契約期間、契約月次明細を重複作成しない | Pass |
| 3 | 単発請求ではMRR・ARR対象外かつ更新停止の契約を作成する | Pass |
| 4 | 既存契約に対象期間がない場合は契約期間と契約月次明細だけを補完する | Pass |
| 5 | 自動作成ルールが複数一致した場合は要確認として自動作成しない | Pass |
| 6 | Freee管理契約はSalesforce更新請求バッチの対象外とする | Pass |
| 7 | Freee請求一覧をoffset/limitで取得し、複数ページを処理する | Pass |
| 8 | 金額一致だけで商品名の類似性が低い場合は請求確定を停止する | Pass |
| 9 | Freee明細の単位をWorkおよび請求明細へ引き継ぐ | Pass |

### 主要クラスのカバレッジ

| Apexクラス | カバレッジ |
| --- | ---: |
| `FreeeInvoiceContractProvisioningService` | 79.9% |
| `ContractRenewalInvoiceBatch` | 94.5% |
| `Mig_FreeeInvoiceValidator` | 91.7% |
| `Mig_FreeeInvoiceFetchService` | 78.2% |
| `FreeeInvoiceService` | 100.0% |

## 10. 2026-07-23 freee請求移行Work保持期間バッチ

| 項目 | 結果 |
| --- | --- |
| 対象環境 | `dev1` |
| 検証方式 | メタデータdry-run + RunSpecifiedTests |
| Deploy ID | `0AfdL00000e7xE1SAI` |
| メタデータ | 56/56 成功 |
| Apexテスト | 33/33 Pass |
| 対象クラスカバレッジ | `Mig_FreeeInvoiceWorkRetentionBatch` 88.0% |
| 総合判定 | Pass |

| No | シナリオ | 結果 |
| --- | --- | --- |
| 1 | 反映済みかつ作成済み請求ありで、Work作成日時から2か月を超えたWorkを削除する | Pass |
| 2 | 削除対象Workの明細Workを主従関係により連動削除する | Pass |
| 3 | 2か月以内の反映済みWorkを保持する | Pass |
| 4 | 要確認Workを保持する | Pass |
| 5 | 作成済み請求がない反映済みWorkを保持する | Pass |
| 6 | 毎月1日3:00の定期スケジュールを登録する | Pass |

## 11. 2026-07-24 Freee請求契約ルール共通化・既存契約重複防止

| 項目 | 結果 |
| --- | --- |
| 対象環境 | `dev1` |
| 検証方式 | メタデータdry-run + RunSpecifiedTests |
| Deploy ID | `0AfdL00000eCNHxSAO` |
| メタデータ | 28/28 成功 |
| Apexテスト | 9/9 Pass |
| 対象クラスカバレッジ | `FreeeInvoiceContractProvisioningService` 84.7% |
| prod dry-run | `0AfRB000001QkjN0AS`、9/9 Pass |
| prodリリース | `0AfRB000001Qkmb0AC`、28/28成功、9/9 Pass |
| 総合判定 | Pass |

| No | シナリオ | 結果 |
| --- | --- | --- |
| 1 | 商品共通ルールから取引先ごとに別契約を作成する | Pass |
| 2 | 取引先別例外ルールを商品共通ルールより優先する | Pass |
| 3 | 取引先・確定商品・対象日に一致する既存契約が1件ならその契約を使用する | Pass |
| 4 | 同条件の既存契約が複数なら新規契約を作成せず要確認にする | Pass |
| 5 | 継続契約と単発契約を正しい契約区分で作成する | Pass |
| 6 | 既存契約の不足期間・月次明細を補完する | Pass |
| 7 | ルールが複数一致する場合は自動作成しない | Pass |
| 8 | 再実行しても契約・期間・月次明細を重複作成しない | Pass |
| 9 | 請求対象期間がない月払い請求は請求月の期間を使用する | Pass |

### prod初期設定・再検証結果

| 項目 | 実績 |
| --- | ---: |
| 登録した商品共通ルール | 4件 |
| 契約未解決の要確認 Before | 117件 |
| 契約未解決の要確認 After | 42件 |
| 新たに反映可能となったWork | 78件 |
| 自動作成した契約管理 | 30件 |
| 自動作成した契約期間 | 78件 |
| 増加した契約月次明細 | 82件 |

## 2026-07-28 Freee請求ステータス動的分割同期

### 検証結果

| 項目 | 結果 |
| --- | --- |
| dev1関連テスト | 25/25 Pass |
| dev1 Freee全体回帰 | 42/42 Pass |
| prod dry-run | `0AfRB000001RGEb0AO`、40/40 Pass |
| prodリリース | `0AfRB000001RGGD0A4`、5/5コンポーネント成功、40/40 Pass |
| Queueableカバレッジ | 82%以上 |
| Schedulerカバレッジ | 100% |
| 総合判定 | Pass |

### テストパターン

| No | パターン | 期待結果 | 結果 |
| --- | --- | --- | --- |
| 1 | 同期対象が21件ある | 最初の20件を処理し、残り1件を2分後に予約する | Pass |
| 2 | freeeが429を返す | 後続呼出しを停止し、対象を残したまま3分以上後に再予約する | Pass |
| 3 | 429エラー内容を保存する | `freee APIの利用上限`を含む日本語メッセージを請求へ保存する | Pass |
| 4 | 定期起動する | `FreeeInvoiceStatusSyncBatch`から動的Queueableを起動する | Pass |
| 5 | 429発生位置より後ろに未処理IDがある | 429対象と後続IDを次回処理へ引き継ぐ | Pass |
| 6 | 動的処理が待機中 | 重複起動を検知する | Pass |
| 7 | 待機中の動的処理を再予約する | 古い一回実行ジョブを解除して新しいジョブを1件だけ登録する | Pass |
| 8 | 既存の見積・取引先・請求連携 | Freee全体回帰で既存機能に影響がない | Pass |

## 2026-07-28 freee請求Work自動解決・誤紐づけ防止

### 検証結果

| 項目 | 結果 |
|---|---|
| 対象環境 | `dev1` |
| Deploy ID | `0AfdL00000eN0rVSAS` |
| デプロイテスト | 31/31 Pass |
| 関連回帰テストRun ID | `707dL00001GNOVOQA5` |
| 関連回帰テスト | 46/46 Pass |
| `Mig_FreeeInvoiceProductResolver` | 90% |
| `Mig_FreeeInvoiceWorkService` | 83% |
| `Mig_FreeeInvoiceFinalizeService` | 85% |
| `FreeeInvoiceContractProvisioningService` | 91% |
| 総合判定 | Pass |

### テストパターン

| No | パターン | 期待結果 | 結果 |
|---|---|---|---|
| 1 | 過去の確定明細と明細名・単価・数量・金額が完全一致 | 商品を自動確定する | Pass |
| 2 | 同じ履歴条件に複数商品が存在 | 商品を推測せず要確認とする | Pass |
| 3 | 金額・数量がない備考行 | 請求対象外として自動除外する | Pass |
| 4 | 主要商品が1件だけの値引き・調整行 | 主要商品へ自動紐づけする | Pass |
| 5 | 再取込時にfreeeから削除された未反映明細 | 古い明細Workを削除する | Pass |
| 6 | 反映済みWorkを再取込 | 反映済みステータスと作成済み請求を維持する | Pass |
| 7 | 税込入力・端数あり | 税抜金額と税額を請求合計へ整合させる | Pass |
| 8 | 年払いで商品マスタの年契約月額料金が未設定 | 請求明細の税抜純額を12分割して月次売上を作る | Pass |
| 9 | 既存契約期間と新規期間が重複 | 新規期間を作成せず要確認とする | Pass |
| 10 | 月次明細候補が複数 | 先頭レコードへ誤って関連請求を設定しない | Pass |
| 11 | 月次明細に別の関連請求が設定済み | 既存の関連請求を上書きしない | Pass |

## 2026-07-28 prodリリース・要確認Work再検証

### リリース結果

| 項目 | 結果 |
|---|---|
| DeploymentSettingsリリース | `0AfRB000001RHfJ0AW`、1/1成功、3/3テストPass |
| dev1再検証 | `0AfdL00000eN40fSAC`、36/36成功、31/31テストPass |
| prod dry-run | `0AfRB000001RHll0AG`、36/36成功、31/31テストPass |
| prodクイックリリース | `0AfRB000001RHtp0AG`、36/36成功 |
| 定期ジョブ | 3件とも停止・削除せず `WAITING` を維持 |
| 総合判定 | Pass |

### データ処理結果

| 項目 | 処理前 | 処理後 | 増減 |
|---|---:|---:|---:|
| 今回対象の要確認Work | 34件 | 29件 | -5件 |
| 今回対象の反映済みWork | 0件 | 5件 | +5件 |
| 今回反映した請求金額 | 0円 | 2,069,100円 | +2,069,100円 |
| Work全体の反映済み | 242件 | 247件 | +5件 |
| Work全体の要確認 | 34件 | 29件 | -5件 |

5件のうち3件はSalesforce請求・請求明細を新規作成した。2件は同じfreee請求書IDのSalesforce請求が既に存在したため、重複作成せず既存請求へ紐づけた。既存2件はfreeeの年払い本体・割引の2行がSalesforceでは割引後の1行へ集約されていたため、請求総額・税額・数量・商品を照合したうえで明細Workを既存請求明細へ紐づけた。

### 残る要確認29件

| 内訳 | 件数 |
|---|---:|
| 契約・契約期間未解決、商品未確定 | 15件 |
| 契約・契約期間未解決 | 9件 |
| 契約・契約期間未解決、商品未確定、金額不一致 | 2件 |
| 商品未確定のみ | 1件 |
| 金額不一致のみ | 2件 |

残る29件は、商品・契約・契約期間が一意に確定しない、または請求金額と明細合計が一致しないため、自動反映しない安全判定を維持した。

## 2026-07-28 商品マスタ単価照合の改善

### 実装・リリース結果

| 項目 | 結果 |
|---|---|
| 照合ルール | `明細金額の絶対値 ÷ 数量`と商品マスタ単価が一意一致し、商品名シグナルも一致する場合のみ自動確定 |
| 移行請求明細の単価 | Work由来単価を保持し、商品マスタ単価による上書きを抑止 |
| dev1デプロイ | `0AfdL00000eNMopSAG`、23/23テストPass |
| prod dry-run | `0AfRB000001RMWv0AO`、23/23テストPass |
| prodデプロイ | `0AfRB000001RMbl0AG`、23/23テストPass |
| 総合判定 | Pass |

### 実データ確認

| Work | 明細 | 計算単価 | 確定商品 | 結果 |
|---|---|---:|---|---|
| `MFIW-000478` | 2000クレジット | 3,132,000 ÷ 12 = 261,000円 | `[年払] knock knock AI Enterpriseプラン 2000クレジット` | 自動確定 |
| `MFIW-000478` | クレジット単価割引 | -252,000 ÷ 12 = -21,000円 | 主商品と同じ年払2000クレジット | 自動確定 |
| `MFIW-000478` | 200クレジット返金 | -72,000 ÷ 3 = -24,000円 | `[月払] knock knock AI Enterpriseプラン 200クレジット` | 自動確定 |

`MFIW-000478`は「反映可能」まで進めた。解決先契約のMRR 93,500円・ARR 1,122,000円と請求明細純額2,808,000円に差があるため、請求の本反映は行わず、契約選択または金額変更の妥当性確認を残した。

## 2026-07-28 請求作成後の契約分類自動補完

| 項目 | 結果 |
|---|---|
| dev1デプロイ | `0AfdL00000eNzgTSAS`、26/26テストPass |
| prod dry-run | `0AfRB000001RMn30AG`、26/26テストPass |
| prodデプロイ | `0AfRB000001RMof0AG`、26/26テストPass |
| 請求明細作成後の分類補完 | Pass |
| 既存契約値を上書きしない | Pass |
| 年払12か月を12アカウントとして扱わない | Pass |
| Freee請求移行・通常単価同期の回帰 | Pass |

## 2026-07-28 取引の契約開始月・MRRレポート

| 項目 | 結果 |
|---|---|
| prod dry-run | `0AfRB000001ROwv0AG`、7/7資産成功 |
| prodデプロイ | `0AfRB000001ROyX0AW`、7/7資産成功 |
| `2026-09-01`の表示 | `2026/09`、Pass |
| `2027-04-01`の表示 | `2027/04`、Pass |
| 【営業】MRR(取引ベース) | `Opportunity__c.ContractStartMonth__c`で昇順グループ、Pass |
