# Salesforce × Stripe連携 構成図

## 1. 全体構成図

Salesforceを契約・請求・請求明細・MRR/ARRの正とし、Stripeを決済実行と決済結果通知の正とする構成です。

```mermaid
flowchart LR
    Customer["顧客"]
    Sales["営業"]
    Accounting["経理"]
    Admin["システム管理者"]

    subgraph SF["Salesforce"]
        Account["取引先<br/>Account"]
        Contract["契約管理<br/>Contract__c"]
        Period["契約期間<br/>ContractPeriod__c"]
        Monthly["契約月次明細<br/>ContractLineItem__c"]
        Invoice["請求<br/>Invoice__c"]
        InvoiceLine["請求明細<br/>InvoiceLine__c"]
        Product["商品マスタ<br/>ProductMaster__c"]
        StripeEvent["Stripeイベントログ<br/>StripeEvent__c"]
        StripeLog["Stripe連携ログ<br/>StripeSyncLog__c"]
    end

    subgraph Stripe["Stripe"]
        StripeCustomer["Customer"]
        Checkout["Checkout Session"]
        Payment["Payment Intent"]
        Refund["Refund"]
        Webhook["Webhook Event"]
    end

    Sales --> Account
    Sales --> Contract
    Accounting --> Invoice
    Admin --> StripeLog

    Account --> Contract
    Contract --> Period
    Contract --> Monthly
    Contract --> Invoice
    Invoice --> InvoiceLine
    InvoiceLine --> Product
    Monthly --> Product

    Account <--> StripeCustomer
    Invoice --> Checkout
    InvoiceLine --> Checkout
    Customer --> Checkout
    Checkout --> Payment
    Payment --> Webhook
    Refund --> Webhook
    Webhook --> StripeEvent
    StripeEvent --> Invoice
    StripeEvent --> StripeLog
```

## 2. 決済フロー図

Salesforceで請求を作成し、Stripe Checkout URLを顧客へ案内します。決済結果はStripe WebhookでSalesforceへ反映します。

```mermaid
sequenceDiagram
    actor Sales as 営業
    actor Customer as 顧客
    participant SF as Salesforce
    participant Stripe as Stripe
    actor Accounting as 経理

    Sales->>SF: 請求を作成・確認
    SF->>SF: 請求明細・商品マスタを確認
    Sales->>SF: Stripe決済URL作成ボタンを押下
    SF->>Stripe: Checkout Session作成
    Stripe-->>SF: Checkout URL / Session IDを返却
    SF-->>Sales: 決済URLを請求に保存
    Sales->>Customer: 決済URLを案内
    Customer->>Stripe: カード決済
    Stripe->>SF: Webhookで決済結果通知
    SF->>SF: 請求ステータス・入金額・決済日を更新
    SF-->>Accounting: 決済状況をレポート・リストビューで確認
```

## 3. Salesforceオブジェクト関連図

既存の契約請求基盤を活用し、Stripe連携に必要なID・URL・ステータスを既存オブジェクトへ追加します。

```mermaid
erDiagram
    Account ||--o{ Contract__c : "契約を持つ"
    Account ||--o{ Invoice__c : "請求先"
    Account ||--o| StripeCustomer : "Stripe顧客IDで紐づく"

    Contract__c ||--o{ ContractPeriod__c : "契約期間"
    Contract__c ||--o{ ContractLineItem__c : "月次売上予定"
    Contract__c ||--o{ Invoice__c : "請求実績"

    ContractPeriod__c ||--o{ ContractLineItem__c : "対象期間の月次明細"
    Invoice__c ||--o{ InvoiceLine__c : "請求明細"
    Invoice__c ||--o{ StripeEvent__c : "決済イベント"
    Invoice__c ||--o{ StripeSyncLog__c : "連携ログ"

    ProductMaster__c ||--o{ InvoiceLine__c : "請求商品"
    ProductMaster__c ||--o{ ContractLineItem__c : "MRR/ARR商品"

    Account {
        string Name
        string StripeCustomerId__c
        string StripeSyncStatus__c
    }

    Contract__c {
        string ContractName__c
        date StartDate__c
        date EndDate__c
        string ContractStatus__c
        string PaymentMethod__c
    }

    Invoice__c {
        string Name
        date BillingDate__c
        decimal BillingAmount__c
        string PaymentStatus__c
        string StripeCheckoutSessionId__c
        string StripePaymentIntentId__c
        string StripePaymentUrl__c
    }

    InvoiceLine__c {
        string Name
        decimal UnitPrice__c
        decimal Quantity__c
        decimal Amount__c
    }

    ContractLineItem__c {
        string ContractYearMonth__c
        decimal MonthlyRevenue__c
        string PaymentStatus__c
    }

    ProductMaster__c {
        string Name
        decimal Price__c
        string BillingType__c
    }

    StripeEvent__c {
        string EventId__c
        string EventType__c
        datetime ReceivedAt__c
        string ProcessStatus__c
    }

    StripeSyncLog__c {
        string TargetObject__c
        string Result__c
        string ErrorMessage__c
    }
```

## 4. 返金・取消フロー図

初期スコープでは返金・取消の実行はStripe画面で行い、SalesforceへはWebhookまたは再取得バッチで結果を同期します。

```mermaid
sequenceDiagram
    actor Accounting as 経理
    participant Stripe as Stripe
    participant SF as Salesforce
    participant Log as Stripe連携ログ

    Accounting->>Stripe: Stripe画面で返金・取消を実施
    Stripe->>SF: Webhookで返金イベント通知
    SF->>SF: StripeイベントIDの重複チェック
    SF->>SF: 請求に返金額・返金日・返金ステータスを反映
    SF->>Log: 処理結果を記録

    alt Webhook未着・処理失敗
        SF->>Stripe: 再取得バッチで決済状態を確認
        SF->>SF: 請求ステータスを補正
        SF->>Log: 補正結果を記録
    end
```

## 5. 役割別利用範囲

営業は決済URL発行と顧客案内、経理は決済状況・未入金・返金確認、システム管理者は接続設定とログ監視を担当します。

```mermaid
flowchart TB
    Sales["営業"]
    Accounting["経理"]
    Admin["システム管理者"]

    subgraph SalesOps["営業の操作"]
        S1["取引先確認"]
        S2["契約・請求確認"]
        S3["Stripe決済URL作成"]
        S4["顧客へ決済案内"]
    end

    subgraph AccountingOps["経理の操作"]
        A1["決済状況確認"]
        A2["未入金・失敗決済確認"]
        A3["返金・取消確認"]
        A4["Stripe画面で必要な手動対応"]
    end

    subgraph AdminOps["管理者の操作"]
        M1["Stripe接続設定"]
        M2["Webhook設定"]
        M3["連携ログ確認"]
        M4["バッチ・権限管理"]
    end

    Sales --> SalesOps
    Accounting --> AccountingOps
    Admin --> AdminOps
```

