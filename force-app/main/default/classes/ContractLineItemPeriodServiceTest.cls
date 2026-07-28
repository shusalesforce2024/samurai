@isTest
private class ContractLineItemPeriodServiceTest {
    @isTest
    static void fillsBlankPeriodFieldsFromStartDateThroughTrigger() {
        Account accountRecord = new Account(Name = 'Period field account');
        insert accountRecord;

        String contractUpdateValue = Contract__c.ContractUpdate__c
            .getDescribe().getPicklistValues()[0].getValue();
        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Period field contract',
            ContractUpdate__c = contractUpdateValue,
            StartDate__c = Date.newInstance(2026, 8, 15),
            Status__c = 'Draft'
        );
        insert contractRecord;

        ContractLineItem__c lineRecord = new ContractLineItem__c(
            MasterContract__c = contractRecord.Id,
            PeriodStartDate__c = Date.newInstance(2026, 8, 15)
        );
        insert lineRecord;

        ContractLineItem__c insertedRecord = [
            SELECT ContractYearMonth__c,
                   Month__c,
                   PeriodStartDate__c,
                   PeriodEndDate__c
            FROM ContractLineItem__c
            WHERE Id = :lineRecord.Id
        ];
        System.assertEquals('2026/08', insertedRecord.ContractYearMonth__c);
        System.assertEquals('2026/08', insertedRecord.Month__c);
        System.assertEquals(Date.newInstance(2026, 8, 15), insertedRecord.PeriodStartDate__c);
        System.assertEquals(Date.newInstance(2026, 8, 31), insertedRecord.PeriodEndDate__c);
    }

    @isTest
    static void derivesDatesFromYearMonthAndPreservesExistingValues() {
        ContractLineItem__c record = new ContractLineItem__c(
            ContractYearMonth__c = '2026/09',
            PeriodEndDate__c = Date.newInstance(2026, 10, 15)
        );

        ContractLineItemPeriodService.populatePeriodFields(
            new List<ContractLineItem__c>{ record }
        );

        System.assertEquals('2026/09', record.ContractYearMonth__c);
        System.assertEquals('2026/09', record.Month__c);
        System.assertEquals(Date.newInstance(2026, 9, 1), record.PeriodStartDate__c);
        System.assertEquals(Date.newInstance(2026, 10, 15), record.PeriodEndDate__c);
    }

    @isTest
    static void rejectsRecordsWithoutAnyPeriodSource() {
        ContractLineItem__c record = new ContractLineItem__c();

        ContractLineItemPeriodService.populatePeriodFields(
            new List<ContractLineItem__c>{ record }
        );

        System.assert(record.hasErrors());
        System.assertEquals(1, record.getErrors().size());
    }

    @isTest
    static void rejectsInvalidYearMonth() {
        ContractLineItem__c record = new ContractLineItem__c(
            Month__c = '2026/13'
        );

        ContractLineItemPeriodService.populatePeriodFields(
            new List<ContractLineItem__c>{ record }
        );

        System.assert(record.hasErrors());
        System.assertEquals(null, record.PeriodStartDate__c);
    }
}
