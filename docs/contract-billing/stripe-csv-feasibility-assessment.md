# Stripeデータ Salesforce CSV投入フィジビリティ検証

## 1. 結論

添付された `customers.csv`、`subscriptions.csv`、`transactions.csv` は、Stripe内のCustomer、Subscription、Transactionの相互参照と金額照合には利用できる。

ただし、2026年8月5日時点のprodメタデータでは、Stripe IDを一意に保持する外部ID項目、Stripe Priceと商品マスタの対応、Stripe決済履歴オブジェクトが不足している。そのため、3ファイルを既存の取引先・契約・請求へ直接投入する方式は安全ではない。

現行のまま実施できるのは「既存取引先候補の特定」「契約候補データの作成」「決済データの照合」までである。契約月次明細、請求、請求明細まで自動投入するには、追加項目・Workオブジェクト・Stripe Invoice関連データが必要となる。

## 2. 検証条件

| 項目 | 内容 |
|---|---|
| 検証環境 | Salesforce prod |
| 実データ更新 | 未実施。Describe、SOQL、ローカルCSV解析のみ |
| customers.csv | 1件 |
| subscriptions.csv | 1件 |
| transactions.csv | 1件 |
| Stripe Customer ID | `cus_UtOiZAdkrEyAqn` |
| Stripe Subscription ID | `sub_1TtbutDiXC3f1UWkstdkHvCt` |
| Stripe Charge ID | `ch_3TtbusDiXC3f1UWk4RUOw6b3` |

## 3. CSV内部の整合性

| 確認項目 | 結果 | 判定 |
|---|---|---|
| Customer ID | 3ファイルで一致 | 合格 |
| 顧客メール | 3ファイルで一致 | 合格 |
| Subscription単価 | 8,800円 | 合格 |
| Quantity | 2 | 合格 |
| Subscription金額 | 8,800円 × 2 = 17,600円 | 合格 |
| Transaction金額 | 17,600円 | 合格 |
| 決済状態 | `Paid`、Captured=`true` | 合格 |
| 返金額 | 0円 | 合格 |
| Stripe Invoice ID | Transactionに存在 | 合格。ただしInvoice本体データなし |
| Product / Price | Price IDのみ | 不足 |
| Salesforce ID metadata | `orgId (metadata)`が空 | 不足 |

## 4. prod照合結果

| 対象 | prod確認結果 | 影響 |
|---|---|---|
| 取引先 | `株式会社SAMURAI ARCHITECTS`が1件存在 | 名称は類似するが完全一致ではない |
| 取引先責任者 | `yutayoko.prime@gmail.com`で横溝 裕太が1件存在 | ContactのAccountIdが空のため、取引先名寄せの確定根拠にはできない |
| 商品マスタ | 標準単価8,800円、17,600円とも0件 | Subscriptionから商品を確定できない |
| Account Stripe Customer ID | 項目なし | 再投入時の一意判定不可 |
| Contract Stripe Subscription ID | 項目なし | 同一Subscriptionの重複契約を防げない |
| Product Stripe Price ID | 項目なし | `price_...`と商品マスタを紐づけられない |
| Invoice Stripe Invoice ID | 項目なし | TransactionのInvoice IDから請求を特定できない |
| Stripe決済履歴 | 専用オブジェクトなし | 複数決済試行・返金履歴を保持できない |

`Contact.StripeAccountId__c`は存在するが、Stripe Customerを取引先単位で管理する用途には適さず、外部ID・一意項目でもない。

## 5. オブジェクト別フィジビリティ

| Salesforceオブジェクト | 元データ | 現状の可否 | 可能な範囲 | 主な阻害要因 |
|---|---|---|---|---|
| 取引先 `Account` | customers.csv | 条件付き | 既存候補1件を名称・メールで提示可能 | Stripe Customer外部ID項目なし、名称完全一致でない |
| 取引先責任者 `Contact` | customers.csv | 不可 | 既存メール候補の提示のみ | Customer CSVに担当者氏名なし。会社メールか個人メールか不明 |
| 商品マスタ `ProductMaster__c` | subscriptions.csv | 不可 | Price IDと金額の抽出のみ | Product名、Stripe Product ID、Price ID保持項目、該当商品がない |
| 取引 `Opportunity__c` | 3ファイル | 不可 | 受注済み候補の推定のみ | 流入経路、受注チャネル、取引名、営業担当等がない |
| 契約管理 `Contract__c` | subscriptions.csv | 条件付き | 月契約・CreditCard・Activatedの候補を作成可能 | Account・商品未確定、Subscription外部IDなし |
| 契約期間 `ContractPeriod__c` | subscriptions.csv | 条件付き | Current Period 1期間の作成候補 | Contract IDが先に必要。期間終了の変換ルールが必要 |
| 契約月次明細 `ContractLineItem__c` | subscriptions.csv | 不可 | 金額17,600円、数量2の候補まで | 商品マスタ未確定。契約Insertだけでは明細ソースがなく自動作成されない |
| 請求 `Invoice__c` | transactions.csv | 不可 | 決済金額・状態の照合のみ | Invoice本体、請求日、期日、税額、明細、Stripe Invoice外部IDがない |
| 請求明細 `InvoiceLine__c` | なし | 不可 | なし | Invoice Lineデータがない |
| Stripe決済 `StripePayment__c` | transactions.csv | 新規開発後に可能 | Charge、金額、返金、状態、日時を保持可能 | オブジェクト未作成 |

