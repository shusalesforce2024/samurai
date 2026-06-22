# freee請求移行Work 要確認確認結果

作成日: 2026-06-22  
対象環境: prod  
対象期間: 2026-03-01 から 2026-06-30

## 1. 現在件数

| 対象 | 件数 |
|---|---:|
| `Mig_FreeeInvoiceWork__c` | 130 |
| `Mig_FreeeInvoiceLineWork__c` | 185 |

## 2. 請求Workステータス

| ステータス | 件数 |
|---|---:|
| 要確認 | 128 |
| 対象外 | 1 |
| 反映可能 | 1 |

## 3. 要確認の主な原因

| 観点 | 件数 | 補足 |
|---|---:|---|
| 取引先未解決 | 39 | `ResolvedAccount__c` が未設定 |
| 契約管理未解決 | 65 | `ResolvedContract__c` が未設定 |
| 契約期間未解決 | 65 | `ResolvedContractPeriod__c` が未設定 |
| 商品マスタ未確定明細 | 182 | `ConfirmedProductMaster__c` が未設定 |

## 4. 商品解決ステータス

| 商品解決ステータス | 件数 |
|---|---:|
| 確定済み | 2 |
| 候補あり | 137 |
| 要確認 | 46 |

要確認請求に紐づく明細だけで見ると以下。

| 商品解決ステータス | 件数 |
|---|---:|
| 確定済み | 1 |
| 候補あり | 136 |
| 要確認 | 46 |

## 5. 注意点

`候補あり` は一括確定しない方がよい。  
理由は、単価一致による低信頼候補が多く、例えば `knock knock AI Basicプラン` が `[OLD] Rendery Enterpriseプラン` に候補付けされているケースがあるため。

## 6. 出力ファイル

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_review_sample.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_work_review_sample.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_account_partners.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_contract_accounts.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_product_candidates.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_product_needs_review.csv`

## 7. 次の対応案

1. 取引先未解決39件を先に解消する。
   - freee取引先IDとSalesforce取引先の紐づきがないため、該当取引先に `Freee_Partner_Id__c` を設定するか、移行対象外にする。

2. 契約管理・契約期間未解決65件を解消する。
   - 取引先は解決しているが、有効な契約管理または対象月の契約期間が見つからない。
   - 既存契約/契約期間を補完するか、請求のみ移行対象として扱うか判断が必要。

3. 商品マスタ未確定182明細を解消する。
   - `候補あり` 136件は候補を目視確認して確定する。
   - `要確認` 46件は商品マスタまたは移行用商品マッピングを追加する。

4. 再検証を実行する。
   - `Mig_FreeeInvoiceMigrationController.validateAll()`
   - `反映可能` が増えたことを確認する。

5. 反映可能分だけSalesforce請求/請求明細へ本反映する。
   - `Mig_FreeeInvoiceFinalizeService.finalizeAllReady()`

---

## 8. 2026-06-22 取引先未解決の解消結果

### 実施方針

Account本体の `Freee_Partner_Id__c` は上書きしない。  
理由は、通常のfreee取引先同期で作成済みのFreee取引先IDを壊す可能性があるため。  
今回は移行用Workの `ResolvedAccount__c` のみを更新した。

### 実施内容

- 実行スクリプト: `scripts/apex/mig-freee-invoice-resolve-accounts-safe.apex`
- 更新対象: `Mig_FreeeInvoiceWork__c.ImportStatus__c = '要確認'` かつ `ResolvedAccount__c = null`
- 更新件数: 31件
- 更新後に `Mig_FreeeInvoiceMigrationController.validateAll()` を実行

### 解消結果

| 項目 | 件数 |
|---|---:|
| 取引先未解決 Before | 39 |
| 移行Workへ取引先反映 | 31 |
| 取引先未解決 After | 8 |

### 反映した主な対応

| freee取引先名 | Salesforce取引先 |
|---|---|
| コクヨ株式会社 ワークプレイス事業本部 スペースソリューション本部 | コクヨ 株式会社 |
| トヨタ・コニック・プロ株式会社 | トヨタコニックプロ株式会社 |
| 株式会社ＬＩＸＩＬ | 株式会社LIXIL |
| 株式会社ＬＩＸＩＬ住宅研究所 | 株式会社 LIXIL住宅研究所 |
| 株式会社コスモスイニシア 建築本部 | 株式会社コスモスイニシア |
| 株式会社コスモスイニシア（流通事業部） | 株式会社コスモスイニシア |
| 株式会社三越伊勢丹プロパティ・デザイン | 三越伊勢丹プロパティ・デザイン株式会社 |
| 株式会社錢高組 | 株式会社 錢高組 |
| 三井不動産レジデンシャルリース株式会社(ソリューション推進部) | 三井不動産レジデンシャルリース株式会社 |
| 三菱商事株式会社 | 三菱商事 株式会社 |
| 松栄不動産株式会社(アパマンショップ仙台東口店) | 松栄不動産株式会社 |
| 西和不動産株式会社 栗東店 | リユースせいわ 西和不動産株式会社 栗東店 |
| 柏井建設株式会社 | 柏井建設 株式会社 |

### 残った取引先未解決

| freee取引先ID | freee取引先名 | 件数 |
|---|---|---:|
| 77887489 | クウジット株式会社 | 1 |
| 112236938 | さいたま家づくりネットワーク事務局 | 1 |
| 85038097 | 株式会社スタッコ | 1 |
| 109374968 | 合同会社髙木秀太事務所 NOI STUDIO | 1 |
| 84446808 | 神奈川県知事 黒岩 祐治 | 3 |
| 96810444 | 帝国不動産株式会社 | 1 |

### 追加出力

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_unresolved_account_match_candidates.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_unresolved_account_fuzzy_candidates.csv`
- `docs/SamuraiData/load/prod/maps/prod_account_candidates_unmatched_freee_partners.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_account_count_after_resolution.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_account_partners_after_resolution.json`

