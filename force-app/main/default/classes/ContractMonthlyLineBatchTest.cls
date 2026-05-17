@isTest
private class ContractMonthlyLineBatchTest {
    @isTest
    static void monthlyContractCreatesOneLineForCurrentMonthAfterBillingUpdateDay() {
        Contract__c contractRecord = createContract('月', Date.newInstance(2026, 6, 15));

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 11)),
            200
        );
        Test.stopTest();

        List<ContractLineItem__c> lines = getLines(contractRecord.Id);
        System.assertEquals(1, lines.size());
        System.assertEquals('2026/6', lines[0].ContractYearMonth__c);
        System.assertEquals('2026/6', lines[0].Month__c);
        System.assertEquals(contractRecord.Account__c, lines[0].Account__c);
    }

    @isTest
    static void monthlyContractCreatesNoDuplicateOnRerun() {
        Contract__c contractRecord = createContract('月', Date.newInstance(2026, 6, 15));

        insert new ContractLineItem__c(
            Name = 'Existing Monthly Line',
            ContractYearMonth__c = '2026/6',
            MasterContract__c = contractRecord.Id,
            Month__c = '2026/6'
        );

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 12)),
            200
        );
        Test.stopTest();

        System.assertEquals(1, getLines(contractRecord.Id).size());
    }

    @isTest
    static void monthlyContractDoesNotRunBeforeBillingUpdateDay() {
        Contract__c contractRecord = createContract('月', Date.newInstance(2026, 6, 15));

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 10)),
            200
        );
        Test.stopTest();

        System.assertEquals(0, getLines(contractRecord.Id).size());
    }

    @isTest
    static void yearlyContractCreatesTwelveLinesFromContractStartMonth() {
        Contract__c contractRecord = createContract('年', Date.newInstance(2026, 6, 15));

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 11)),
            200
        );
        Test.stopTest();

        List<ContractLineItem__c> lines = getLines(contractRecord.Id);
        System.assertEquals(12, lines.size());
        Set<String> yearMonths = new Set<String>();
        for (ContractLineItem__c line : lines) {
            yearMonths.add(line.ContractYearMonth__c);
        }
        System.assert(yearMonths.contains('2026/6'));
        System.assert(yearMonths.contains('2027/5'));
    }

    @isTest
    static void inactiveContractIsIgnored() {
        Account accountRecord = new Account(Name = 'Inactive Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = 'Inactive Contract',
            ContractUpdate__c = '月',
            StartDate__c = Date.newInstance(2026, 6, 15),
            Status__c = 'Draft'
        );
        insert contractRecord;

        Test.startTest();
        Database.executeBatch(
            new ContractMonthlyLineBatch(Date.newInstance(2026, 6, 11)),
            200
        );
        Test.stopTest();

        System.assertEquals(0, getLines(contractRecord.Id).size());
    }

    private static Contract__c createContract(String contractUpdate, Date startDate) {
        Account accountRecord = new Account(Name = contractUpdate + ' Account');
        insert accountRecord;

        Contract__c contractRecord = new Contract__c(
            Account__c = accountRecord.Id,
            ContractName__c = contractUpdate + ' Contract',
            ContractUpdate__c = contractUpdate,
            Plan__c = 'Pro',
            StartDate__c = startDate,
            Status__c = 'Activated'
        );
        insert contractRecord;

        return contractRecord;
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
