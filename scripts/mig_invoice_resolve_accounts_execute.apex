List<Account> candidates = new List<Account>{
    new Account(Name = '合同会社小島屋', Freee_Partner_Id__c = 117908370),
    new Account(Name = '株式会社NTTファシリティーズ', Freee_Partner_Id__c = 116847474),
    new Account(Name = '株式会社ヨコハマ地所', Freee_Partner_Id__c = 90698095),
    new Account(Name = '九州旅客鉄道株式会社(建設工事部施設課)', Freee_Partner_Id__c = 100746831),
    new Account(Name = '東急リゾーツ＆ステイ株式会社', Freee_Partner_Id__c = 86796448),
    new Account(Name = '九州旅客鉄道株式会社(博多設備区)', Freee_Partner_Id__c = 100766938),
    new Account(Name = '株式会社ＬＩＸＩＬ住宅研究所', Freee_Partner_Id__c = 102184607),
    new Account(Name = '株式会社トーケン', Freee_Partner_Id__c = 108278685),
    new Account(Name = '九州旅客鉄道株式会社(開発工事部)', Freee_Partner_Id__c = 100773244),
    new Account(Name = '株式会社JBリアルエステート', Freee_Partner_Id__c = 115316670),
    new Account(Name = '株式会社JR東日本建築設計', Freee_Partner_Id__c = 100332683),
    new Account(Name = '松栄不動産株式会社(アパマンショップ仙台東口店)', Freee_Partner_Id__c = 98221039),
    new Account(Name = '愛知建築士会', Freee_Partner_Id__c = 92143953),
    new Account(Name = '西和不動産株式会社 栗東店', Freee_Partner_Id__c = 96603066),
    new Account(Name = '株式会社三越伊勢丹プロパティ・デザイン', Freee_Partner_Id__c = 104848225),
    new Account(Name = 'コクヨ株式会社 ワークプレイス事業本部 スペースソリューション本部', Freee_Partner_Id__c = 119152943),
    new Account(Name = '株式会社デザインアーク（東京スペースソリューション第１営業所）', Freee_Partner_Id__c = 119080101),
    new Account(Name = '福井コンピュータアーキテクト', Freee_Partner_Id__c = 82617882),
    new Account(Name = '株式会社錢高組', Freee_Partner_Id__c = 108865293),
    new Account(Name = '三井不動産レジデンシャルリース株式会社(ソリューション推進部)', Freee_Partner_Id__c = 103564412),
    new Account(Name = '株式会社コスモスイニシア（流通事業部）', Freee_Partner_Id__c = 105448655),
    new Account(Name = '三菱地所株式会社(DX推進部)', Freee_Partner_Id__c = 103655741),
    new Account(Name = '柏井建設株式会社', Freee_Partner_Id__c = 108259265),
    new Account(Name = 'アイリスオーヤマ株式会社(ストアソリューション営業部ストアデザインチーム)', Freee_Partner_Id__c = 100773123),
    new Account(Name = 'アイリスオーヤマ株式会社(空間デザイン部)', Freee_Partner_Id__c = 100773095),
    new Account(Name = '株式会社ＬＩＸＩＬ', Freee_Partner_Id__c = 111309576)
};

Set<Decimal> partnerIds = new Set<Decimal>();
for (Account candidate : candidates) {
    partnerIds.add(candidate.Freee_Partner_Id__c);
}

Set<Decimal> existingPartnerIds = new Set<Decimal>();
for (Account existing : [
    SELECT Id, Freee_Partner_Id__c
    FROM Account
    WHERE Freee_Partner_Id__c IN :partnerIds
]) {
    existingPartnerIds.add(existing.Freee_Partner_Id__c);
}

List<Account> inserts = new List<Account>();
for (Account candidate : candidates) {
    if (!existingPartnerIds.contains(candidate.Freee_Partner_Id__c)) {
        inserts.add(candidate);
    }
}

Database.SaveResult[] results = Database.insert(inserts, false);
Integer successCount = 0;
Integer failureCount = 0;
List<String> messages = new List<String>();
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
        messages.add('CREATED ' + inserts[i].Name + ' / ' + results[i].getId());
    } else {
        failureCount++;
        List<String> errors = new List<String>();
        for (Database.Error err : results[i].getErrors()) {
            errors.add(err.getStatusCode() + ': ' + err.getMessage());
        }
        messages.add('FAILED ' + inserts[i].Name + ' / ' + String.join(errors, ' | '));
    }
}

System.debug(LoggingLevel.INFO, JSON.serializePretty(new Map<String, Object>{
    'candidates' => candidates.size(),
    'skippedExisting' => candidates.size() - inserts.size(),
    'insertAttempts' => inserts.size(),
    'successCount' => successCount,
    'failureCount' => failureCount,
    'messages' => messages
}));
