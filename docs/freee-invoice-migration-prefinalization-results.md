# freee請求移行 確定前作業結果

更新日: 2026-06-21
対象環境: dev1

## 結論

freeeから取得した請求Work 12件に対して、移行確定前の参照解決と商品マスタ確定を実施した。

結果として、Salesforce請求・請求明細へ反映可能なWorkは2件。

## 実施内容

| No | 作業 | 結果 |
| --- | --- | --- |
| 1 | 契約・契約期間の自動解決ロジック改善 | 完了 |
| 2 | 商品マスタ解決ロジックを単価優先に修正 | 完了 |
| 3 | 一意に判定できる商品候補を確定 | 6明細を確定 |
| 4 | Work再検証 | 完了 |
| 5 | Apexテスト | `Mig_FreeeInvoiceMigrationTest` 5/5 Pass |

## 反映可能になった請求Work

| freee請求書ID | 取引先 | 請求日 | 金額 | ステータス |
| --- | --- | --- | ---: | --- |
| `59458020` | NTTデータ | 2026-06-19 | 132,000 | 反映可能 |
| `60545598` | NTTデータ | 2026-06-19 | 33,000 | 反映可能 |

## 現在のステータス

| Workステータス | 件数 |
| --- | ---: |
| 反映可能 | 2 |
| 要確認 | 10 |

| 商品解決ステータス | 件数 |
| --- | ---: |
| 確定済み | 7 |
| 要確認 | 6 |

## 安全性のため止めたもの

以下は自動確定せず、要確認のまま残した。

| 理由 | 対象 |
| --- | --- |
| 対応する契約期間が見つからない | `[demo]株式会社freee企画` の請求、NTTデータの2026-05-15請求 |
| Salesforce取引先が解決できない | `SF連携株式会社_1774157688669` |
| 対応する商品マスタが見つからない | 単価1,000円、5,000円、11,000円、100,000円などの明細 |
| 明細情報が不足している | freee請求書ID `54454493` の明細 |

## 実行コマンド

```powershell
sf project deploy start --target-org dev1 --source-dir force-app/main/default/classes/Mig_FreeeInvoiceReferenceResolver.cls --source-dir force-app/main/default/classes/Mig_FreeeInvoiceMigrationTest.cls --test-level RunSpecifiedTests --tests Mig_FreeeInvoiceMigrationTest --wait 60
sf project deploy start --target-org dev1 --source-dir force-app/main/default/classes/Mig_FreeeInvoiceProductResolver.cls --source-dir force-app/main/default/classes/Mig_FreeeInvoiceMigrationTest.cls --test-level RunSpecifiedTests --tests Mig_FreeeInvoiceMigrationTest --wait 60
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-resolve-and-validate.apex
sf apex run --target-org dev1 --file scripts/apex/mig-freee-invoice-confirm-unique-product-candidates.apex
```

## 追加・修正した資産

| ファイル | 内容 |
| --- | --- |
| `force-app/main/default/classes/Mig_FreeeInvoiceReferenceResolver.cls` | 契約期間が一意に特定できる場合、契約も契約期間から解決するよう修正 |
| `force-app/main/default/classes/Mig_FreeeInvoiceProductResolver.cls` | 商品マスタ解決を単価優先に修正。数量複数時に合計金額で誤判定しないよう制御 |
| `scripts/apex/mig-freee-invoice-resolve-and-validate.apex` | 参照解決、商品解決、検証を一括実行するスクリプト |
| `scripts/apex/mig-freee-invoice-confirm-unique-product-candidates.apex` | 商品単価が一意に決まる候補だけを確定するスクリプト |

## 次の判断

`反映可能` の2件は、`Mig_FreeeInvoiceFinalizeService.finalizeAllReady()` によりSalesforce請求・請求明細へ反映可能。

ただし、今回の作業範囲は「移行確定前作業」のため、請求・請求明細の本作成は未実施。

