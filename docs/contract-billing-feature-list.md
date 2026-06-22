# 契約・請求・Freee連携 機能一覧

## 1. 目的

本書は、契約・請求・Freee連携要件をSalesforce開発機能として洗い出したもの。
実装時に必要なオブジェクト、項目、リストビュー、Apex、バッチ、権限制御、テスト観点を整理する。
レポートは利用要件として定義するが、作成作業はユーザー側で行う。

## 2. 開発対象サマリ

| 区分 | 開発対象 |
| --- | --- |
| データモデル | 契約、契約期間、契約月次明細、請求、請求明細、商品マスタ、見積、見積明細、取引、イベント |
| 画面・UI | 契約ページ、請求ページ、請求明細ページ、契約期間ページ、契約月次明細ページ |
| リストビュー | 年契約更新確認、Freee連携エラー、決済待ち請求、送付待ち請求、取消請求、請求作成対象 |
| レポート | 月別売上予定、入金予定、未請求、決済待ち、MRR/ARR、契約更新予定、解約予定、イベント別売上、契約月次明細3種。作成はユーザー側で実施 |
| 自動化 | ボタン起動による初回作成、月契約更新、年契約更新、更新時Freee請求書自動作成、Freee送付・決済ステータス同期、取消処理 |
| Apex | 初回作成サービス、Freee APIクライアント、更新バッチ、Freee作成Queueable、ステータス同期バッチ、取消・再作成サービス、エラーハンドリング |
| 権限制御 | Freee連携済み請求・請求明細の編集制御、取消済みデータの編集制御 |
| 連携ログ | Freee請求書作成・同期・取消時のエラーログ |
| テスト | 月契約、年契約、初期費用、値引き、税額、Freee成功/失敗、取消、再作成、同期 |

## 3. オブジェクト機能

### 3.1 契約

既存またはカスタム契約オブジェクトを利用する。
継続契約の親として扱う。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 取引先 | 参照 | 請求先取引先 |
| 元取引 | 参照 | 受注元の取引 |
| 元見積 | 参照 | Activate見積 |
| イベント | 参照またはコピー項目 | 取引のイベント情報をレポート用に保持 |
| 契約種別 | 選択リスト | 月契約 / 年契約 |
| 契約ステータス | 選択リスト | 有効 / 終了 / 取消 / 切替済み等 |
| 契約開始日 | 日付 | 契約開始日 |
| 契約終了日 | 日付 | 契約終了日 |
| 更新停止フラグ | チェックボックス | 自動更新停止 |
| 更新確認ステータス | 選択リスト | 未確認 / 更新予定 / 更新停止 / 条件変更あり |
| 支払方法 | 選択リスト | 請求書等 |
| 次回請求書作成予定日 | 日付 | バッチ対象判定・リスト表示 |
| MRR | 通貨 | レポート用 |
| ARR | 通貨 | レポート用 |

必要機能:

- 取引受注後に担当者が画面ボタンを押下し、対象契約を特定する。
- 契約種別により、契約期間・請求・請求明細の生成ルールを切り替える。
- 年契約は終了2か月前から更新確認リストビューに表示する。
- 更新停止フラグが true の契約は自動更新対象外にする。

### 3.2 契約期間

契約の更新単位。
月契約では1か月、年契約では1年を表す。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 契約 | 主従または参照 | 親契約 |
| 期間開始日 | 日付 | 対象期間開始 |
| 期間終了日 | 日付 | 対象期間終了 |
| 契約種別 | 数式またはコピー | 月契約 / 年契約 |
| 更新回数 | 数値 | 初回、2回目以降の判定 |
| 初回期間フラグ | チェックボックス | 初期費用請求判定 |
| 請求作成ステータス | 選択リスト | 未作成 / 作成済 / エラー / 取消済 |
| 関連請求 | 参照 | 作成された請求 |
| Freee連携ステータス | 選択リスト | 請求側の状態を参照しても可 |

必要機能:

- 初回作成時に契約種別に応じた期間を作成する。
- 月契約更新バッチで翌月分を作成する。
- 年契約更新バッチで次年度分を作成する。
- 同一契約・同一期間の重複作成を防止する。

### 3.3 契約月次明細

月別売上予定、MRR/ARR、商品別売上分析用。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 契約 | 参照 | 親契約 |
| 契約期間 | 主従または参照 | 対象期間 |
| 商品マスタ | 参照 | 商品別集計 |
| 見積明細 | 参照 | 生成元 |
| 対象年月 | テキストまたは日付 | 例: 2026-06 |
| 対象期間開始日 | 日付 | 月初 |
| 対象期間終了日 | 日付 | 月末 |
| 売上予定額 | 通貨 | 月別売上 |
| MRR対象フラグ | チェックボックス | MRR集計 |
| ARR対象フラグ | チェックボックス | ARR集計 |
| 初期費用フラグ | チェックボックス | 初回のみ |
| 関連請求 | 参照 | 請求済み確認 |