## 6. 既存自動処理への影響

### 6.1 契約管理

`Contract__c`は次の項目がInsert時に必要となる。

- `Account__c`
- `ContractUpdate__c`（月または年）

Stripeサンプルからは次の候補値を作れる。

| Salesforce項目 | 候補値 |
|---|---|
| ContractUpdate__c | 月 |
| Payment__c | CreditCard |
| Status__c | Activated |
| ContractNature__c | Recurring |
| StartDate__c | Stripe開始日時から業務タイムゾーンで日付化 |
| AccountCount__c | 2 |

ただし、Activated契約をInsertしても、請求明細または既存契約月次明細をテンプレートとして取得できない場合、現行トリガーは契約期間・契約月次明細を作成しない。商品マスタを確定し、初回明細を明示的に作成する必要がある。

### 6.2 請求

`Invoice__c`はAccountが必須で、既存Freee連携設計ではFreee勘定科目も必要となる。Stripe TransactionをInvoiceへ直接Insertすると、次の問題が起きる。

- Stripe Invoice IDを一意に保持できない。
- Stripe Chargeと請求を1対1と誤認する。
- Invoice Line、税額、請求対象期間を復元できない。
- Freee請求とStripe決済の責務が混在する。

したがって、Transactionは`StripePayment__c`へ格納し、Stripe Invoiceデータを取得後に`Invoice__c`へ紐づける。

## 7. 日時変換の注意

Stripe CSVはUTCである。DateTime項目には次の形式で投入する。

```text
2026-07-15T23:08:00.000Z
```

サンプルの`2026-07-15 23:08 UTC`は日本時間では`2026-07-16 08:08 JST`となる。SalesforceのDate項目へ変換する場合、UTC日付をそのまま使うか、日本時間の日付を使うかで1日ずれるため、日本時間を業務基準とすることを推奨する。

StripeのCurrent Period Endは次回課金時点を表すため、Salesforceで終了日を含むDateとして保持する場合は、業務タイムゾーン変換後の終了日から1日を引く。

## 8. 安全に投入するための最小追加開発

| 優先度 | 追加対象 | 内容 |
|---|---|---|
| 必須 | Account | `StripeCustomerId__c`：テキスト、外部ID、一意 |
| 必須 | Contract__cまたはStripeSubscription__c | Stripe Subscription ID：外部ID、一意 |
| 必須 | ProductMaster__c | `StripePriceId__c`：テキスト、外部ID、一意 |
| 必須 | Invoice__c | `StripeInvoiceId__c`：テキスト、外部ID、一意 |
| 必須 | StripePayment__c | Charge ID、Payment Intent ID、Invoice参照、金額、返金額、状態、決済日時 |
| 必須 | 移行Work | Customer、Subscription、Invoice、Invoice Line、Paymentの検証用Work |
| 必須 | 商品対応 | Stripe Product / Priceと商品マスタの対応表 |
| 推奨 | 名寄せ | Salesforce ID metadata、Stripe Customer ID、完全一致、要確認の順で判定 |
| 推奨 | 冪等性 | 外部ID Upsert、処理単位の件数・金額照合 |

## 9. 追加取得が必要なデータ

1. Stripe Products
2. Stripe Prices
3. Stripe Invoices
4. Stripe Invoice Line Items
5. Payment Intents
6. SubscriptionとInvoiceの関係
7. 顧客・申込担当者の氏名
8. Salesforce Account IDまたはOpportunity IDを保持したmetadata

## 10. 推奨投入順序

```text
Stripe CSV/API
  ↓
Stripe移行Work
  ↓ 名寄せ・商品・金額・日時・重複検証
Account
  ↓
Contract / StripeSubscription
  ↓
ContractPeriod
  ↓
ContractLineItem
  ↓
Invoice
  ↓
InvoiceLine
  ↓
StripePayment
```

本オブジェクトへの反映は外部IDUpsertを使用し、親オブジェクトの成功結果を確認してから子オブジェクトへ進む。

## 11. 最終判定

| 検証観点 | 判定 |
|---|---|
| CSVの文字コード・基本形式 | 合格 |
| Customer・Subscription・Transactionのキー整合 | 合格 |
| 金額整合 | 合格 |
| 既存取引先候補の特定 | 条件付き合格 |
| 商品マスタ特定 | 不合格 |
| 契約管理作成 | 条件付き合格 |
| 契約期間作成 | 条件付き合格 |
| 契約月次明細作成 | 現状不可 |
| 請求・請求明細作成 | 現状不可 |
| 決済履歴作成 | 新規オブジェクト作成後に可能 |
| 重複防止・再実行安全性 | 現状不可 |

総合判定は「技術的に実現可能だが、現行3CSVと現行Salesforceスキーマだけで本番直接投入することは不可」とする。
