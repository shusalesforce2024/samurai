Contract__c sourceContract = [
    SELECT Id
    FROM Contract__c
    LIMIT 1
];

Savepoint verificationSavepoint = Database.setSavepoint();
ContractLineItem__c testLine = new ContractLineItem__c(
    MasterContract__c = sourceContract.Id,
    PeriodStartDate__c = Date.newInstance(2026, 12, 1)
);
insert testLine;

ContractLineItem__c insertedLine = [
    SELECT ContractYearMonth__c,
           Month__c,
           PeriodStartDate__c,
           PeriodEndDate__c
    FROM ContractLineItem__c
    WHERE Id = :testLine.Id
];

System.assertEquals('2026/12', insertedLine.ContractYearMonth__c);
System.assertEquals('2026/12', insertedLine.Month__c);
System.assertEquals(Date.newInstance(2026, 12, 1), insertedLine.PeriodStartDate__c);
System.assertEquals(Date.newInstance(2026, 12, 31), insertedLine.PeriodEndDate__c);

System.debug(LoggingLevel.ERROR, 'PERIOD_GUARD_VERIFICATION=' + insertedLine);
Database.rollback(verificationSavepoint);