---

## 9. 2026-06-22 残取引先のAccount作成・紐づけ結果

### 実施内容

残った取引先未解決8件について、対応するAccountを新規作成し、移行Workへ紐づけた。

- 実行スクリプト: `scripts/apex/mig-freee-invoice-create-and-resolve-remaining-accounts.apex`
- 作成Account: 6件
- 紐づけた `Mig_FreeeInvoiceWork__c`: 8件
- 実行後に `Mig_FreeeInvoiceMigrationController.validateAll()` を実行

### 作成したAccount

| Account名 | Freee取引先ID |
|---|---:|
| クウジット株式会社 | 77887489 |
| さいたま家づくりネットワーク事務局 | 112236938 |
| 株式会社スタッコ | 85038097 |
| 合同会社髙木秀太事務所 NOI STUDIO | 109374968 |
| 神奈川県知事　黒岩　祐治 | 84446808 |
| 帝国不動産株式会社 | 96810444 |

### 解消結果

| 項目 | 件数 |
|---|---:|
| 取引先未解決 Before | 8 |
| 作成Account | 6 |
| 移行Workへ取引先反映 | 8 |
| 取引先未解決 After | 0 |

### 副次効果

取引先を解決したことで、契約管理・契約期間も一部自動解決された。

| 項目 | Before | After |
|---|---:|---:|
| 契約管理未解決 | 65 | 43 |
| 契約期間未解決 | 65 | 43 |
| 商品マスタ未確定明細 | 182 | 182 |

### 追加出力

- `docs/SamuraiData/load/prod/maps/prod_accounts_created_for_mig_invoice_remaining_partners.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_account_count_after_create_accounts.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_status_after_create_accounts.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_contract_count_after_accounts.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_period_count_after_accounts.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_unconfirmed_product_count_after_accounts.json`

---

## 10. 2026-06-22 契約管理・契約期間未解決の解消結果

### 実施方針

取引先は解決済みだが、既存の有効契約または対象年月の契約期間に自動解決できなかった freee 請求 Work 43件について、移行用の契約管理・契約期間を作成して明示的に紐づけた。

既存の本運用契約を不用意に変更しないため、作成した契約管理は `ContractName__c` を `Mig_freee請求移行_` 始まりとし、`Status__c = Draft` とした。請求移行 Work 側には `ResolvedContract__c` と `ResolvedContractPeriod__c` を直接設定しているため、後続の請求・請求明細反映に必要な参照は満たしている。

### 実行内容

- 実行スクリプト: `scripts/apex/mig-freee-invoice-create-migration-contract-periods.apex`
- 対象 Work: 43件
- 作成した移行用契約管理: 27件
- 作成した移行用契約期間: 39件
- 更新した `Mig_FreeeInvoiceWork__c`: 43件
- 実行後に `Mig_FreeeInvoiceMigrationController.validateAll()` を実行

### 解消結果

| 項目 | Before | After |
|---|---:|---:|
| 契約管理未解決 | 43 | 0 |
| 契約期間未解決 | 43 | 0 |
| Workステータス: 反映可能 | 1 | 2 |
| Workステータス: 要確認 | 128 | 127 |
| 商品マスタ未確定明細 | 182 | 183 |

商品マスタ未確定明細は、契約期間を作成したことにより再検証対象が増えたため 183件となった。次の未解決は `Mig_FreeeInvoiceLineWork__c.ConfirmedProductMaster__c` の確定である。

