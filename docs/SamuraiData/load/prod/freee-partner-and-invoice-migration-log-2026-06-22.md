# Freee取引先同期・Freee請求移行 実行ログ

実行日: 2026-06-22  
対象環境: prod  
作業者: Codex  

## 1. Freee取引先同期

本番移行作業のため、通常の50件上限ではなく、移行用サービス `FreeePartnerMigrationSyncService.enqueueTodayUnsynced(2000)` を使用した。

内部ではSalesforceのcallout上限を避けるため、最大2000件を受け取り、45件単位のQueueableに分割して実行する。

| 項目 | 結果 |
|---|---:|
| 対象 | 本日作成された取引先 |
| 同期対象件数 | 7,639 |
| 同期済み件数 | 7,639 |
| 未同期件数 | 0 |
| Queueable完了数 | 152 |
| 判定 | 完了 |

確認ファイル:

- `docs/SamuraiData/load/prod/maps/prod_account_today_freee_synced_final2.csv`
- `docs/SamuraiData/load/prod/maps/prod_account_today_freee_unsynced_final2.csv`

## 2. Freee請求移行Fetch

対象期間は2026年3月分から2026年6月分。

### 2.1 事象

最初のFetchで、Freee APIから対象期間外の2023年から2024年の請求が20件返り、Mig Workに作成された。

| 項目 | 件数 |
|---|---:|
| 期間外Mig請求Work | 20 |
| 期間外Mig請求明細Work | 48 |

### 2.2 対処

期間外のMig Workを削除した。

| 項目 | 結果 |
|---|---:|
| 削除したMig請求Work | 20 |
| 削除したMig請求明細Work | 48 |

その後、`Mig_FreeeInvoiceFetchBatch` を修正し、Freee APIの期間条件に加えてSalesforce側でも請求日が対象期間内の請求だけをWork化する防御を追加した。

| 項目 | 結果 |
|---|---|
| dry-run Deploy ID | `0AfRB000001KiU90AK` |
| 本番Deploy ID | `0AfRB000001KiVl0AK` |
| テスト | `Mig_FreeeInvoiceMigrationTest` 6/6 Pass |

### 2.3 修正後のFetch結果

| 項目 | 結果 |
|---|---:|
| Fetchジョブ | Completed |
| エラー | 0 |
| Mig請求Work | 0 |
| Mig請求明細Work | 0 |

## 3. 現在の判定

Freee請求一覧APIはステータス200で疎通している。

ただし、2026年3月から6月を指定しても、Freee側から返却された一覧は2023年から2024年の請求20件だった。修正後は期間外請求がWork化されないことを確認済み。

現時点では、本番Freee APIから対象期間2026年3月から6月の請求が取得できていないため、請求・請求明細の本反映は未実施。

## 4. 次の確認事項

1. Freee側に2026年3月から6月の請求データが存在するか確認する。
2. Salesforceの接続先Freee事業所、Named Credential、認証ユーザーが対象のFreee環境を向いているか確認する。
3. Freee側の請求一覧APIで利用できる期間条件が現在の実装パラメータと一致しているか確認する。
4. 対象請求が取得できる状態になったら、再度 `scripts/apex/mig-freee-invoice-fetch.apex` を実行する。

## 5. 進捗

| 工程 | 状態 | 進捗 |
|---|---|---:|
| 基本データ投入 | 完了 | 100% |
| Freee取引先同期 | 完了 | 100% |
| Freee請求Work取得 | 対象データ未取得のため停止 | 0% |
| Freee請求Work検証 | 未着手 | 0% |
| Freee請求本反映 | 未着手 | 0% |