必要機能:

- 月契約は契約期間ごとに商品別で作成する。
- 年契約は12か月分の商品別明細を作成する。
- 初期費用は初月のみ作成する。
- 年契約の月額は商品マスタの年契約用月額料金を利用する。
- 契約月次明細レポートで決済状況を見られるよう、関連請求を必ず設定する。
- Freee請求書送付ステータス、決済ステータス、入金額、未入金額、入金日、Freee請求書情報は関連請求から参照する。

### 3.4 請求

Salesforce上の請求管理単位。
Freee請求書と1対1で対応する。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 契約 | 参照 | 親契約 |
| 契約期間 | 参照 | 対象期間 |
| 取引先 | 参照 | 請求先 |
| 請求名 | テキスト/自動採番 | Freee請求書タイトル |
| 請求日 | 日付 | 毎月20日、土日は前日 |
| 支払期日 | 日付 | 請求日の翌月末 |
| 請求対象期間開始日 | 日付 | 対象期間 |
| 請求対象期間終了日 | 日付 | 対象期間 |
| 請求金額 | 通貨 | Freee同期で上書き |
| 税額 | 通貨 | 10%、切り上げ |
| 税込金額 | 通貨 | 合計 |
| Freee請求書ID | テキスト | Freee一意ID |
| Freee請求書番号 | テキスト | Freee発番 |
| Freee請求書URL | URL | Freee画面URL |
| Freee連携ステータス | 選択リスト | 未連携 / 連携済 / 連携エラー |
| Freee請求書送付ステータス | 選択リスト | 送付待ち / 送付済み |
| 決済ステータス | 選択リスト | 決済待ち / 決済済み |
| 入金額 | 通貨 | Freee同期 |
| 未入金額 | 通貨 | Freee同期 |
| 最終同期日時 | 日時 | Freee同期日時 |
| 同期エラー内容 | ロングテキスト | エラー詳細 |
| 取消ステータス | 選択リスト | 通常 / 取消済 |
| 元請求 | 参照 | 取消後再作成時の元請求 |
| 社内メモ | ロングテキスト | Salesforce正 |

必要機能:

- 請求からFreee請求書を作成する。
- Freee請求書ID、番号、URLを保持する。
- Freee連携済み後は業務項目を編集不可にする。
- 取消時は物理削除せず取消ステータスにする。
- 取消後の再作成は新規請求を作成し、元請求を参照する。

### 3.5 請求明細

Freee請求書明細行に対応する。
商品マスタに紐づく。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 請求 | 主従または参照 | 親請求 |
| 商品マスタ | 参照 | 商品分析・商品別集計 |
| 見積明細 | 参照 | 生成元 |
| 明細名 | テキスト | Freee明細名 |
| 数量 | 数値 | 数量 |
| 単価 | 通貨 | 値引き前単価 |
| 値引き率 | パーセント | 見積明細由来 |
| 値引き後単価 | 通貨 | 単価 × 値引き率 |
| 金額 | 通貨 | 税抜金額 |
| 税率 | パーセント | 10% |
| 税額 | 通貨 | 切り上げ |
| 税込金額 | 通貨 | 合計 |
| 明細種別 | 選択リスト | 継続費用 / 初期費用 / 年間利用料 |
| Freee明細ID | テキスト | 必要に応じて |

必要機能:

- 月契約はサービスごとに1明細を作成する。
- 年契約は年間利用料1明細を作成する。
- 年契約の年間利用料1明細の明細名は「契約名 + 年払い費用」とする。
- 初期費用は初回のみ別明細として作成する。
- 値引きは商品単価に値引き率をかけて計算する。
- Freee連携済み後は編集不可にする。

### 3.6 商品マスタ

見積明細、契約月次明細、請求明細の生成元。
現行のFreee見積書・請求書連携では、商品マスタのFreee品目IDは使用しない。

主な項目:

| 項目 | 型 | 用途 |
| --- | --- | --- |
| 商品名 | テキスト | 表示名 |
| 商品コード | テキスト | 一意コード |
| 商品種別 | 選択リスト | 継続費用 / 初期費用 / オプション |
| 請求タイミング | 選択リスト | 毎月 / 年一括 / 初回のみ |
| 月額料金 | 通貨 | 月契約用 |
| 年額料金 | 通貨 | 年契約用 |
| 年契約月額料金 | 通貨 | 年契約の契約月次明細作成用 |
| MRR対象フラグ | チェックボックス | MRR対象 |
| ARR対象フラグ | チェックボックス | ARR対象 |
| 請求明細表示区分 | 選択リスト | 個別表示 / 年間利用料に集約 |
| 初回のみフラグ | チェックボックス | 初期費用判定 |

