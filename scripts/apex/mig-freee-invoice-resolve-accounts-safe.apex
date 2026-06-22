Map<String, Id> accountByFreeePartnerId = new Map<String, Id>{
    '119152943' => '001RB00001VTCZ9YAP', // コクヨ株式会社
    '113337501' => '001RB00001VTrkUYAT', // トヨタコニックプロ株式会社
    '111309576' => '001RB00001VTqidYAD', // 株式会社LIXIL
    '102184607' => '001RB00001VTraTYAT', // 株式会社 LIXIL住宅研究所
    '105043583' => '001RB00001VTqgBYAT', // 株式会社コスモスイニシア
    '105448655' => '001RB00001VTqgBYAT', // 株式会社コスモスイニシア
    '104848225' => '001RB00001VTqxsYAD', // 三越伊勢丹プロパティ・デザイン株式会社
    '108865293' => '001RB00001VTqW8YAL', // 株式会社 錢高組
    '103564412' => '001RB00001VTqbXYAT', // 三井不動産レジデンシャルリース株式会社
    '102411107' => '001RB00001VTqkoYAD', // 三菱商事 株式会社
    '98221039' => '001RB00001VTtIeYAL', // 松栄不動産株式会社
    '96603066' => '001RB00001VTtIZYA1', // リユースせいわ 西和不動産株式会社 栗東店
    '108259265' => '001RB00001VTrI5YAL'  // 柏井建設 株式会社
};

List<Mig_FreeeInvoiceWork__c> worksToUpdate = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, FreeePartnerId__c, ResolvedAccount__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = '要確認'
      AND ResolvedAccount__c = null
      AND FreeePartnerId__c IN :accountByFreeePartnerId.keySet()
]) {
    workRecord.ResolvedAccount__c = accountByFreeePartnerId.get(workRecord.FreeePartnerId__c);
    worksToUpdate.add(workRecord);
}

update worksToUpdate;
System.debug('Resolved account work count=' + worksToUpdate.size());

Mig_FreeeInvoiceMigrationController.validateAll();
