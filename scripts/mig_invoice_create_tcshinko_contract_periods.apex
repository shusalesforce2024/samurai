Id contractId = 'a04RB00000kUAPzYAO';
List<Date> monthStarts = new List<Date>{
    Date.newInstance(2026, 5, 1),
    Date.newInstance(2026, 6, 1)
};

Map<Date, ContractPeriod__c> existingByStart = new Map<Date, ContractPeriod__c>();
for (ContractPeriod__c periodRecord : [
    SELECT Id, PeriodStartDate__c
    FROM ContractPeriod__c
    WHERE Contract__c = :contractId
      AND PeriodStartDate__c IN :monthStarts
]) {
    existingByStart.put(periodRecord.PeriodStartDate__c, periodRecord);
}

List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
for (Date monthStart : monthStarts) {
    if (existingByStart.containsKey(monthStart)) {
        continue;
    }
    periodsToInsert.add(new ContractPeriod__c(
        Contract__c = contractId,
        ContractUpdate__c = '月',
        PeriodStartDate__c = monthStart,
        PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
        IsInitialPeriod__c = false
    ));
}

if (!periodsToInsert.isEmpty()) {
    insert periodsToInsert;
}

Mig_FreeeInvoiceValidator.validateAll();
System.debug(LoggingLevel.INFO, 'inserted contract periods=' + periodsToInsert.size());