必要機能:

- 見積明細から請求明細・契約月次明細を作る際の判定元にする。
- 年契約では年契約月額料金を契約月次明細に使用する。
- 年契約では見積明細の商品マスタを請求明細に使用する。
- 年契約では商品マスタの年契約月額料金を契約月次明細に使用する。
- `AnnualBulkBillingProduct__c` と `AnnualMonthlyProduct__c` は現行ロジックで使用しないため、商品マスタ画面には表示しない。
- Freee連携では、請求明細名・数量・単価・税率を請求明細から送信する。
- 請求書連携では、請求のFreee勘定科目とFreee勘定科目マッピングから `account_item_id` を送信する。
- 商品マスタのFreee品目IDは現行連携では不要。将来Freee品目連携を行う場合のみ追加検討する。

## 4. リストビュー機能

### 4.1 契約リストビュー

| リストビュー | 条件 | 用途 |
| --- | --- | --- |
| 年契約_更新確認対象 | 契約種別 = 年契約、契約終了日が今日から2か月以内、更新停止フラグ = false | 更新前確認 |
| 自動更新停止契約 | 更新停止フラグ = true | 更新停止管理 |
| 契約切替予定 | 契約ステータス = 切替予定 | アップセル・切替管理 |
| 解約予定契約 | 契約ステータス = 解約予定 | 解約管理 |
| アップセル適用予定 | 契約ステータス = 切替予定、切替適用月 = 翌月 | 翌月アップセル確認 |

### 4.2 請求リストビュー

| リストビュー | 条件 | 用途 |
| --- | --- | --- |
| Freee連携エラー | Freee連携ステータス = 連携エラー | エラー対応 |
| 決済待ち請求 | 決済ステータス = 決済待ち | 決済確認 |
| 送付待ち請求 | Freee請求書送付ステータス = 送付待ち | 送付確認 |
| 取消済み請求 | 取消ステータス = 取消済 | 履歴確認 |
| Freee未連携請求 | Freee連携ステータス = 未連携 | 手動連携確認 |
| 今月請求 | 請求日 = 今月 | 請求確認 |

### 4.3 契約期間リストビュー

| リストビュー | 条件 | 用途 |
| --- | --- | --- |
| 請求未作成期間 | 請求作成ステータス = 未作成 | 作成漏れ確認 |
| 請求作成エラー期間 | 請求作成ステータス = エラー | エラー確認 |
| 今月開始期間 | 期間開始日 = 今月 | 契約期間確認 |

## 5. レポート機能

| レポート | 主オブジェクト | 内容 |
| --- | --- | --- |
| 月別売上予定 | 契約月次明細 | 対象年月別、商品別、取引先別の売上予定 |
| 入金予定 | 請求 | 請求日・支払期日別の請求金額 |
| 未請求一覧 | 契約期間 / 契約月次明細 | 請求未作成の対象確認 |
| 決済待ち一覧 | 請求 | 決済待ちの請求 |
| MRR | 契約月次明細 | MRR対象商品の月次売上 |
| ARR | 契約月次明細 | ARR対象商品の年換算売上 |
| 契約更新予定 | 契約 | 契約終了日、更新確認ステータス別 |
| 解約予定 | 契約 | 解約予定・更新停止契約 |
| イベント別受注 | 取引 | イベント別の受注金額 |
| イベント別売上 | 契約月次明細 | 契約にコピーしたイベント情報で集計 |
| Freee連携エラー | 請求 | エラー内容・最終同期日時 |
| 契約月次明細(営業) | 契約月次明細 | MRRグラフ、すべての過去金額、解約後も金額を変更せず表示。関連請求の決済ステータスも表示 |
| 契約月次明細(経理) | 契約月次明細 | 現在有効な契約、過去2か月分の決済済み明細のみ表示。関連請求の入金日・入金額も表示 |
| 契約月次明細(解約) | 契約月次明細 | 本来獲得できる予定だった契約と金額。関連請求がある場合は決済ステータスも表示 |

必要なカスタムレポートタイプ:

```text
契約 with 契約期間
契約 with 契約期間 with 契約月次明細
契約月次明細 with 請求
契約 with 契約期間 with 請求
請求 with 請求明細
取引 with 見積 with 見積明細
イベント with 取引
```

## 6. 自動化・Apex機能

### 6.1 受注時初回作成

起動:

```text
担当者が取引画面のボタンを押下したとき
```

処理:

