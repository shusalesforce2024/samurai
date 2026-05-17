@isTest
private class ContractMonthlyLineBatchTest {
    @isTest
    static void monthlyContractCreatesCurrentMonthWhenActivated() {
        Contract__c contractRecord = createDraftContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        contractRecord.Status__c = 'Activated';
        update contractRecord;
        Test.stopTest();

        List<ContractLineItem__c> lines = getLines(contractRecord.Id);
        System.assertEquals(1, lines.size());
        System.assertEquals('2026/6', lines[0].ContractYearMonth__c);
        System.assertEquals('2026/6', lines[0].Month__c);
        System.assertEquals(contractRecord.Account__c, lines[0].Account__c);
    }

    @isTest
    static void monthlyContractCreatesNextMonthAfterBillingUpdateDay() {
        Contract__c contractRecord = createActivatedContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 11)),
            200
        );
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(2, yearMonths.size());
        System.assert(yearMonths.contains('2026/6'));
        System.assert(yearMonths.contains('2026/7'));
    }

    @isTest
    static void monthlyContractCreatesNoDuplicateOnRerun() {
        Contract__c contractRecord = createActivatedContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 12)),
            200
        );
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 12)),
            200
        );
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(2, yearMonths.size());
        System.assert(yearMonths.contains('2026/6'));
        System.assert(yearMonths.contains('2026/7'));
    }

    @isTest
    static void monthlyContractDoesNotCreateNextMonthOnBillingUpdateDay() {
        Contract__c contractRecord = createActivatedContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 10)),
            200
        );
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(1, yearMonths.size());
        System.assert(yearMonths.contains('2026/6'));
    }

    @isTest
    static void yearlyContractCreatesTwelveLinesWhenActivated() {
        Contract__c contractRecord = createDraftContract(
            '年',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        contractRecord.Status__c = 'Activated';
        update contractRecord;
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(12, yearMonths.size());
        System.assert(yearMonths.contains('2026/6'));
        System.assert(yearMonths.contains('2027/5'));
    }

    @isTest
    static void yearlyContractCreatesNextTwelveLinesAfterRenewalMonthDayTen() {
        Contract__c contractRecord = createActivatedContract(
            '年',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2027, 6, 11)),
            200
        );
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(24, yearMonths.size());
        System.assert(yearMonths.contains('2026/6'));
        System.assert(yearMonths.contains('2027/5'));
        System.assert(yearMonths.contains('2027/6'));
        System.assert(yearMonths.contains('2028/5'));
    }

    @isTest
    static void yearlyContractDoesNotCreateNextYearBeforeRenewalMonthDayTen() {
        Contract__c contractRecord = createActivatedContract(
            '年',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2027, 6, 10)),
            200
        );
        Test.stopTest();

        System.assertEquals(12, getYearMonths(contractRecord.Id).size());
    }

    @isTest
    static void inactiveContractIsIgnored() {
        Contract__c contractRecord = createDraftContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 11)),
            200
        );
        Test.stopTest();

        System.assertEquals(0, getLines(contractRecord.Id).size());
    }

    private static Contract__c createActivatedContract(String contractUpdate, Date startDate) {
        Contract__c contractRecord = createDraftContract(contractUpdate, startDate);
        contractRecord.Status__c = 'Activated';
        update contractRecord;

        return contractRecord;
    }

    private static Contract__c createDraftContract(String contractUpdate, Date startDate) {
        Account accountRecord = new Account(Name = contractUpdate + ' Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = contractUpdate + ' Contract',
            ContractUpdate__c = contractUpdate,
            Plan__c = 'Pro',
            StartDate__c = startDate,
            Status__c = 'Draft'
        );
        insert contractRecord;

        return contractRecord;
    }

    private static Set<String> getYearMonths(Id contractId) {
        Set<String> yearMonths = new Set<String>();
        for (ContractLineItem__c line : getLines(contractId)) {
            yearMonths.add(line.ContractYearMonth__c);
        }
        return yearMonths;
    }

    private static List<ContractLineItem__c> getLines(Id contractId) {
        return [
            SELECT Account__c,
                   ContractYearMonth__c,
                   MasterContract__c,
                   Month__c,
                   Name,
                   Plan__c
            FROM ContractLineItem__c
            WHERE MasterContract__c = :contractId
            ORDER BY ContractYearMonth__c ASC
        ];
    }
}
