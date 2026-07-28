# freee請求移行 反映実行結果

更新日: 2026-06-22  
対象環境: dev1  
対象処理: `Mig_FreeeInvoiceFinalizeService.finalizeAllReady()`

## 結論

freeeから取得した請求Workのうち、反映可能だった2件をSalesforceの請求・請求明細へ反映しました。

| 判定 | 件数 |
| --- | ---: |
| 反映済み | 2 |
| 対象外 | 10 |
| 要確認 | 0 |

## 反映対象

| freee請求書ID | 反映結果 | Salesforce請求 | 備考 |
| --- | --- | --- | --- |
| `59458020` | 反映済み | `a1JIe00000AiSpQMAV` | 既存のSalesforce請求に紐づけ。既存請求明細2件も照合して紐づけ。 |
| `60545598` | 反映済み | `a1JIe00000AiUO8MAN` | 新規のSalesforce請求・請求明細1件を作成。 |

## 作成・紐づけされた請求

| Salesforce請求 | 請求番号 | freee請求書ID | 契約管理 | 契約期間 | 入金ステータス | 送付ステータス | freee連携 | 連携状態 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `a1JIe00000AiSpQMAV` | `INV-0000000033` | `59458020` | `a1OIe000000fzTNMAY` | `a1UIe0000032l5hMAA` | 決済待ち | 送付待ち | 済み | Success |
| `a1JIe00000AiUO8MAN` | `INV-0000000037` | `60545598` | `a1OIe000000fzTNMAY` | `a1UIe0000032l5hMAA` | 決済待ち | 送付待ち | 済み | Success |

## 作成・紐づけされた請求明細

| freee請求書ID | Salesforce請求明細 | 商品マスタ | 明細名 | 数量 | 単価 | 税込金額 | freee明細ID | 備考 |
| --- | --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `59458020` | `a1KIe0000005g8NMAQ` | `a1VIe000000XcSCMA0` | テスト | 3 | 30000 | 99000 | なし | 既存明細に紐づけ |
| `59458020` | `a1KIe0000005g8OMAQ` | `a1VIe000000XcSAMA0` | test | 3 | 10000 | 33000 | なし | 既存明細に紐づけ |
| `60545598` | `a1KIe0000005iIvMAI` | `a1VIe000000XcSAMA0` | SAMURAI Report Sample 20260524 Product 1 | 3 | 10000 | 33000 | `269799848` | 新規作成 |

## 実施した対応

### 1. 要確認Workの対象外化

移行対象外として扱うWorkを反映対象から除外しました。

実行スクリプト:

```powershell
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-exclude-review-work.apex
```

### 2. 反映処理

反映可能なWorkをSalesforce請求・請求明細へ反映しました。

実行スクリプト:

```powershell
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-finalize-all.apex
```

## 反映時に発生した問題と修正

### 既存のfreee連携済み請求を更新できない問題

freee請求書ID `59458020` は既にSalesforce請求に存在し、`Sent_To_Freee__c = true` でした。  
請求の主要業務項目はValidation Ruleで編集不可のため、既存請求を上書きしないように修正しました。

修正後の仕様:

- freee請求書IDが一致する既存請求がある場合、新規作成しない
- 既存請求の主要業務項目は更新しない
- 移行Workとの紐づけ情報のみ更新する

### 既存のfreee連携済み請求明細を更新できない問題

既存請求配下の請求明細もValidation Ruleで編集不可でした。  
そのため、既存請求の場合は請求明細を新規作成・更新せず、既存明細と照合して紐づける仕様に修正しました。

照合キー:

- 請求ID
- 商品マスタ
- 数量
- 税込金額

既存明細が一意に特定できない場合は、対象Workを `要確認` に戻す仕様です。

## デプロイ・テスト

修正後、dev1へデプロイし、移行テストを実行しました。

| 対象 | 結果 |
| --- | --- |
| `Mig_FreeeInvoiceFinalizeService.cls` デプロイ | 成功 |
| `Mig_FreeeInvoiceMigrationTest` | 5/5 Pass |
| 反映処理 | 成功 |

## 確認SOQL

```powershell
sf data query --target-org dev1 --query "SELECT FreeeInvoiceId__c, ImportStatus__c, CreatedInvoice__c, ValidationMessage__c FROM Mig_FreeeInvoiceWork__c WHERE FreeeInvoiceId__c IN ('59458020','60545598') ORDER BY FreeeInvoiceId__c" --result-format human

sf data query --target-org dev1 --query "SELECT ImportStatus__c, COUNT(Id) totalCount FROM Mig_FreeeInvoiceWork__c GROUP BY ImportStatus__c" --result-format human

sf data query --target-org dev1 --query "SELECT Id, Name, Freee_Invoice_Id__c, Freee_External_Key__c, ParentContract__c, ContractPeriod__c, InvoiceAmount__c, PaymentStatus__c, Freee_Invoice_Status__c, Sent_To_Freee__c, Freee_Sync_Status__c FROM Invoice__c WHERE Freee_Invoice_Id__c IN (59458020, 60545598) ORDER BY Freee_Invoice_Id__c" --result-format human

sf data query --target-org dev1 --query "SELECT Id, Name, Invoice__c, Invoice__r.Freee_Invoice_Id__c, ProductMaster__c, Description__c, Quantity__c, Unit_Price__c, AmountWithTax__c, Freee_Line_Id__c FROM InvoiceLine__c WHERE Invoice__r.Freee_Invoice_Id__c IN (59458020, 60545598) ORDER BY Invoice__r.Freee_Invoice_Id__c, Name" --result-format human

sf data query --target-org dev1 --query "SELECT InvoiceWork__r.FreeeInvoiceId__c, Description__c, ImportStatus__c, CreatedInvoiceLine__c FROM Mig_FreeeInvoiceLineWork__c WHERE InvoiceWork__r.FreeeInvoiceId__c IN ('59458020','60545598') ORDER BY InvoiceWork__r.FreeeInvoiceId__c, Description__c" --result-format human
```

## 次に実施すること

本番投入前に、以下を実施してください。

1. 本番環境で対象期間のfreee請求を取得する
2. 参照解決・商品マッピング・検証を実行する
3. `反映可能` のみ反映する
4. `要確認` は原因を解消するか、移行対象外にする
5. 反映後に請求・請求明細・契約期間・契約月次明細との参照を確認する