```text
1. Activate見積を取得する
2. Activate見積が0件ならエラー
3. Activate見積が複数ならエラー
4. 対象契約を特定する
5. 初回契約期間を作成する
6. 契約月次明細を作成する
7. 請求を作成する
8. 請求明細を作成する
9. 担当者が請求明細・商品などを確認/補正する
10. 担当者が請求画面のボタンからFreee請求書を手動作成する
11. Freee情報を請求に保存する
```

初回請求対象:

```text
当月分から請求する。
契約作成日が契約開始月より後の場合も、契約開始月分を初回請求対象とする。
```

想定Apex:

```text
OppContractInvoiceController
OppContractInvoiceService
FreeeInvoiceService
```

実装済みApex:

```text
OppContractInvoiceController
OppContractInvoiceService
FreeeInvoiceFacade
FreeeInvoiceService
```

契約月次明細と請求の紐づけ:

```text
請求作成後、対象となる契約月次明細の関連請求に作成済み請求を設定する。
年契約の場合は、12か月分の契約月次明細が同じ年一括請求を参照する。
月契約の場合は、対象月の契約月次明細が月次請求を参照する。
```

アップセル時の契約切替処理:

```text
1. 旧契約を終了する
2. 新契約を作成する
3. 旧契約と新契約を関連付ける
4. 翌月から新契約を請求対象にする
5. 作成済み請求は削除しない
6. 決済待ち請求も削除せず、そのまま残す
7. 請求取消・再作成などの自動処理は行わない
8. 必要な請求調整がある場合は、運用判断で手動対応する
9. 日割り計算はしない
```

### 6.2 月契約更新バッチ

スケジュール:

```text
毎月11日 2:00
```

処理:

```text
MRR/ARR・将来売上レポート用の契約月次明細は、`ContractMonthlyLineBatch` が毎月11日深夜に先行作成する。
請求・請求明細・Freee請求書はSalesforce側の更新請求バッチでは作成せず、freee側の自動作成・自動送付を正とする。
freee請求書取込後、対象となる契約月次明細の関連請求を更新する。
同一契約・同一期間の契約期間が存在する場合は作成しない。
```

対象:

```text
契約種別 = 月契約
契約ステータス = 有効
更新停止フラグ = false
```

想定Apex:

```text
ContractRenewalInvoiceBatch
FreeeInvoiceCreateQueueable
FreeeInvoiceFacade
```

### 6.3 年契約更新バッチ

スケジュール:

```text
毎月11日 2:00
```

処理:

```text
次年度分の契約月次明細は、次年度契約開始月の前月11日深夜に `ContractMonthlyLineBatch` が先行作成する。
請求・請求明細・Freee請求書はSalesforce側の更新請求バッチでは作成せず、freee側の自動作成・自動送付を正とする。
freee請求書取込後、年一括請求に対応する12か月分の契約月次明細へ関連請求を設定する。
同一契約・同一期間の契約期間が存在する場合は作成しない。
```

対象:

```text
契約種別 = 年契約
契約ステータス = 有効
更新停止フラグ = false
次年度契約開始月の前月11日に該当
```

想定Apex:

```text
ContractRenewalInvoiceBatch
FreeeInvoiceCreateQueueable
FreeeInvoiceFacade
```

### 6.4 Freee請求書作成

処理:

```text
1. 請求・請求明細を取得する
2. Freee請求書作成APIを呼び出す
3. 成功時はFreee請求書ID、番号、URLを保存する
4. 失敗時はFreee連携ステータス = 連携エラー、同期エラー内容を保存する
5. 失敗時は画面上にエラーメッセージを表示する
6. 失敗時はFreee連携ログを作成する
7. 自動リトライ、手動リトライは行わない
```

想定Apex:

```text
FreeeInvoiceClient
FreeeInvoiceService
FreeeAuthService
FreeeRequestBuilder
FreeeResponseParser
FreeeIntegrationLogService
```

実装済みApex:

```text
FreeeInvoiceController
FreeeInvoiceFacade
FreeeInvoiceMapper
FreeeInvoiceService
FreeeConfigService
FreeeSyncLogService
```

### 6.5 Freee送付・決済ステータス同期

スケジュール:

```text
毎日 2:00
```

対象:

```text
決済ステータス != 決済済み
Freee連携ステータス = 連携済
取消ステータス != 取消済
```

処理:

```text
1. 決済待ちの請求を取得する
2. Freeeから請求書の送付ステータス・決済ステータスを取得する
3. 金額、支払期日、送付ステータス、決済ステータス、入金額、未入金額をSalesforceへ上書きする
4. 最終同期日時を更新する
5. 失敗時は同期エラー内容を保存する
```

想定Apex:

