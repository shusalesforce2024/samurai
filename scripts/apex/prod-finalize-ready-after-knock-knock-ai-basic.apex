Integer readyCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = '反映可能'
];
System.assertEquals(22, readyCount, '事前確認時から反映可能件数が変わっています。');

Mig_FreeeInvoiceFinalizeService.finalizeAllReady();

System.debug(LoggingLevel.ERROR, 'requestedReadyCount=' + readyCount);
