Integer readyCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
];
Integer readyWithExistingInvoiceCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = :Mig_FreeeInvoiceWorkService.STATUS_READY
      AND CreatedInvoice__c != null
];

System.assertEquals(155, readyCount, '事前確認した反映可能件数と異なるため処理を中止しました。');
System.assertEquals(68, readyWithExistingInvoiceCount, '事前確認した既存請求紐づけ件数と異なるため処理を中止しました。');

Mig_FreeeInvoiceFinalizeService.finalizeAllReady();

System.debug('requestedReadyCount=' + readyCount);
System.debug('requestedExistingInvoiceCount=' + readyWithExistingInvoiceCount);