```text
FreeeInvoiceStatusSyncBatch
FreeeInvoiceStatusSyncService
```

### 6.6 請求取消・再作成

処理:

```text
1. Salesforce請求を取消ステータスにする
2. Freee請求書を取消・キャンセル扱いにする
3. 契約期間の請求作成ステータスを取消済みにする
4. 再作成時は新規請求を作成し、元請求を参照する
```

想定Apex:

```text
InvoiceCancelService
InvoiceRecreateService
FreeeInvoiceCancelService
```

実装済みApex / 画面:

```text
InvoiceActionController
invoiceCancelAction
invoiceRecreateAction
Invoice__c.InvoiceCancelAction
Invoice__c.InvoiceRecreateAction
```

### 6.7 手動操作

必要なクイックアクションまたは画面アクション:

```text
Freee請求書作成
請求取消: 実装済み
請求再作成: 実装済み
送付・決済ステータス再同期
```

## 7. Flow / Validation / Trigger整理

推奨方針:

```text
複雑な生成処理・外部連携はApexで実装する。
入力補助や単純な項目コピーはFlowで実装可能。
編集制御はValidation RuleまたはApex Triggerで実装する。
```

候補:

| 種別 | 機能 |
| --- | --- |
| Record-Triggered Flow | 取引イベント情報を契約へコピー |
| Record-Triggered Flow | 契約の次回請求書作成予定日算出 |
| Validation Rule | Freee連携済み請求の業務項目編集不可 |
| Validation Rule | Freee連携済み請求明細の編集不可 |
| Validation Rule | 取消済み請求の編集不可 |
| Apex Trigger | 請求取消時の整合性制御 |

現行実装では、初回作成は取引画面のボタン起動とし、取引受注時のApex Triggerは使用しない。
請求取消時の整合性制御はApex Triggerではなく、`InvoiceCancelService` から契約期間・契約月次明細を更新する。

## 8. エラー制御

必要なエラー管理:

```text
Activate見積が存在しない
Activate見積が複数存在する
対象契約が存在しない
見積明細が存在しない
請求にFreee勘定科目がない、またはFreee勘定科目マッピングがない
商品マスタの料金設定が不足している
契約期間が重複している
請求が重複している
Freee請求書作成に失敗した
Freee送付・決済ステータス同期に失敗した
Freee請求書取消に失敗した
```

推奨オブジェクト:

```text
Freee連携ログ
```

主な項目:

```text
関連請求
処理種別
ステータス
リクエスト概要
レスポンス概要
エラーメッセージ
実行日時
実行ユーザ
```

## 9. 権限・セキュリティ

権限制御:

```text
Freee連携前: 請求・請求明細は編集可能
Freee連携済み: 業務項目は編集不可
Freee連携済み: 社内メモのみ編集可能
Freee連携エラー: 修正に必要な項目のみ編集可能
取消済み: 編集不可、社内メモのみ編集可能
```

通知方針:

```text
基本通知は行わない。
Freee連携エラー、年契約更新確認、決済待ち、送付待ち、請求取消、Activate見積複数エラーはリストビューまたはレポートで確認する。
```

必要な権限セット案:

```text
契約請求管理者
契約請求担当者
請求参照のみ
Freee連携管理者
```

## 10. 設定・メタデータ

設定化したい値:

```text
請求締め日: 10日
請求書作成日: 11日
請求日: 20日
支払期日: 請求日の翌月末
月契約更新バッチ実行時刻: 毎日 2:00に起動し、11日のみ作成処理を実行
年契約更新バッチ実行時刻: 毎日 2:00に起動し、11日のみ作成処理を実行
Freee送付・決済ステータス同期バッチ実行時刻: 毎日 3:00
税率: 10%
税端数処理: 切り上げ
Freee APIエンドポイント
Freee事業所ID
Freee認証情報参照
```

推奨:

```text
カスタムメタデータ型で管理する。
```

候補カスタムメタデータ:

```text
Billing_Setting__mdt
Freee_Integration_Setting__mdt
```

## 11. テストクラス

想定テストクラス:

```text
ContractBillingInitialCreationServiceTest
ContractPeriodServiceTest
ContractMonthlyDetailServiceTest
InvoiceCreationServiceTest
InvoiceLineCreationServiceTest
ContractRenewalInvoiceBatchTest
FreeeInvoiceServiceTest
FreeeInvoiceStatusSyncBatchTest
InvoiceCancelServiceTest
InvoiceRecreateServiceTest
```

実装済みテストクラス:

```text
OppContractInvoiceServiceTest
ContractRenewalInvoiceBatchTest
FreeeInvoiceStatusSyncBatchTest
InvoiceCancelRecreateServiceTest
```

