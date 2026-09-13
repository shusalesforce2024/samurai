Mig_FreeeInvoiceValidator.validateAll();

Map<String, Integer> countsByStatus = new Map<String, Integer>();
for (AggregateResult resultRecord : [
    SELECT ImportStatus__c status, COUNT(Id) recordCount
    FROM Mig_FreeeInvoiceWork__c
    GROUP BY ImportStatus__c
]) {
    countsByStatus.put(
        (String) resultRecord.get('status'),
        (Integer) resultRecord.get('recordCount')
    );
}
System.debug(LoggingLevel.ERROR, 'FREEE_WORK_STATUS_COUNTS=' + countsByStatus);
