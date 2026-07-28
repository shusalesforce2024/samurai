# Freee請求移行Work 要確認対応一覧

- 作成日: 2026-07-24
- 対象環境: prod
- 対象件数: 61件
- 用途: 経理担当者が各Workの確認内容と対応方法を判断するためのチェックリスト

## 原因別件数

| 主原因 | 件数 |
|---|---:|
| 契約・商品未確定 | 34 |
| 商品未確定 | 19 |
| 契約・契約期間未確定 | 5 |
| 既存請求明細との照合不一致 | 1 |
| 金額不一致 | 1 |
| 商品名の類似性不足 | 1 |

## 対応順序

1. 優先度「高」の金額不一致、既存請求明細不一致、商品名類似性不足を確認する。
2. 商品未確定レコードの商品を確定し、再利用できる名称は商品マッピングへ登録する。
3. 契約未確定レコードの請求区分を確認し、Freee請求契約ルールを登録する。
4. Workを再検証し、「反映可能」になったレコードだけ本反映する。

## 共通確認事項

同じ内容をレコードごとに繰り返さず、以下の確認コードでまとめています。各レコード固有の確認対象は次の一覧を参照してください。

| コード | 対象件数 | 共通して確認すること | 確認後の対応 |
|---|---:|---|---|
| C01 | 39 | 請求が月契約・年契約・単発請求のどれか、既存契約へ紐づけるか新規契約を作るか、請求日を含む契約期間を作成してよいか確認する。 | 取引先・商品・件名キーワード・請求区分が一意になるFreee請求契約ルールを登録し、有効化する。 |
| P01 | 24 | Freee明細名・単価・数量と候補商品が一致し、その商品として確定してよいか確認する。 | 候補商品を確定商品に設定し、継続利用する名称は商品マッピングへ登録する。 |
| P02 | 33 | 商品候補がない明細について、既存商品、汎用商品、商品マスタ追加のどれで管理するか確認する。 | 商品マスタを選択または追加し、確定商品と商品マッピングを設定する。 |
| P03 | 1 | Freee明細名と確定商品名が類似していないため、単価・数量・契約内容を含めて誤紐づけでないか確認する。 | 正しければ正式な別名として商品マッピングへ登録し、誤りなら正しい商品へ変更する。 |
| A02 | 1 | 現在も請求金額と明細合計が異なるため、税、値引き、源泉税、調整額、明細重複のどれが原因かFreee原本で確認する。 | Freee原本を正としてWorkの税額・請求金額・明細を補正する。 |
| I01 | 1 | 作成済みSalesforce請求とFreee請求の明細を、Freee明細ID・件名・数量・単価・金額単位で比較する。 | 既存明細を直接削除せず、差分確定後に不足明細の追加または誤明細の訂正を行う。 |

## レコード別確認事項

