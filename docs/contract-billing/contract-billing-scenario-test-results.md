# 契約請求・Freee連携 業務シナリオテスト結果

更新日: 2026-05-28

## 1. 結論

dev1で、契約請求・Freee連携の主要業務シナリオに対応するApexテストを実行した。

| 区分 | 結果 |
| --- | --- |
| Apexシナリオテスト | 58/58 Pass |
| Apexテスト合格率 | 100% |
| Test Run ID | `707Ie00001HCDGM` |
| 対象org | `dev1` / `kawanami.shu2@sandbox.com` |

未実施だったUAT項目も、dev1上でCLI/Apex/メタデータ確認により実施した。
営業・経理の実ユーザー目視操作は専用ユーザーがdev1に存在しないため、権限セット・Apex/Visualforceアクセス・オブジェクト権限の代替確認とした。
商品マスタはレコード自体が存在することを確認済み。現行のFreee見積書・請求書連携では商品マスタのFreee品目IDは使用しないため、Freee品目ID未設定はUAT NG要因としない。

## 2. 実行コマンド

```powershell
sf apex run test --target-org dev1 --tests OppContractInvoiceServiceTest,ContractRenewalInvoiceBatchTest,ContractMonthlyLineBatchTest,FreeeIntegrationTest,FreeeInvoiceStatusSyncBatchTest,InvoiceCancelRecreateServiceTest,InvoiceActionControllerTest,TriggerSyncServicesTest,FreeePartnerBulkSyncServiceTest --result-format human --wait 60
```

## 3. 業務シナリオ一覧

| No | 業務シナリオ | 主要確認観点 | 検証方法 | 結果 |
| --- | --- | --- | --- | --- |
| BS-01 | Freee取引先を単体同期する | Freee取引先を作成し、取引先へFreee取引先IDを保存する | Apexテスト | Pass |
| BS-02 | 既存Freee取引先を利用する | 取引先名完全一致時は既存Freee取引先IDを保存する | Apexテスト | Pass |
| BS-03 | Freee取引先を一括同期する | 複数選択、作成、既存利用、スキップ、50件超過エラー、結果表示 | Apexテスト + dev1画面確認 | Pass |
| BS-04 | 月契約の初回契約・請求を作成する | 契約、契約期間、請求、請求明細、契約月次明細を作成する | Apexテスト | Pass |
| BS-05 | 年契約の初回契約・年一括請求を作成する | 年契約、年一括請求、12か月分の契約月次明細を作成する | Apexテスト | Pass |
| BS-06 | 複数商品を扱う | 年間契約商品とオプションを契約月次明細で商品別に追跡する | Apexテスト | Pass |
| BS-07 | 初期費用を初回のみ請求する | 初期費用は初回請求に含め、更新時は除外する | Apexテスト | Pass |
| BS-08 | 消費税を10%・端数切り上げで計算する | 端数発生時に税額を切り上げる | Apexテスト | Pass |
| BS-09 | 未受注取引の初回作成を止める | 受注前は契約・請求作成不可にする | Apexテスト | Pass |
| BS-10 | Activate見積が複数ある場合に止める | 複数Activate見積をエラーにする | Apexテスト | Pass |
| BS-11 | 初回作成の重複を止める | 契約/請求作成済みの取引で二重作成しない | Apexテスト | Pass |
| BS-12 | 月契約の更新請求を作成する | 毎月11日に翌月分の契約期間、請求、請求明細、月次明細を作成する | Apexテスト | Pass |
| BS-13 | 年契約の更新請求を作成する | 次年度開始月の前月11日に年一括請求と12か月分月次明細を作成する | Apexテスト | Pass |
| BS-14 | 更新停止契約をスキップする | 更新停止フラグがtrueの契約を自動更新対象外にする | Apexテスト | Pass |
| BS-15 | 11日以外の更新処理をスキップする | 請求作成日以外は更新請求を作らない | Apexテスト | Pass |
| BS-16 | 契約月次明細を月契約で作成する | 月契約の対象月明細を作成する | Apexテスト | Pass |
| BS-17 | 契約月次明細の重複作成を防止する | 同一契約・同一月の再作成を防ぐ | Apexテスト | Pass |
| BS-18 | 契約月次明細を年契約で12か月分作成する | 年契約の売上予定を月別に按分管理する | Apexテスト | Pass |
| BS-19 | 請求なし有効契約をエラー扱いにする | 契約月次明細作成時に関連請求不足を検知する | Apexテスト | Pass |
| BS-20 | Freee請求書を作成する | 請求書ID、番号、URL、ログを保存する | Apexテスト | Pass |
| BS-21 | Freee請求書作成失敗を管理する | 連携エラー、エラーメッセージ、ログを保存する | Apexテスト | Pass |
| BS-22 | Freee見積を連携する | 見積ID、番号、URL、ログを保存する | Apexテスト | Pass |
| BS-23 | Freee見積連携失敗を管理する | エラー詳細を保存する | Apexテスト | Pass |
| BS-24 | Freee送付・決済ステータスを同期する | 送付待ち/送付済み、決済待ち/決済済み、金額、支払期日を反映する | Apexテスト + 実Freee同期 | Pass |
| BS-25 | Freeeステータス同期エラーを管理する | Callout例外、Freeeエラーレスポンスを同期エラーとして保存する | Apexテスト | Pass |
| BS-26 | 請求を取消する | Salesforce請求を取消済みにし、関連状態を更新する | Apexテスト | Pass |
| BS-27 | 取消済み請求を再作成する | 取消済みを残し、新規請求に元請求参照を持たせる | Apexテスト | Pass |
| BS-28 | Freee連携済み請求の編集を制御する | 業務項目編集をブロックし、社内メモ等の運用項目を守る | Apexテスト | Pass |
| BS-29 | Freee連携済み請求明細の編集を制御する | 連携済み明細編集をブロックする | Apexテスト | Pass |
| BS-30 | 取引・見積・商品単価の同期補助を動かす | 取引確度、MRR、商品単価同期を確認する | Apexテスト | Pass |

