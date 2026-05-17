public with sharing class ContractMonthlyLineBatch
    implements Database.Batchable<SObject>, Schedulable {
    @TestVisible
    private static final String STATUS_ACTIVATED = 'Activated';
    @TestVisible
    private static final String UPDATE_MONTHLY = '月';
    @TestVisible
    private static final String UPDATE_YEARLY = '年';
    @TestVisible
    private static final Integer BILLING_UPDATE_DAY = 10;
    private static final Integer YEARLY_MONTH_COUNT = 12;

    private Date runDate;

    public ContractMonthlyLineBatch() {
        this(Date.today());
    }

    @TestVisible
    private ContractMonthlyLineBatch(Date runDate) {
        this.runDate = runDate;
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new ContractMonthlyLineBatch(), 200);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (!shouldRun(runDate)) {
            return Database.getQueryLocator([
                SELECT Id
                FROM Contract__c
                WHERE Id = null
            ]);
        }

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Account__c,
                   ContractName__c,
                   ContractUpdate__c,
                   Plan__c,
                   StartDate__c,
                   Status__c
            FROM Contract__c
            WHERE Status__c = :STATUS_ACTIVATED
              AND ContractUpdate__c IN (:UPDATE_MONTHLY, :UPDATE_YEARLY)
              AND StartDate__c != null
        ]);
    }

    public void execute(
        Database.BatchableContext context,
        List<Contract__c> contractRecords
    ) {
        if (contractRecords.isEmpty()) {
            return;
        }

        Map<Id, Set<String>> existingYearMonthsByContractId =
            getExistingYearMonthsByContractId(contractRecords);
        List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();

        for (Contract__c contractRecord : contractRecords) {
            for (String yearMonth : buildTargetYearMonths(contractRecord)) {
                Set<String> existingYearMonths = existingYearMonthsByContractId.get(
                    contractRecord.Id
                );
                if (existingYearMonths != null && existingYearMonths.contains(yearMonth)) {
                    continue;
                }

                linesToInsert.add(buildLine(contractRecord, yearMonth));
            }
        }

        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    @TestVisible
    private static Boolean shouldRun(Date targetDate) {
        return targetDate != null && targetDate.day() > BILLING_UPDATE_DAY;
    }

    private Map<Id, Set<String>> getExistingYearMonthsByContractId(
        List<Contract__c> contractRecords
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contractRecords) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, Set<String>> existingYearMonthsByContractId =
            new Map<Id, Set<String>>();
        for (ContractLineItem__c line : [
            SELECT MasterContract__c,
                   ContractYearMonth__c
            FROM ContractLineItem__c
            WHERE MasterContract__c IN :contractIds
        ]) {
            if (!existingYearMonthsByContractId.containsKey(line.MasterContract__c)) {
                existingYearMonthsByContractId.put(
                    line.MasterContract__c,
                    new Set<String>()
                );
            }
            existingYearMonthsByContractId.get(line.MasterContract__c).add(
                line.ContractYearMonth__c
            );
        }

        return existingYearMonthsByContractId;
    }

    private List<String> buildTargetYearMonths(Contract__c contractRecord) {
        Date startMonth = firstDayOfMonth(contractRecord.StartDate__c);
        Integer monthCount = contractRecord.ContractUpdate__c == UPDATE_YEARLY
            ? YEARLY_MONTH_COUNT
            : 1;

        Date targetMonth = contractRecord.ContractUpdate__c == UPDATE_MONTHLY
            ? getMonthlyTargetMonth(startMonth)
            : startMonth;

        List<String> yearMonths = new List<String>();
        for (Integer index = 0; index < monthCount; index++) {
            yearMonths.add(formatYearMonth(targetMonth.addMonths(index)));
        }

        return yearMonths;
    }

    private Date getMonthlyTargetMonth(Date contractStartMonth) {
        Date currentMonth = firstDayOfMonth(runDate);
        return contractStartMonth > currentMonth ? contractStartMonth : currentMonth;
    }

    private static Date firstDayOfMonth(Date sourceDate) {
        return Date.newInstance(sourceDate.year(), sourceDate.month(), 1);
    }

    private static String formatYearMonth(Date sourceDate) {
        return String.valueOf(sourceDate.year()) + '/' + String.valueOf(sourceDate.month());
    }

    private static ContractLineItem__c buildLine(
        Contract__c contractRecord,
        String yearMonth
    ) {
        String sourceName = String.isBlank(contractRecord.ContractName__c)
            ? contractRecord.Name
            : contractRecord.ContractName__c;

        return new ContractLineItem__c(
            Name = sourceName + '_' + yearMonth,
            Account__c = contractRecord.Account__c,
            ContractYearMonth__c = yearMonth,
            MasterContract__c = contractRecord.Id,
            Month__c = yearMonth,
            Plan__c = contractRecord.Plan__c
        );
    }
}
