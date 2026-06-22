Map<String, String> partnerNameById = new Map<String, String>{
    '77887489' => 'クウジット株式会社',
    '112236938' => 'さいたま家づくりネットワーク事務局',
    '85038097' => '株式会社スタッコ',
    '109374968' => '合同会社髙木秀太事務所 NOI STUDIO',
    '84446808' => '神奈川県知事　黒岩　祐治',
    '96810444' => '帝国不動産株式会社'
};

Set<Decimal> partnerIds = new Set<Decimal>();
for (String partnerIdText : partnerNameById.keySet()) {
    partnerIds.add(Decimal.valueOf(partnerIdText));
}

Map<String, Account> accountByPartnerId = new Map<String, Account>();
for (Account accountRecord : [
    SELECT Id, Name, Freee_Partner_Id__c
    FROM Account
    WHERE Freee_Partner_Id__c IN :partnerIds
]) {
    accountByPartnerId.put(String.valueOf(accountRecord.Freee_Partner_Id__c.setScale(0)), accountRecord);
}

List<Account> accountsToInsert = new List<Account>();
for (String partnerIdText : partnerNameById.keySet()) {
    if (!accountByPartnerId.containsKey(partnerIdText)) {
        accountsToInsert.add(new Account(
            Name = partnerNameById.get(partnerIdText),
            Freee_Partner_Id__c = Decimal.valueOf(partnerIdText)
        ));
    }
}

insert accountsToInsert;

for (Account accountRecord : accountsToInsert) {
    accountByPartnerId.put(String.valueOf(accountRecord.Freee_Partner_Id__c.setScale(0)), accountRecord);
}

List<Mig_FreeeInvoiceWork__c> worksToUpdate = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id, FreeePartnerId__c, ResolvedAccount__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = '要確認'
      AND ResolvedAccount__c = null
      AND FreeePartnerId__c IN :partnerNameById.keySet()
]) {
    Account accountRecord = accountByPartnerId.get(workRecord.FreeePartnerId__c);
    if (accountRecord != null) {
        workRecord.ResolvedAccount__c = accountRecord.Id;
        worksToUpdate.add(workRecord);
    }
}

update worksToUpdate;
System.debug('Inserted accounts=' + accountsToInsert.size());
System.debug('Resolved invoice works=' + worksToUpdate.size());

Mig_FreeeInvoiceMigrationController.validateAll();