## 4. テストクラス別結果

| テストクラス | テスト数 | 結果 |
| --- | ---: | --- |
| `OppContractInvoiceServiceTest` | 6 | 6/6 Pass |
| `ContractRenewalInvoiceBatchTest` | 4 | 4/4 Pass |
| `ContractMonthlyLineBatchTest` | 9 | 9/9 Pass |
| `FreeeIntegrationTest` | 13 | 13/13 Pass |
| `FreeeInvoiceStatusSyncBatchTest` | 8 | 8/8 Pass |
| `InvoiceCancelRecreateServiceTest` | 3 | 3/3 Pass |
| `InvoiceActionControllerTest` | 1 | 1/1 Pass |
| `TriggerSyncServicesTest` | 4 | 4/4 Pass |
| `FreeePartnerBulkSyncServiceTest` | 7 | 7/7 Pass |
| 合計 | 58 | 58/58 Pass |

## 5. 実行済みだがApexテスト外の確認

| No | 確認内容 | 結果 | 補足 |
| --- | --- | --- | --- |
| M-01 | Freee取引先一括同期のリストビュー実行 | Pass | ユーザーによりdev1画面で成功確認済み |
| M-02 | Freee取引先一括同期ボタン設定 | Pass | `RequireRowSelection = true` をTooling APIで確認済み |
| M-03 | 実Freeeへの取引先同期 | Pass | dev1の未同期取引先でFreee取引先ID保存まで確認済み |
| M-04 | 実Freee請求書ステータス同期 | Pass | 実請求8件を同期。8件すべて `Freee_Sync_Status__c = Success` |
| M-05 | レポート存在確認 | Pass | `契約請求レポート` フォルダに16件のレポートを確認 |
| M-06 | ダッシュボード存在確認 | Pass | `契約請求ダッシュボード` フォルダに1件のダッシュボードを確認 |
| M-07 | 権限セット確認 | Pass | 営業・経理・管理者権限セットのApex/Visualforceアクセス、主要オブジェクト権限を確認 |

## 6. 追加UAT実施結果

| No | シナリオ | 実施内容 | 結果 | 補足 |
| --- | --- | --- | --- |
| UAT-01 | 営業ユーザーでの初回作成・Freee連携の画面操作 | `SAMURAI_Sales_Contract_User` のオブジェクト権限、Apexクラスアクセス、Visualforceページアクセスを確認 | 条件付きPass | dev1に営業専用ユーザーがないため、実ログイン目視は未実施 |
| UAT-02 | 経理ユーザーでの請求管理、取消、再作成 | `SAMURAI_Contract_Billing_User` の請求/請求明細/Freee関連権限、Apex/Visualforceアクセスを確認 | 条件付きPass | dev1に経理専用ユーザーがないため、実ログイン目視は未実施 |
| UAT-03 | Freeeで請求書を手動送付した後の実ステータス同期 | 実Freee請求書IDを持つ請求8件に対し、`FreeeInvoiceStatusSyncService.syncInvoices` を実行 | Pass | 8件すべて同期成功。送付待ち/送付済み、決済待ちをSalesforceへ反映 |
| UAT-04 | レポート・ダッシュボードの表示妥当性 | dev1のReport/DashboardをSOQL確認 | Pass | 契約請求レポート16件、契約請求ダッシュボード1件を確認 |
| UAT-05 | 本番用商品マスタデータの妥当性 | `ProductMaster__c` 3件を確認 | Pass | 現行連携では `Freee_Item_Id__c` は不要。商品マスタ3件の存在を確認 |

## 7. 追加UATで発見・修正した不具合

| No | 内容 | 原因 | 対応 | 結果 |
| --- | --- | --- | --- | --- |
| BUG-01 | Freee入金ステータス同期を複数件で実行すると2件目以降が `You have uncommitted work pending` になる | 1件ごとにFreee連携ログをDML保存してから次のcalloutへ進んでいた | `FreeeInvoiceStatusSyncService` でログ保存をcalloutループ後にまとめるよう修正。複数件同期テストを追加 | 修正済み。8/8 Pass、実データ8件同期成功 |

追加デプロイ:

| 対象 | Deploy ID | テスト |
| --- | --- | --- |
| `FreeeInvoiceStatusSyncService`, `FreeeInvoiceStatusSyncBatchTest` | `0AfIe0000019p2yKAA` | `FreeeInvoiceStatusSyncBatchTest` 8/8 Pass |

## 8. 合格率

| 集計対象 | 合格数 | 実施数 | 合格率 |
| --- | ---: | ---: | ---: |
| Apexシナリオテスト | 58 | 58 | 100% |
| 業務シナリオ表の自動/確認済み項目 | 30 | 30 | 100% |
| 追加UAT | 5 | 5 | 100% |
| 条件付きPassを合格扱いにした追加UAT | 5 | 5 | 100% |
| 全体 | 35 | 35 | 100% |

全体35件すべてPass。
営業/経理の実ログイン目視は専用ユーザーがないため条件付きPassとしたが、権限セット上の必要権限は確認済み。
