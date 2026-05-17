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

    private enum LineCreationTiming {
        ACTIVATION,
        SCHEDULED
    }

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
        createLines(contractRecords, LineCreationTiming.SCHEDULED, runDate);
    }

    public void finish(Database.BatchableContext context) {
    }

    public static void createInitialLinesForActivatedContracts(
        List<Contract__c> newRecords,
        Map<Id, Contract__c> oldMap
    ) {
        List<Contract__c> targetContracts = new List<Contract__c>();
        for (Contract__c contractRecord : newRecords) {
            if (!isLineCreationTarget(contractRecord)) {
                continue;
            }

            Contract__c oldRecord = oldMap == null ? null : oldMap.get(contractRecord.Id);
            if (oldRecord == null || oldRecord.Status__c != STATUS_ACTIVATED) {
                targetContracts.add(contractRecord);
            }
        }

        createLines(targetContracts, LineCreationTiming.ACTIVATION, Date.today());
    }

    @TestVisible
    private static Boolean shouldRun(Date targetDate) {
        return targetDate != null && targetDate.day() > BILLING_UPDATE_DAY;
    }

    private static void createLines(
        List<Contract__c> contractRecords,
        LineCreationTiming timing,
        Date targetDate
    ) {
        if (contractRecords.isEmpty()) {
            return;
        }

        Map<Id, Set<String>> existingYearMonthsByContractId =
            getExistingYearMonthsByContractId(contractRecords);
        List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();

        for (Contract__c contractRecord : contractRecords) {
            for (String yearMonth : buildTargetYearMonths(
                contractRecord,
                timing,
                targetDate
            )) {
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

    private static Boolean isLineCreationTarget(Contract__c contractRecord) {
        return contractRecord.Status__c == STATUS_ACTIVATED
            && contractRecord.StartDate__c != null
            && (
                contractRecord.ContractUpdate__c == UPDATE_MONTHLY
                || contractRecord.ContractUpdate__c == UPDATE_YEARLY
            );
    }

    private static Map<Id, Set<String>> getExistingYearMonthsByContractId(
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

    private static List<String> buildTargetYearMonths(
        Contract__c contractRecord,
        LineCreationTiming timing,
        Date targetDate
    ) {
        Date startMonth = firstDayOfMonth(contractRecord.StartDate__c);

        if (timing == LineCreationTiming.ACTIVATION) {
            Integer monthCount = contractRecord.ContractUpdate__c == UPDATE_YEARLY
                ? YEARLY_MONTH_COUNT
                : 1;
            return buildYearMonthRange(startMonth, monthCount);
        }

        if (contractRecord.ContractUpdate__c == UPDATE_MONTHLY) {
            return buildYearMonthRange(
                getScheduledMonthlyTargetMonth(startMonth, targetDate),
                1
            );
        }

        Date yearlyTargetMonth = getScheduledYearlyTargetMonth(startMonth, targetDate);
        if (yearlyTargetMonth == null) {
            return new List<String>();
        }

        return buildYearMonthRange(yearlyTargetMonth, YEARLY_MONTH_COUNT);
    }

    private static List<String> buildYearMonthRange(Date targetMonth, Integer monthCount) {
        List<String> yearMonths = new List<String>();
        for (Integer index = 0; index < monthCount; index++) {
            yearMonths.add(formatYearMonth(targetMonth.addMonths(index)));
        }

        return yearMonths;
    }

    private static Date getScheduledMonthlyTargetMonth(
        Date contractStartMonth,
        Date targetDate
    ) {
        Date nextMonth = firstDayOfMonth(targetDate).addMonths(1);
        return contractStartMonth > nextMonth ? contractStartMonth : nextMonth;
    }

    private static Date getScheduledYearlyTargetMonth(
        Date contractStartMonth,
        Date targetDate
    ) {
        if (targetDate.month() != contractStartMonth.month()) {
            return null;
        }

        Date renewalStartMonth = Date.newInstance(
            targetDate.year(),
            contractStartMonth.month(),
            1
        );
        return renewalStartMonth > contractStartMonth ? renewalStartMonth : null;
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
