List<Id> workIds = new List<Id>{
    'a0FRB00000YqK3u2AF','a0FRB00000YqK3v2AF','a0FRB00000YqSO22AN',
    'a0FRB00000aCDG92AO','a0FRB00000aCb7D2AS','a0FRB00000aDbGN2A0',
    'a0FRB00000aE0GL2A0','a0FRB00000aE0GP2A0','a0FRB00000au0xS2AQ',
    'a0FRB00000aurBN2AY','a0FRB00000b1IdV2AU'
};
Integer readyCount = [
    SELECT COUNT()
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
      AND ImportStatus__c = '反映可能'
      AND CreatedInvoice__c = null
];
System.assertEquals(11, readyCount, 'Preflight ready Work count changed');
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(workIds);
List<AggregateResult> results = [
    SELECT ImportStatus__c status, COUNT(Id) countValue
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
    GROUP BY ImportStatus__c
];
System.debug(LoggingLevel.ERROR, 'FINALIZE_RESULTS=' + results);
