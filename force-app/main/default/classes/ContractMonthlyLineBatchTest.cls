@isTest
private class ContractMonthlyLineBatchTest {
    @isTest
    static void monthlyContractCreatesCurrentMonthWhenActivated() {
        Contract__c contractRecord = createDraftContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );
        createInvoiceWithLines(contractRecord.Id, contractRecord.Account__c);

        Test.startTest();
        contractRecord.Status__c = 'Activated';
        update contractRecord;
        Test.stopTest();

        List<ContractLineItem__c> lines = getLines(contractRecord.Id);
        System.assertEquals(1, lines.size());
        System.assertEquals('2026/06', lines[0].ContractYearMonth__c);
        System.assertEquals('2026/06', lines[0].Month__c);
        System.assertEquals(contractRecord.Account__c, lines[0].Account__c);
        System.assertEquals(5, lines[0].PeopleNumber__c);
        System.assertEquals(500, lines[0].Total__c);
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
        System.assert(yearMonths.contains('2026/06'));
        System.assert(yearMonths.contains('2026/07'));
        assertLineTotals(contractRecord.Id, '2026/07', 5, 500);
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
        System.assert(yearMonths.contains('2026/06'));
        System.assert(yearMonths.contains('2026/07'));
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
        System.assert(yearMonths.contains('2026/06'));
    }

    @isTest
    static void yearlyContractCreatesTwelveLinesWhenActivated() {
        Contract__c contractRecord = createDraftContract(
            '年',
            Date.newInstance(2026, 6, 15)
        );
        createInvoiceWithLines(contractRecord.Id, contractRecord.Account__c);

        Test.startTest();
        contractRecord.Status__c = 'Activated';
        update contractRecord;
        Test.stopTest();

        Set<String> yearMonths = getYearMonths(contractRecord.Id);
        System.assertEquals(12, yearMonths.size());
        System.assert(yearMonths.contains('2026/06'));
        System.assert(yearMonths.contains('2027/05'));
        assertLineTotals(contractRecord.Id, '2026/06', 5, 500);
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
        System.assert(yearMonths.contains('2026/06'));
        System.assert(yearMonths.contains('2027/05'));
        System.assert(yearMonths.contains('2027/06'));
        System.assert(yearMonths.contains('2028/05'));
        assertLineTotals(contractRecord.Id, '2027/06', 5, 500);
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

    @isTest
    static void activatedContractWithoutInvoiceThrowsError() {
        Contract__c contractRecord = createDraftContract(
            '月',
            Date.newInstance(2026, 6, 15)
        );

        Test.startTest();
        contractRecord.Status__c = 'Activated';
        Database.SaveResult result = Database.update(contractRecord, false);
        Test.stopTest();

        System.assertEquals(false, result.isSuccess());
        System.assert(
            result.getErrors()[0].getMessage().contains('契約に紐づく請求が存在しない')
        );
        System.assertEquals(0, getLines(contractRecord.Id).size());
    }

    private static Contract__c createActivatedContract(String contractUpdate, Date startDate) {
        Contract__c contractRecord = createDraftContract(contractUpdate, startDate);
        createInvoiceWithLines(contractRecord.Id, contractRecord.Account__c);
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

    private static void createInvoiceWithLines(Id contractId, Id accountId) {
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountId,
            ParentContract__c = contractId,
            Subject__c = 'Contract Invoice'
        );
        insert invoiceRecord;

        insert new List<InvoiceLine__c>{
            new InvoiceLine__c(
                Description__c = 'Line 1',
                Invoice__c = invoiceRecord.Id,
                Quantity__c = 2,
                Unit_Price__c = 100
            ),
            new InvoiceLine__c(
                Description__c = 'Line 2',
                Invoice__c = invoiceRecord.Id,
                Quantity__c = 3,
                Unit_Price__c = 100
            )
        };
    }

    private static void assertLineTotals(
        Id contractId,
        String yearMonth,
        Decimal expectedPeopleNumber,
        Decimal expectedTotal
    ) {
        ContractLineItem__c line = [
            SELECT PeopleNumber__c,
                   Total__c
            FROM ContractLineItem__c
            WHERE MasterContract__c = :contractId
              AND ContractYearMonth__c = :yearMonth
            LIMIT 1
        ];

        System.assertEquals(expectedPeopleNumber, line.PeopleNumber__c);
        System.assertEquals(expectedTotal, line.Total__c);
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
                   PeopleNumber__c,
                   Plan__c,
                   Total__c
            FROM ContractLineItem__c
            WHERE MasterContract__c = :contractId
            ORDER BY ContractYearMonth__c ASC
        ];
    }
}