主要テストケース:

```text
月契約の初回作成
年契約の初回作成
月途中開始で日割りなし
初期費用が初回のみ作成される
初期費用が更新時に除外される
値引き率が請求明細に反映される
税額が10%切り上げで計算される
Activate見積が0件の場合エラー
Activate見積が複数の場合エラー
月契約の毎月11日更新
年契約の次年度契約開始月前月11日更新
Freee請求書作成成功
Freee請求書作成失敗
Freee連携ログ作成
決済待ち請求のみ同期対象になる
Freee同期で金額・支払期日・ステータスが上書きされる
請求取消
取消後再作成
Freee連携済み請求の編集不可
Freee連携済み請求明細の編集不可
```

## 12. 実装順序案

1. オブジェクト・項目・リレーション作成
2. 商品マスタ項目整備
3. リストビュー作成
4. 請求・請求明細生成ロジック実装
5. 契約期間・契約月次明細生成ロジック実装
6. ボタン起動による初回作成処理実装
7. 月契約更新バッチ実装
8. 年契約更新バッチ実装
9. 更新時Freee請求書自動作成連携実装
10. Freee送付・決済ステータス同期バッチ実装
11. 取消・再作成処理実装
12. 権限制御・Validation Rule実装
13. テストクラス作成
14. UAT
## 13. Freee取引先一括同期機能

取引先リストビューで選択した複数取引先を一括でFreee取引先同期する。

開発対象:

| 種別 | API名 / 名称 | 内容 |
| --- | --- | --- |
| Apex | `FreeePartnerBulkSyncService` | 複数取引先のFreee検索・作成・Salesforce取引先ID保存を行う一括同期サービス |
| Apex | `FreeePartnerBulkSyncController` | 取引先リストビュー選択レコードを受け取り、一括同期サービスを呼び出すVisualforce拡張コントローラ |
| Visualforce | `FreeePartnerBulkSync` | 一括同期の実行結果画面。対象件数、成功、スキップ、失敗、レコード別メッセージを表示 |
| WebLink/List Button | `Account.FreeePartnerBulkSync` | 取引先リストビュー用の「Freee取引先一括同期」ボタン |
| Search Layout | `Account.searchLayouts.listViewButtons` | 取引先リストビューに一括同期ボタンを表示 |
| Permission Set | `SAMURAI_Sales_Contract_User` | 営業ユーザーに一括同期Apex/Visualforceアクセスを付与 |
| Permission Set | `SAMURAI_Contract_Billing_User` | 経理ユーザーに一括同期Apex/Visualforceアクセスを付与 |
| Permission Set | `SAMURAI_System_Admin` | システム管理者に一括同期Apex/Visualforceアクセスを付与 |
| Profile | `Admin` | 管理者プロファイルに一括同期Apex/Visualforceアクセスを付与 |
| Test | `FreeePartnerBulkSyncServiceTest` | 新規作成、既存Freee取引先利用、設定済みIDスキップ、Visualforceコントローラ、50件超過エラーを検証 |

処理仕様:

- 最大50件/回まで同期可能。
- `Account.Freee_Partner_Id__c` 設定済みの取引先はスキップ。
- 未設定の取引先はFreee取引先検索を行い、完全一致があれば既存IDを保存。
- 完全一致がなければFreee取引先を作成し、返却されたIDを保存。
- 一括処理中は先にFreee APIコールアウトを行い、最後にSalesforce取引先を一括更新する。これにより、DML後コールアウトエラーを回避する。
- レコード別の成功・失敗を結果画面に表示し、1件の失敗で他レコードの同期を止めない。
## 契約期間・請求関連の設計方針

### 契約期間から請求を確認する機能

契約期間に紐づく請求の正本は `Invoice__c.ContractPeriod__c` とする。契約期間画面には請求関連リストを表示し、同一契約期間に紐づくすべての請求を確認できるようにする。

`ContractPeriod__c.RelatedInvoice__c` は代表請求として扱う。通常は作成済みの有効請求を設定する。請求取消後に請求を再作成した場合は、代表請求を再作成後の新しい請求へ更新する。

契約月次明細の `RelatedInvoice__c` は、契約月次明細レポートで請求・入金状態を確認するために使用する。請求再作成時は、対象の契約月次明細の関連請求も再作成後の新しい請求へ更新する。

### Apex処理

`InvoiceRecreateService` は、取消済み請求から新規請求を再作成した後、以下を更新する。

- 契約期間の代表請求
- 契約月次明細の関連請求

これにより、契約期間の請求関連リストには取消済み請求と再作成後請求の両方が残り、代表請求と契約月次明細レポートは最新有効請求を参照する。

## レポート機能の整理