| No | 優先度 | 主原因 | Work | 取引先 | 請求日 | 金額 | 確認コード | このレコード固有の確認対象 |
|---:|---|---|---|---|---|---:|---|---|
| 1 | 高 | 商品名の類似性不足 | [MFIW-000044](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000UtK9v2AF/view) | 戸田建設株式会社 | 2026-03-20 | 500,500 | P03 | 商品誤紐づけ確認: 「VISIOAL＿ベーシックプラン」 -> 「[月払] knock knock AI Enterpriseプラン 500クレジット」 \|\| 商品誤紐づけ確認: 「既存写真との整合（敷地）」 -> 「Rendery セキュリティオプション(SSO)_運用費用」 \|\| 商品誤紐づけ確認: 「詳細整合（インテリア）」 -> 「Rendery セキュリティオプション(IP制限)_運用費用」 \|\| 商品誤紐づけ確認: 「確認タイミング追加」 -> 「Rendery セキュリティオプション(SSO)_運用費用」 \|\| 商品誤紐づけ確認: 「追加修正」 -> 「Rendery セキュリティオプション(SSO)_運用費用」 |
| 2 | 中 | 契約・商品未確定 | [MFIW-000275](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj59H2AR/view) | 株式会社ヨコハマ地所 | 2026-03-20 | 12,100 | C01,P01 | 請求区分と契約先: 株式会社ヨコハマ地所 / 請求日: 2026-03-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 3 | 中 | 商品未確定 | [MFIW-000277](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj59J2AR/view) | リアルティホールディングス株式会社 | 2026-03-20 | 175,450 | P02 | 商品選択: 「knock knock AI_Enterpriseプラン_1100クレジット」 |
| 4 | 中 | 契約・商品未確定 | [MFIW-000280](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj59M2AR/view) | アグレ都市デザイン株式会社 | 2026-03-20 | 12,100 | C01,P01 | 請求区分と契約先: アグレ都市デザイン株式会社 / 請求日: 2026-03-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 5 | 中 | 契約・商品未確定 | [MFIW-000292](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wio6l2AB/view) | 株式会社トーケン | 2026-03-20 | 1,056,000 | C01,P02 | 請求区分と契約先: 株式会社トーケン / 請求日: 2026-03-20 \|\| 商品選択: 「Rendery_Pro_10アカウント_年間一括払い」 |
| 6 | 中 | 契約・商品未確定 | [MFIW-000357](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjhrF2AR/view) | 東急リゾーツ＆ステイ株式会社 | 2026-03-20 | 108,900 | C01,P01 | 請求区分と契約先: 東急リゾーツ＆ステイ株式会社 / 請求日: 2026-03-20 \|\| 商品候補確認: 「Rendery　エンタープライズプラン」 -> 「[OLD] Rendery Enterpriseプラン(2025年9月まで)」 |
| 7 | 中 | 商品未確定 | [MFIW-000359](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjhrH2AR/view) | 株式会社前田工務店 | 2026-03-20 | 60,500 | P01 | 商品候補確認: 「Rendery(エンタープライズプラン：1ヶ月)」 -> 「[OLD] Rendery Enterpriseプラン(2025年9月まで)」 |
| 8 | 中 | 契約・商品未確定 | [MFIW-000368](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjhzK2AR/view) | 株式会社アークフロンティア　テラスエステート | 2026-03-20 | 123,200 | C01,P02 | 請求区分と契約先: 株式会社アークフロンティア　テラスエステート / 請求日: 2026-03-20 \|\| 商品選択: 「knock knock AI_Enterpriseプラン(月額)」 |
| 9 | 中 | 契約・商品未確定 | [MFIW-000295](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wjfvr2AB/view) | 株式会社ヨコハマ地所 | 2026-04-20 | 12,100 | C01,P01 | 請求区分と契約先: 株式会社ヨコハマ地所 / 請求日: 2026-04-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 10 | 中 | 商品未確定 | [MFIW-000296](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wjfvs2AB/view) | リアルティホールディングス株式会社 | 2026-04-20 | 175,450 | P02 | 商品選択: 「knock knock AI_Enterpriseプラン_1200クレジット」 |
| 11 | 中 | 契約・商品未確定 | [MFIW-000299](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wjfvv2AB/view) | アグレ都市デザイン株式会社 | 2026-04-20 | 12,100 | C01,P01 | 請求区分と契約先: アグレ都市デザイン株式会社 / 請求日: 2026-04-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 12 | 中 | 契約・商品未確定 | [MFIW-000314](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj5UB2AZ/view) | 東急リゾーツ＆ステイ株式会社 | 2026-04-20 | 108,900 | C01,P01 | 請求区分と契約先: 東急リゾーツ＆ステイ株式会社 / 請求日: 2026-04-20 \|\| 商品候補確認: 「Rendery　エンタープライズプラン」 -> 「[OLD] Rendery Enterpriseプラン(2025年9月まで)」 |
| 13 | 中 | 契約・商品未確定 | [MFIW-000325](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj5UM2AZ/view) | 福井コンピュータアーキテクト | 2026-04-20 | 5,181,000 | C01,P02 | 請求区分と契約先: 福井コンピュータアーキテクト / 請求日: 2026-04-20 \|\| 商品選択: 「着手金として」 |
| 14 | 中 | 商品未確定 | [MFIW-000327](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj5UO2AZ/view) | 東急建設株式会社 | 2026-04-20 | 105,600 | P02 | 商品選択: 「Rendery_Pro(2026年4月- 2027年3月)」 |
| 15 | 中 | 商品未確定 | [MFIW-000329](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj5UQ2AZ/view) | 株式会社大塚商会 | 2026-04-20 | 14,080 | P01 | 商品候補確認: 「Rendery_Pro_月額利用料_注文番号：405016881」 -> 「[代理販売20%] Rendery Proプラン」 |
| 16 | 中 | 商品未確定 | [MFIW-000330](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wj5UR2AZ/view) | 株式会社大塚商会 | 2026-04-20 | 7,040 | P01 | 商品候補確認: 「Rendery_Pro_４月利用料(株式会社長谷建築設計事務所様)」 -> 「[代理販売20%] Rendery Proプラン」 |
| 17 | 中 | 契約・商品未確定 | [MFIW-000334](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjFOi2AN/view) | 株式会社石勝エクステリア | 2026-04-20 | 1,716,000 | C01,P02 | 請求区分と契約先: 株式会社石勝エクステリア / 請求日: 2026-04-20 \|\| 商品選択: 「年払い割引」 \|\| 商品選択: 「セキュリティオプション_シングルサインオン_運用費用_年払い」 |
| 18 | 中 | 契約・商品未確定 | [MFIW-000342](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjFOq2AN/view) | 近鉄不動産株式会社 | 2026-04-20 | 676,500 | C01,P01,P02 | 請求区分と契約先: 近鉄不動産株式会社 / 請求日: 2026-04-20 \|\| 商品候補確認: 「[月額費用]Rendery Enterpriseプラン_11アカウント」 -> 「Rendery Enterpriseプラン」 \|\| 商品選択: 「[月額費用]セキュリティオプション+_運用費用」 \|\| 商品選択: 「[初月のみ]セキュリティオプション+_初期コスト」 |
| 19 | 中 | 契約・商品未確定 | [MFIW-000346](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjFOu2AN/view) | 株式会社フジタ | 2026-04-20 | 924,000 | C01,P02 | 請求区分と契約先: 株式会社フジタ / 請求日: 2026-04-20 \|\| 商品選択: 「年払い割引」 |
| 20 | 中 | 契約・商品未確定 | [MFIW-000349](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjFOx2AN/view) | 株式会社フジタ | 2026-04-20 | 1,293,600 | C01,P02 | 請求区分と契約先: 株式会社フジタ / 請求日: 2026-04-20 \|\| 商品選択: 「年払い割引」 |
| 21 | 中 | 契約・商品未確定 | [MFIW-000350](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjFOy2AN/view) | 株式会社フジタ | 2026-04-20 | 554,400 | C01,P02 | 請求区分と契約先: 株式会社フジタ / 請求日: 2026-04-20 \|\| 商品選択: 「年払い割引」 |
| 22 | 中 | 契約・商品未確定 | [MFIW-000229](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjSKT2A3/view) | 株式会社ヨコハマ地所 | 2026-05-20 | 12,100 | C01,P01 | 請求区分と契約先: 株式会社ヨコハマ地所 / 請求日: 2026-05-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 23 | 中 | 商品未確定 | [MFIW-000230](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjSKU2A3/view) | リアルティホールディングス株式会社 | 2026-05-20 | 175,450 | P02 | 商品選択: 「knock knock AI_Enterpriseプラン_1200クレジット」 |
| 24 | 中 | 契約・商品未確定 | [MFIW-000233](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjSKX2A3/view) | アグレ都市デザイン株式会社 | 2026-05-20 | 12,100 | C01,P01 | 請求区分と契約先: アグレ都市デザイン株式会社 / 請求日: 2026-05-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 25 | 中 | 契約・商品未確定 | [MFIW-000248](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTBg2AN/view) | 東急リゾーツ＆ステイ株式会社 | 2026-05-20 | 108,900 | C01,P01 | 請求区分と契約先: 東急リゾーツ＆ステイ株式会社 / 請求日: 2026-05-20 \|\| 商品候補確認: 「Rendery　エンタープライズプラン」 -> 「[OLD] Rendery Enterpriseプラン(2025年9月まで)」 |
| 26 | 中 | 商品未確定 | [MFIW-000259](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTmd2AF/view) | 株式会社大塚商会 | 2026-05-20 | 42,240 | P01 | 商品候補確認: 「Rendery_Pro_月額利用料(ジェイアール北海道エンジニアリング株式会社分)」 -> 「[代理販売20%] Rendery Proプラン」 |
| 27 | 中 | 商品未確定 | [MFIW-000260](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTme2AF/view) | 株式会社大塚商会 | 2026-05-20 | 14,080 | P01 | 商品候補確認: 「Rendery_Pro_月額利用料_注文番号：405342479」 -> 「[代理販売20%] Rendery Proプラン」 |
| 28 | 中 | 商品未確定 | [MFIW-000264](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTmi2AF/view) | 日鉄興和不動産株式会社 | 2026-05-20 | 1,848,000 | P02 | 商品選択: 「年払い割引」 |
| 29 | 中 | 契約・商品未確定 | [MFIW-000267](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTml2AF/view) | 近鉄不動産株式会社 | 2026-05-20 | 291,500 | C01,P01,P02 | 請求区分と契約先: 近鉄不動産株式会社 / 請求日: 2026-05-20 \|\| 商品候補確認: 「[月額費用]Rendery Enterpriseプラン_11アカウント」 -> 「Rendery Enterpriseプラン」 \|\| 商品選択: 「[月額費用]セキュリティオプション+_運用費用」 |
| 30 | 中 | 商品未確定 | [MFIW-000268](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WjTmm2AF/view) | 若築建設株式会社 | 2026-05-20 | 105,600 | P02 | 商品選択: 「Rendery Proプラン1アカウント_年払い」 |
| 31 | 中 | 契約・契約期間未確定 | [MFIW-000114](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000UtKuT2AV/view) | SFテスト | 2026-05-21 | 33,000 | C01 | 請求区分と契約先: SFテスト / 請求日: 2026-05-21 |
| 32 | 中 | 契約・契約期間未確定 | [MFIW-000125](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000UtM9t2AF/view) | どさんこ不動産 | 2026-06-19 | 33,000 | C01 | 請求区分と契約先: どさんこ不動産 / 請求日: 2026-06-19 |
| 33 | 高 | 金額不一致 | [MFIW-000126](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000UtM9u2AF/view) | 帝国不動産株式会社 | 2026-06-19 | 52,800 | A02 | 金額差異: 請求金額 52,800 円 / 明細合計 96,000 円 / 差額 43,200 円 |
| 34 | 中 | 商品未確定 | [MFIW-000174](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WicaT2AR/view) | リアルティホールディングス株式会社 | 2026-06-20 | 175,450 | P02 | 商品選択: 「knock knock AI_Enterpriseプラン_1200クレジット」 |
| 35 | 中 | 契約・契約期間未確定 | [MFIW-000183](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WhTPP2A3/view) | 株式会社デザインアーク | 2026-06-20 | 181,500 | C01 | 請求区分と契約先: 株式会社デザインアーク / 請求日: 2026-06-20 |
| 36 | 中 | 商品未確定 | [MFIW-000206](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WihDQ2AZ/view) | 梅林建設株式会社 | 2026-06-20 | 924,000 | P02 | 商品選択: 「年払い割引」 |
| 37 | 中 | 契約・商品未確定 | [MFIW-000208](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WihDS2AZ/view) | 株式会社NTTファシリティーズ | 2026-06-20 | 1,650,000 | C01,P02 | 請求区分と契約先: 株式会社NTTファシリティーズ / 請求日: 2026-06-20 \|\| 商品選択: 「Rendery Enterpriseプラン_10アカウント_月払い費用」 |
| 38 | 中 | 商品未確定 | [MFIW-000211](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WihDV2AZ/view) | 創建ホーム株式会社 | 2026-06-20 | 1,108,800 | P02 | 商品選択: 「年払い割引」 |
| 39 | 中 | 契約・商品未確定 | [MFIW-000156](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WieAb2AJ/view) | コクヨ株式会社 ワークプレイス事業本部 スペースソリューション本部 | 2026-06-25 | 544,500 | C01,P02 | 請求区分と契約先: コクヨ株式会社 ワークプレイス事業本部 スペースソリューション本部 / 請求日: 2026-06-25 \|\| 商品選択: 「パースディレクション」 \|\| 商品選択: 「※パース製作も含む」 |
| 40 | 中 | 契約・商品未確定 | [MFIW-000157](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wi6a42AB/view) | 株式会社コスモスイニシア | 2026-06-26 | 440,000 | C01,P02 | 請求区分と契約先: 株式会社コスモスイニシア / 請求日: 2026-06-26 \|\| 商品選択: 「プロポーザルに関するディレクション業務（着手金）」 |
| 41 | 中 | 契約・商品未確定 | [MFIW-000150](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wi4gd2AB/view) | 株式会社オリバー | 2026-06-29 | 3,300,000 | C01,P02 | 請求区分と契約先: 株式会社オリバー / 請求日: 2026-06-29 \|\| 商品選択: 「着手金として」 |
| 42 | 中 | 契約・商品未確定 | [MFIW-000151](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wi4ge2AB/view) | 株式会社ＬＩＸＩＬ | 2026-06-29 | 13,624,600 | C01,P02 | 請求区分と契約先: 株式会社ＬＩＸＩＬ / 請求日: 2026-06-29 \|\| 商品選択: 「AIによる空間提案ツール開発 （2026年6⽉-9⽉）」 \|\| 商品選択: 「要件定義・コンサルティング」 \|\| 商品選択: 「UX/UIデザイン」 \|\| 商品選択: 「フロントエンド開発」 \|\| 商品選択: 「AI画像⽣成パイプライン」 \|\| 商品選択: 「バックエンド/API開発」 \|\| 商品選択: 「テスト・品質保証」 \|\| 商品選択: 「PM・運⽤準備」 \|\| 商品選択: 「システム保守運⽤費⽤ （2026年9⽉-2027年3⽉）」 \|\| 商品選択: 「AI 画像⽣成 API 費⽤ ※1000組×1組当たり4枚画像⽣成想定」 |
| 43 | 中 | 契約・商品未確定 | [MFIW-000152](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wi4gf2AB/view) | 株式会社ＬＩＸＩＬ | 2026-06-29 | 3,861,000 | C01,P02 | 請求区分と契約先: 株式会社ＬＩＸＩＬ / 請求日: 2026-06-29 \|\| 商品選択: 「着手金」 |
| 44 | 中 | 契約・商品未確定 | [MFIW-000153](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000WiSXe2AN/view) | クウジット株式会社 | 2026-07-02 | 247,500 | C01,P02 | 請求区分と契約先: クウジット株式会社 / 請求日: 2026-07-02 \|\| 商品選択: 「システム保守運用費＿2026年4-6月度」 |
| 45 | 中 | 商品未確定 | [MFIW-000154](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Wic2L2AR/view) | 梅林建設株式会社 | 2026-07-03 | 72,630 | P02 | 商品選択: 「交通費」 |
| 46 | 中 | 契約・商品未確定 | [MFIW-000373](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000XX8tV2AT/view) | 愛知建築士会 | 2026-07-07 | 127,800 | C01,P02 | 請求区分と契約先: 愛知建築士会 / 請求日: 2026-07-07 \|\| 商品選択: 「講師費」 \|\| 商品選択: 「交通費（往復）」 |
| 47 | 中 | 契約・商品未確定 | [MFIW-000374](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YomM12AJ/view) | 野村不動産株式会社 | 2026-07-14 | 495,000 | C01,P02 | 請求区分と契約先: 野村不動産株式会社 / 請求日: 2026-07-14 \|\| 商品選択: 「外観モデル」 |
| 48 | 中 | 契約・商品未確定 | [MFIW-000378](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Ypg4v2AB/view) | 株式会社アールシーコア | 2026-07-20 | 275,000 | C01,P02 | 請求区分と契約先: 株式会社アールシーコア / 請求日: 2026-07-20 \|\| 商品選択: 「セキュリティオプション+_運用費用_月額」 |
| 49 | 中 | 商品未確定 | [MFIW-000388](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YptF22AJ/view) | コンチネンタルホーム株式会社 | 2026-07-20 | 44,000 | P01 | 商品候補確認: 「Rendery_Proプラン_5アカウント(月額費用)」 -> 「Rendery Proプラン」 |
| 50 | 中 | 契約・商品未確定 | [MFIW-000398](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000Yq7Em2AJ/view) | 近鉄不動産株式会社 | 2026-07-20 | 308,000 | C01,P01,P02 | 請求区分と契約先: 近鉄不動産株式会社 / 請求日: 2026-07-20 \|\| 商品候補確認: 「[月額費用]Rendery Enterpriseプラン_11アカウント」 -> 「Rendery Enterpriseプラン」 \|\| 商品選択: 「[月額費用]セキュリティオプション+_運用費用」 |
| 51 | 中 | 契約・商品未確定 | [MFIW-000405](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK3t2AF/view) | 株式会社野村工務店 | 2026-07-20 | 1,584,000 | C01,P01 | 請求区分と契約先: 株式会社野村工務店 / 請求日: 2026-07-20 \|\| 商品候補確認: 「Rendery Enterpriseプラン_10アカウント_月額費用」 -> 「[代理販売20%] Rendery Enterpriseプラン」 |
| 52 | 中 | 契約・商品未確定 | [MFIW-000406](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK3u2AF/view) | 株式会社サンテン・コーポレーション | 2026-07-20 | 35,200 | C01,P01 | 請求区分と契約先: 株式会社サンテン・コーポレーション / 請求日: 2026-07-20 \|\| 商品候補確認: 「Rendery Proプラン_月額費用」 -> 「Rendery Proプラン」 |
| 53 | 中 | 契約・商品未確定 | [MFIW-000407](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK3v2AF/view) | 株式会社パインウェル | 2026-07-20 | 8,800 | C01,P01 | 請求区分と契約先: 株式会社パインウェル / 請求日: 2026-07-20 \|\| 商品候補確認: 「Rendery Proプラン（月額）」 -> 「Rendery Proプラン」 |
| 54 | 中 | 商品未確定 | [MFIW-000410](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK3y2AF/view) | 株式会社大塚商会 | 2026-07-20 | 14,080 | P01 | 商品候補確認: 「Rendery_Pro_月額利用料_注文番号：405342481」 -> 「[代理販売20%] Rendery Proプラン」 |
| 55 | 中 | 契約・商品未確定 | [MFIW-000413](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK412AF/view) | 野村不動産株式会社 | 2026-07-20 | 2,244,000 | C01,P02 | 請求区分と契約先: 野村不動産株式会社 / 請求日: 2026-07-20 \|\| 商品選択: 「セキュリティオプション(シングルサインオン)月額費用」 |
| 56 | 中 | 商品未確定 | [MFIW-000414](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqK422AF/view) | 株式会社大塚商会 | 2026-07-20 | 1,584,000 | P01 | 商品候補確認: 「Rendery Enterpriseプラン_10アカウント_月額費用」 -> 「[代理販売20%] Rendery Enterpriseプラン」 |
| 57 | 高 | 既存請求明細との照合不一致 | [MFIW-000415](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqSO22AN/view) | 株式会社ワンズ・レーニア | 2026-07-20 | 82,500 | I01 | 明細照合: Salesforce請求「」 / Freee請求書ID 63128994 |
| 58 | 中 | 契約・契約期間未確定 | [MFIW-000421](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqSO82AN/view) | 株式会社ヨコハマ地所 | 2026-07-20 | 12,100 | C01,P01 | 請求区分と契約先: 株式会社ヨコハマ地所 / 請求日: 2026-07-20 \|\| 商品候補確認: 「knock knock AI_Basicプラン」 -> 「knock knock AI Basicプラン(50クレジット)」 |
| 59 | 中 | 商品未確定 | [MFIW-000422](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqSO92AN/view) | リアルティホールディングス株式会社 | 2026-07-20 | 175,450 | P02 | 商品選択: 「knock knock AI_Enterpriseプラン_1200クレジット」 |
| 60 | 中 | 契約・契約期間未確定 | [MFIW-000431](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YqLuW2AV/view) | 株式会社デザインアーク | 2026-07-20 | 181,500 | C01 | 請求区分と契約先: 株式会社デザインアーク / 請求日: 2026-07-20 |
| 61 | 中 | 契約・商品未確定 | [MFIW-000447](https://samuraiarchitects.lightning.force.com/lightning/r/Mig_FreeeInvoiceWork__c/a0FRB00000YswQ42AJ/view) | プラス株式会社 | 2026-07-31 | 6,600,000 | C01,P02 | 請求区分と契約先: プラス株式会社 / 請求日: 2026-07-31 \|\| 商品選択: 「事業開発検討」 \|\| 商品選択: 「3Dモデル自動生成システム開発PoC」 |
