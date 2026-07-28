List<Mig_FreeeInvoiceWork__c> targetWorks = [
    SELECT Id, PartnerName__c, FreeePartnerId__c, ResolvedAccount__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id = 'a0FRB00000UtM9t2AF'
      AND ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW
      AND ResolvedAccount__c = null
];
System.assertEquals(1, targetWorks.size(), '対象Workが事前確認結果と異なるため処理を中止しました。');

List<Account> existingAccounts = [
    SELECT Id
    FROM Account
    WHERE Name LIKE '%どさんこ%'
       OR Freee_Partner_Id__c = 117408227
];
System.assertEquals(0, existingAccounts.size(), '同名または同じfreee取引先IDの取引先が存在するため処理を中止しました。');

Account accountRecord = new Account(
    Name = targetWorks[0].PartnerName__c,
    Freee_Partner_Id__c = 117408227
);
insert accountRecord;

Mig_FreeeInvoiceValidator.validateAll();
System.debug('createdAccountId=' + accountRecord.Id);