レポートは、計画データと実績データを分けて作成する。

| 区分 | 主オブジェクト | 目的 | 主な利用者 |
| --- | --- | --- | --- |
| 予定系 | 契約月次明細 | 将来売上、MRR、ARR、商品別売上予定を見る | 営業 |
| 実績系 | 請求 | Freee連携、送付、決済、入金、取消を見る | 経理 |
| 突合系 | 契約月次明細 | 売上予定に対する請求作成・送付・決済状態を見る | 営業 / 経理 / 管理者 |

### 契約月次明細レポートタイプ

契約月次明細レポートタイプには、関連請求から参照する以下の数式項目を含める。

| 項目 | API名 | 用途 |
| --- | --- | --- |
| 関連請求 送付ステータス | `RelatedInvoiceFreeeInvoiceStatus__c` | Freee請求書の送付待ち/送付済み確認 |
| 関連請求 決済ステータス | `RelatedInvoicePaymentStatus__c` | 決済待ち/決済済み確認 |
| 関連請求 入金日 | `RelatedInvoicePaymentReceivedDate__c` | 入金日確認 |
| 関連請求 Freee連携ステータス | `RelatedInvoiceFreeeSyncStatus__c` | Freee連携エラー確認 |
| 関連請求 取消ステータス | `RelatedInvoiceCancelStatus__c` | 取消済み請求の識別 |

契約月次明細ベースのレポートでは、売上予定金額、MRR、ARRを集計対象とする。請求金額、入金額、未入金額は同一請求が複数の契約月次明細から参照される場合に重複集計されるため、契約月次明細ベースでは集計しない。

### 請求レポートタイプ

請求レポートタイプは経理向けの実績確認に使用する。未送付、未入金、入金予定、Freee連携エラー、取消済み請求、今月請求一覧は請求を主オブジェクトにして作成する。

### 必要レポート

| レポート | 主オブジェクト | 表示・集計内容 |
| --- | --- | --- |
| 月別売上予定 | 契約月次明細 | 月別の売上予定金額 |
| MRR | 契約月次明細 | MRR対象商品の売上予定 |
| ARR | 契約月次明細 | ARR対象商品の売上予定 |
| 契約月次明細(営業) | 契約月次明細 | 将来売上、関連請求、送付ステータス、決済ステータス |
| 月次売上予定・請求状態一覧 | 契約月次明細 | 売上予定と請求状態の突合 |
| 未送付請求一覧 | 請求 | 送付待ち請求 |
| 未入金請求一覧 | 請求 | 決済待ち請求 |
| 入金予定 | 請求 | 支払期日、未入金額 |
| Freee連携エラー一覧 | 請求 | Freee連携失敗請求 |
| 取消済み請求一覧 | 請求 | 取消済み請求、元請求 |

### ダッシュボード

| 種別 | API名 | 表示名 | 主な構成レポート |
| --- | --- | --- | --- |
| Dashboard | `SalesContractDashboard` | 営業用 契約売上ダッシュボード | `DashMonthlyRevenueForecastChart`, `DashMRRChart`, `DashARRChart`, `DashContractRenewalScheduleChart` |
| Dashboard | `AccountingBillingDashboard` | 経理用 請求管理ダッシュボード | `DashPaymentWaitingInvoicesChart`, `DashUnsentInvoicesChart`, `DashPaymentScheduleChart`, `DashFreeeErrorInvoicesChart`, `DashCanceledInvoicesChart` |

旧 `ContractBillingOverview` は営業・経理のグラフが混在するため削除対象とする。Home FlexiPage の埋め込みダッシュボードは、営業用・経理用ダッシュボードへ差し替える。

### 削除対象レポート

| API名 | 理由 |
| --- | --- |
| `MonthlyDetailCancellation` | 解約確認は契約ライフサイクル/解約予定レポートで確認し、契約月次明細ベースの請求実績確認と混在させないため |
## 追記: freee請求書取込機能

### Apex

| 機能 | 資産 | 内容 |
|---|---|---|
| freee請求書通常取込Service | `FreeeInvoiceImportService` | 通常運用の対象期間を計算し、既存のfreee請求書取得バッチを起動する |
| freee請求書通常取込Scheduler | `FreeeInvoiceImportScheduler` | 夜間スケジュール実行用の入口 |
| freee請求書手動取込Controller | `FreeeInvoiceImportManualController` | Visualforce画面から対象期間を指定して取込を起動する |
| freee請求書Work一括本反映Controller | `FreeeInvoiceWorkBulkActionController` | リストビューで選択したWorkを請求・請求明細へ本反映する |

### 画面・ボタン

