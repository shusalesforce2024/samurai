# prod データ投入実施結果

実施日: 2026-06-22  
対象環境: prod  
操作種別: Insert  
参考手順: prt01 投入成功手順

## 実施前対象

| 順番 | オブジェクト | API名 | 投入予定件数 |
|---:|---|---|---:|
| 1 | 商品マスタ | `ProductMaster__c` | 35 |
| 2 | 取引先 | `Account` | 7,639 |
| 3 | 取引先責任者 | `Contact` | 17,756 |
| 4 | 取引 | `Opportunity__c` | 483 |
| 5 | 契約管理 | `Contract__c` | 161 |
| 6 | 契約期間 | `ContractPeriod__c` | 162 |
| 7 | 契約月次明細 | `ContractLineItem__c` | 1,514 |
|  | 合計 |  | 27,750 |

## 実施結果

| 順番 | オブジェクト | Job ID | 処理件数 | 成功 | 失敗 | 結果 |
|---:|---|---|---:|---:|---:|---|
| 1 | 商品マスタ | `750RB00001GUaAnYAL` | 35 | 35 | 0 | 成功 |
| 2 | 取引先 | `750RB00001GUPc1YAH` | 7,639 | 7,639 | 0 | 成功 |
| 3 | 取引先責任者 | `750RB00001GU4xQYAT` | 17,756 | 17,293 | 463 | 一部失敗後に補正 |
| 3-1 | 取引先責任者 再投入 | `750RB00001GUHsyYAH` | 288 | 275 | 13 | 補正分成功、重複13件残 |
| 3-2 | 取引先責任者 重複許可投入 | `750RB00001GUPgvYAH` | 188 | 188 | 0 | 成功 |
| 4 | 取引 初回 | `750RB00001GUU5PYAX` | 483 | 0 | 483 | 選択リスト値不一致で失敗、データ補正 |
| 4-1 | 取引 再投入 | `750RB00001GUVBCYA5` | 483 | 483 | 0 | 成功 |
| 5 | 契約管理 | `750RB00001GUOCwYAP` | 161 | 161 | 0 | 成功 |
| 6 | 契約期間 | `750RB00001GUaqlYAD` | 162 | 162 | 0 | 成功 |
| 7 | 契約月次明細 | `750RB00001GTuwSYAT` | 1,514 | 1,514 | 0 | 成功 |

最終的な投入成功件数は 27,750 件です。

## 補正内容

| 対象 | 内容 |
|---|---|
| 取引先責任者 | `MarketingStatus__c = バウンス` は選択リスト未定義のため空欄化して再投入 |
| 取引先責任者 | メール形式不正値は空欄化して再投入 |
| 取引先責任者 | 重複検知で止まったレコードは、標準重複ルールを一時的に停止して投入後、復旧 |
| 取引 | `StageName__c` と `LostReason__c` は prt01 成功CSVと同じAPI値へ変換 |
| 契約管理 | `ContractUpdate__c` はメモ欄から年払いを年更新、半年払い・解約・通常を月更新として設定 |
| 契約管理 | 投入中のみ `ContractTrigger` を一時停止し、投入後に復旧 |
| 契約期間 | 親契約の `ContractUpdate__c` を反映し、未指定の状態は `未連携` / `未作成` / `true` を設定 |
| 契約月次明細 | prt01 成功結果の紐づけをもとに、親契約・契約期間IDをprod IDへ置換 |
| 契約月次明細 | `Month__c` / `ContractYearMonth__c` は `yyyy/MM` 形式にゼロ埋め |

## 実施後確認

| 確認対象 | 結果 |
|---|---:|
| `ProductMaster__c` CreatedDate = TODAY | 35 |
| `Account` CreatedDate = TODAY | 7,639 |
| `Contact` CreatedDate = TODAY | 17,756 |
| `Opportunity__c` CreatedDate = TODAY | 483 |
| `Contract__c` CreatedDate = TODAY | 161 |
| `ContractPeriod__c` CreatedDate = TODAY | 162 |
| `ContractLineItem__c` CreatedDate = TODAY | 1,514 |
| `ContractTrigger` | Active 復旧済み |
| Contact標準重複ルール | 一時停止後、復旧デプロイ済み |

## 保存ファイル

| 種別 | 保存先 |
|---|---|
| 生成CSV | `docs/SamuraiData/load/prod/generated/` |
| IDマップ | `docs/SamuraiData/load/prod/maps/` |
| Bulk API結果 | `docs/SamuraiData/load/prod/results/` |

## 注意事項

- 取引の初回投入失敗ファイルは、原因追跡用に `results/04_Opportunity__c.750RB00001GUU5PYAX-failed-records.csv` として保存しています。
- 取引先責任者の初回失敗ファイルと再投入失敗ファイルは、補正履歴として `results/` に保存しています。
- 契約管理投入では `ContractTrigger` を一時停止しましたが、投入後に `Active` へ戻し、Tooling APIで復旧確認済みです。