### 追加出力

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_created_migration_contracts.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_created_migration_contract_periods.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_contract_count_after_migration_periods.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_unresolved_period_count_after_migration_periods.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_status_after_migration_periods.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_unconfirmed_product_count_after_migration_periods.json`

---

## 11. 2026-06-22 商品マスタ未確定・金額不一致の解消結果

### 実施内容

契約管理・契約期間の解決後に残っていた商品マスタ未確定明細183件を解消した。

まず、単価が商品マスタ上で一意に特定でき、かつ `SuggestedProductMaster__c` と一致する90件を自動確定した。次に、残り93件について、明細名ルールにより商品マスタを確定した。

### 商品マスタ確定結果

| 処理 | 件数 |
|---|---:|
| 単価一意候補の確定 | 90 |
| 明細名ルールによる確定 | 93 |
| 商品マスタ未確定 Before | 183 |
| 商品マスタ未確定 After | 0 |

明細名ルールによる93件の割当内訳は以下。

| 割当先商品マスタ | 件数 |
|---|---:|
| 受託開発 | 45 |
| knock knock AI Basicプラン(50クレジット) | 24 |
| [OLD] Rendery Enterpriseプラン(2025年9月まで) | 14 |
| Rendery セキュリティオプション+_運用費用 | 8 |
| Rendery セキュリティオプション(SSO)_初期費用 | 1 |
| [年払] Rendery Enterpriseプラン | 1 |

### 金額不一致の補正

商品マスタ確定後、4件だけ `InvoiceAmount__c` と明細税込合計が一致しなかった。対象4件は Work 側の `TaxAmount__c` が空で、請求金額が税抜額として入っていたため、明細合計をもとに `InvoiceAmount__c` と `TaxAmount__c` を補正した。

| 処理 | 件数 |
|---|---:|
| 金額不一致補正 | 4 |
| 要確認 Work Before | 4 |
| 要確認 Work After | 0 |

### 最終結果

| 項目 | 件数 |
|---|---:|
| `Mig_FreeeInvoiceWork__c` 反映可能 | 129 |
| `Mig_FreeeInvoiceWork__c` 対象外 | 1 |
| `Mig_FreeeInvoiceWork__c` 要確認 | 0 |
| `Mig_FreeeInvoiceLineWork__c` 確定済み | 185 |
| 商品マスタ未確定明細 | 0 |

取得済みfreee請求130件のうち、移行対象129件は本反映可能な状態になった。

### 実行スクリプト

- `scripts/apex/mig-freee-invoice-confirm-unique-product-candidates.apex`
- `scripts/apex/mig-freee-invoice-confirm-remaining-products-by-rule.apex`
- `scripts/apex/mig-freee-invoice-fix-remaining-amount-mismatch.apex`

### 追加出力

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_unconfirmed_products_current.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_unconfirmed_products_after_unique_confirm.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_remaining_product_assignment_preview.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_remaining_amount_mismatch_raw.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_status_after_product_and_amount_resolution.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_product_status_after_product_and_amount_resolution.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_needs_review_count_after_product_and_amount_resolution.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_line_unconfirmed_product_count_after_product_and_amount_resolution.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_ready_work_after_resolution.csv`

---

## 12. 2026-06-22 Salesforce請求・請求明細への本反映結果

### 実施内容

`Mig_FreeeInvoiceWork__c.ImportStatus__c = 反映可能` の129件を、Salesforceの `Invoice__c` / `InvoiceLine__c` へ本反映した。

- 実行スクリプト: `scripts/apex/mig-freee-invoice-finalize-all.apex`
- 実行処理: `Mig_FreeeInvoiceFinalizeService.finalizeAllReady()`
- 対象Work: 129件

### 既存請求との重複対応

freee請求ID `60979452` は既存の `Invoice__c` に同一 `Freee_Invoice_Id__c` が存在したため、新規作成ではなく既存請求へ紐づける方針で処理した。

初回本反映では、既存請求明細の `ProductMaster__c` が空だったため、Work明細との照合に失敗し、該当1件だけ `要確認` に戻った。

対応として、対象をfreee請求ID `60979452` の1件に限定し、既存請求明細へ `Rendery Proプラン` を設定したうえで再反映した。既存請求はfreee連携済みロックの対象だったため、移行補正時のみ `Sent_To_Freee__c` を一時的にfalseへ変更し、補正後にtrueへ戻した。

- 補正スクリプト: `scripts/apex/mig-freee-invoice-fix-existing-invoice-60979452.apex`
- 対象freee請求ID: `60979452`
- 対象Work: `MFIW-000127`

### 最終結果

| 項目 | 件数 |
|---|---:|
| `Mig_FreeeInvoiceWork__c` 反映済み | 129 |
| `Mig_FreeeInvoiceWork__c` 対象外 | 1 |
| `Mig_FreeeInvoiceWork__c` 要確認 | 0 |
| `CreatedInvoice__c` 紐づけ済みWork | 129 |
| Salesforce請求 `Invoice__c` 合計 | 129 |
| Salesforce請求明細 `InvoiceLine__c` 合計 | 184 |

取得済みfreee請求130件のうち、移行対象129件はSalesforce請求・請求明細へ本反映済み。対象外1件を除き、未解消・未反映のWorkは残っていない。

### 追加出力

- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_ready_before_finalize.csv`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_status_after_finalize.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_created_invoice_count_after_finalize.json`
- `docs/SamuraiData/load/prod/maps/prod_invoice_count_after_finalize.json`
- `docs/SamuraiData/load/prod/maps/prod_invoiceline_count_after_finalize.json`
- `docs/SamuraiData/load/prod/maps/prod_mig_invoice_work_after_finalize.csv`
- `docs/SamuraiData/load/prod/maps/prod_invoice_after_finalize.csv`
- `docs/SamuraiData/load/prod/maps/prod_invoiceline_after_finalize.csv`
