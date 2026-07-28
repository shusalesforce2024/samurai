# Freee請求移行Work 商品類似性チェック対応メモ

## 対応日

2026-07-07

## 背景

請求書移行Workから請求・請求明細を作成する際、請求明細の件名と商品マスタ名が類似していないにもかかわらず、金額一致だけで商品マスタが紐づき、請求明細が作成されている疑いがあった。

## 調査結果

対象: 商品マスタが紐づいている請求書移行Work明細 247件

| 区分 | 件数 |
|---|---:|
| 高リスク | 20 |
| 高リスクのうち請求明細作成済み | 17 |
| 高リスクのうち未作成 | 3 |
| 中リスク | 24 |

高リスクの主な条件:

- `ResolveMessage__c = Matched by unit price.`
- 請求明細件名と商品マスタ名の類似度が低い
- 例: `講演料` に対して `Rendery セキュリティオプション(ドメイン制限)_初期費用` が紐づく

調査CSV:

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_product_similarity_suspects.csv`

## 実施した対応

### 1. 再発防止

`Mig_FreeeInvoiceFinalizeService` に請求作成直前のチェックを追加した。

以下の条件に該当する場合、請求作成を止め、請求書移行Workを `要確認` に戻す。

- 商品マスタが金額一致由来で紐づいている
- 請求明細件名と商品マスタ名の類似度が低い

対象の金額一致メッセージ:

- `Matched by unit price.`
- `Matched by single-line amount.`

### 2. テスト追加

`Mig_FreeeInvoiceMigrationTest.finalizeBlocksLowSimilarityPriceOnlyProductMatch` を追加。

確認内容:

- 件名 `講演料`
- 商品マスタ `Rendary`
- 金額一致由来
- 請求作成が止まり、Workが `要確認` になること

### 3. 既存疑義データの見える化

高リスク20明細を `要確認` に更新した。

親の請求書移行Work 10件も `要確認` に更新した。

請求・請求明細レコード自体は削除・変更していない。作成済みデータは監査・確認用に残している。

検証CSV:

- `docs/SamuraiData/load/prod/maps/prod_low_similarity_price_match_marked_verify.csv`

## 本番反映結果

対象デプロイ:

- `Mig_FreeeInvoiceFinalizeService`
- `Mig_FreeeInvoiceMigrationTest`

本番デプロイ結果:

- Deploy ID: `0AfRB000001NLhV0AW`
- テスト: `Mig_FreeeInvoiceMigrationTest`
- 結果: 10/10 Pass

## 今後の確認作業

請求書移行Workの `要確認` レコードを開き、関連リスト `Freee請求明細移行Work` で以下を確認する。

- 請求明細件名
- 現在の確定商品マスタ
- 作成済み請求明細
- 正しい商品マスタ

正しい商品マスタが判断できる場合は、明細の `確定商品マスタ` を修正する。

すでに請求明細が作成済みの場合は、必要に応じて請求明細側の商品マスタも修正する。