| 機能 | 配置先 | 内容 |
|---|---|---|
| freee請求書を取込 | `Mig_FreeeInvoiceWork__c` リストビュー | freee請求書を取得してWorkへ保存する |
| freee請求書を再検証 | `Mig_FreeeInvoiceWork__c` リストビュー | Workの参照解決・検証結果を再確認する |
| freee請求書を一括本反映 | `Mig_FreeeInvoiceWork__c` リストビュー | `反映可能` のWorkをSalesforce請求へ反映する |

### バッチ運用

| バッチ | 方針 | 理由 |
|---|---|---|
| `ContractMonthlyLineBatch` | 継続 | MRR/ARR・将来売上レポート用の契約月次明細を先に作成するため |
| `ContractRenewalInvoiceBatch` | 停止 | Salesforceで請求・請求明細・Freee請求書まで作成する旧更新請求バッチであり、freee自動作成・自動送付と二重請求になるため |
| `FreeeInvoiceImportScheduler` | 新規利用 | freeeで作成された請求書をSalesforceへ取り込むため |
| `FreeeInvoiceStatusSyncBatch` | 継続 | freee送付ステータス・決済ステータスを同期するため |

通常運用の作成順序:

```text
1. ContractMonthlyLineBatch が契約月次明細を作成
2. freee側で請求書を自動作成・自動送付
3. FreeeInvoiceImportScheduler または手動取込でfreee請求書をWorkへ取込
4. Work検証・本反映でInvoice__c / InvoiceLine__cを作成または更新
5. 対象契約期間内の契約月次明細 RelatedInvoice__c を更新
6. FreeeInvoiceStatusSyncBatch が送付ステータス・決済ステータスを同期
```

## 追記: freee取込・金額同期の最新機能（2026-06-23更新）

### 更新対象機能

| 区分 | 資産 | 内容 |
|---|---|---|
| Apex Service | `Mig_FreeeInvoiceWorkService` | freee請求取込Work作成時に、請求金額、税額、入金額、未入金額を設定する |
| Apex Batch | `FreeeInvoiceStatusSyncBatch` | Salesforce請求の送付ステータス、決済ステータス、金額系項目をfreeeから日次同期する |
| Apex Service | `FreeeInvoiceStatusSyncService` | 決済ステータスと請求金額から、入金額・未入金額を統一ルールで算出する |
| Apex Test | `Mig_FreeeInvoiceMigrationTest` | freee取込時の税額、入金額、未入金額の設定を検証する |
| Apex Test | `FreeeInvoiceStatusSyncBatchTest` | 日次同期時の金額更新を検証する |
| Apex Script | `scripts/apex/backfill-freee-invoice-amounts.apex` | 既存請求・既存Workの入金額、未入金額を一度だけ補正する |
| Schedule Script | `scripts/apex/schedule-contract-billing-batches.apex` | 通常運用で必要なバッチのみを登録し、旧更新請求バッチを停止する |
| Check Script | `scripts/check-contract-billing-release-readiness.ps1` | 権限、Apex資産、スケジュール登録状況、旧バッチ停止状態を確認する |

### 金額同期仕様

| 項目 | 実装仕様 |
|---|---|
| 請求金額 | freee請求書の請求金額をSalesforceへ保持 |
| 税額 | freee請求書ヘッダー税額を優先。取得不可の場合は明細税額合計 |
| 入金額 | 決済ステータスが「決済済み」の場合は請求金額、それ以外は0 |
| 未入金額 | 決済ステータスが「決済待ち」の場合は請求金額、それ以外は0 |

### スケジュール対象

| バッチ | 状態 | 理由 |
|---|---|---|
| `ContractMonthlyLineBatch` | 有効 | 契約月次明細を毎月11日深夜に作成し、MRR/ARR・将来売上を維持するため |
| `FreeeInvoiceImportScheduler` | 有効 | freee自動作成・自動送付済み請求書をSalesforceへ取り込むため |
| `FreeeInvoiceStatusSyncBatch` | 有効 | freee側の送付ステータス・決済ステータス・金額情報をSalesforceへ反映するため |
| `ContractRenewalInvoiceBatch` | 停止 | Salesforce起点の更新請求作成はfreee自動作成と二重請求になるため |

### 月次明細作成バッチの障害耐性

| 機能 | 実装仕様 |
|---|---|
| 不備契約の扱い | 請求または既存契約月次明細がない契約はスキップし、他契約の月次明細作成を継続する |
| Activated時処理 | 作成元情報がない場合でも契約更新自体は失敗させない |
| Scheduled実行 | 同一スコープ内に不備契約が含まれても、作成可能な契約は処理する |
| テスト | `ContractMonthlyLineBatchTest` で不備契約スキップ、正常契約継続処理を検証する |
