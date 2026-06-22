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

        Map<Id, Set<String>> existingLineKeysByContractId =
            getExistingLineKeysByContractId(contractRecords);
        Map<Id, InvoiceSummary> invoiceSummaryByContractId =
            getInvoiceSummaryByContractId(contractRecords);
        Map<Id, List<ContractLineItem__c>> templateLinesByContractId =
            getTemplateLinesByContractId(contractRecords);
        contractRecords = filterContractsWithLineSource(
            contractRecords,
            invoiceSummaryByContractId,
            templateLinesByContractId
        );
        if (contractRecords.isEmpty()) {
            return;
        }
        Map<String, ContractPeriod__c> periodByKey =
            getExistingPeriodsByKey(contractRecords);
        List<PendingLineGroup> pendingLineGroups = new List<PendingLineGroup>();
        List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
        List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();

        for (Contract__c contractRecord : contractRecords) {
            for (PeriodPlan periodPlan : buildTargetPeriods(
                contractRecord,
                timing,
                targetDate
            )) {
                String periodKey = buildPeriodKey(contractRecord.Id, periodPlan.periodStartDate);
                ContractPeriod__c periodRecord = periodByKey.get(periodKey);
                if (periodRecord == null) {
                    periodRecord = buildPeriod(contractRecord, periodPlan, timing);
                    periodsToInsert.add(periodRecord);
                    periodByKey.put(periodKey, periodRecord);
                }

                pendingLineGroups.add(new PendingLineGroup(
                    contractRecord,
                    periodRecord,
                    periodPlan
                ));
            }
        }

        if (!periodsToInsert.isEmpty()) {
            insert periodsToInsert;
        }

        for (PendingLineGroup groupRecord : pendingLineGroups) {
            List<ContractLineItem__c> templateLines =
                templateLinesByContractId.get(groupRecord.contractRecord.Id);
            if (templateLines != null && !templateLines.isEmpty()) {
                linesToInsert.addAll(buildLinesFromTemplates(
                    groupRecord,
                    collapseTemplateLines(templateLines),
                    existingLineKeysByContractId
                ));
            } else {
                linesToInsert.addAll(buildLinesFromInvoiceSummary(
                    groupRecord,
                    invoiceSummaryByContractId.get(groupRecord.contractRecord.Id),
                    existingLineKeysByContractId
                ));
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

    private static Map<Id, Set<String>> getExistingLineKeysByContractId(
        List<Contract__c> contractRecords
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contractRecords) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, Set<String>> existingLineKeysByContractId =
            new Map<Id, Set<String>>();
        for (ContractLineItem__c line : [
            SELECT MasterContract__c,
                   ContractYearMonth__c,
                   ProductMaster__c,
                   QuotationLine__c
            FROM ContractLineItem__c
            WHERE MasterContract__c IN :contractIds
        ]) {
            if (!existingLineKeysByContractId.containsKey(line.MasterContract__c)) {
                existingLineKeysByContractId.put(
                    line.MasterContract__c,
                    new Set<String>()
                );
            }
            existingLineKeysByContractId.get(line.MasterContract__c).add(buildLineKey(line));
        }

        return existingLineKeysByContractId;
    }

    private static Map<Id, InvoiceSummary> getInvoiceSummaryByContractId(
        List<Contract__c> contractRecords
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contractRecords) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, InvoiceSummary> invoiceSummaryByContractId =
            new Map<Id, InvoiceSummary>();
        for (AggregateResult result : [
            SELECT ParentContract__c contractId,
                   SUM(NumberOfPeople__c) peopleNumber,
                   SUM(TotalAmount__c) totalAmount
            FROM Invoice__c
            WHERE ParentContract__c IN :contractIds
            GROUP BY ParentContract__c
        ]) {
            invoiceSummaryByContractId.put(
                (Id) result.get('contractId'),
                new InvoiceSummary(
                    (Decimal) result.get('peopleNumber'),
                    (Decimal) result.get('totalAmount')
                )
            );
        }

        return invoiceSummaryByContractId;
    }

    private static Map<Id, List<ContractLineItem__c>> getTemplateLinesByContractId(
        List<Contract__c> contractRecords
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contractRecords) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, List<ContractLineItem__c>> linesByContractId =
            new Map<Id, List<ContractLineItem__c>>();
        for (ContractLineItem__c line : [
            SELECT Id,
                   MasterContract__c,
                   ProductMaster__c,
                   QuotationLine__c,
                   RevenueAmount__c,
                   Total__c,
                   PeopleNumber__c,
                   MRR_Target__c,
                   ARR_Target__c,
                   Plan__c
            FROM ContractLineItem__c
            WHERE MasterContract__c IN :contractIds
              AND (InitialFee__c = false OR InitialFee__c = null)
            ORDER BY PeriodStartDate__c DESC, CreatedDate DESC
        ]) {
            if (!linesByContractId.containsKey(line.MasterContract__c)) {
                linesByContractId.put(line.MasterContract__c, new List<ContractLineItem__c>());
            }
            linesByContractId.get(line.MasterContract__c).add(line);
        }

        return linesByContractId;
    }

    private static Map<String, ContractPeriod__c> getExistingPeriodsByKey(
        List<Contract__c> contractRecords
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contractRecords) {
            contractIds.add(contractRecord.Id);
        }

        Map<String, ContractPeriod__c> periodByKey = new Map<String, ContractPeriod__c>();
        for (ContractPeriod__c periodRecord : [
            SELECT Id,
                   Contract__c,
                   PeriodStartDate__c,
                   PeriodEndDate__c
            FROM ContractPeriod__c
            WHERE Contract__c IN :contractIds
        ]) {
            periodByKey.put(
                buildPeriodKey(periodRecord.Contract__c, periodRecord.PeriodStartDate__c),
                periodRecord
            );
        }

        return periodByKey;
    }

    private static List<Contract__c> filterContractsWithLineSource(
        List<Contract__c> contractRecords,
        Map<Id, InvoiceSummary> invoiceSummaryByContractId,
        Map<Id, List<ContractLineItem__c>> templateLinesByContractId
    ) {
        List<Contract__c> validContracts = new List<Contract__c>();
        List<String> contractNamesWithoutInvoice = new List<String>();
        for (Contract__c contractRecord : contractRecords) {
            List<ContractLineItem__c> templateLines = templateLinesByContractId.get(contractRecord.Id);
            Boolean hasTemplate = templateLines != null && !templateLines.isEmpty();
            Boolean hasInvoiceSummary = invoiceSummaryByContractId.containsKey(contractRecord.Id);
            if (hasTemplate || hasInvoiceSummary) {
                validContracts.add(contractRecord);
            } else {
                contractNamesWithoutInvoice.add(getContractDisplayName(contractRecord));
            }
        }

        if (!contractNamesWithoutInvoice.isEmpty()) {
            System.debug(LoggingLevel.WARN,
                'Skipped ContractMonthlyLineBatch targets because no invoice or contract monthly line source exists: '
                + String.join(contractNamesWithoutInvoice, ', ')
            );
        }
        return validContracts;
    }

    private static List<PeriodPlan> buildTargetPeriods(
        Contract__c contractRecord,
        LineCreationTiming timing,
        Date targetDate
    ) {
        Date startMonth = firstDayOfMonth(contractRecord.StartDate__c);

        if (timing == LineCreationTiming.ACTIVATION) {
            Integer monthCount = contractRecord.ContractUpdate__c == UPDATE_YEARLY
                ? YEARLY_MONTH_COUNT
                : 1;
            return new List<PeriodPlan>{
                new PeriodPlan(startMonth, monthCount)
            };
        }

        if (contractRecord.ContractUpdate__c == UPDATE_MONTHLY) {
            return new List<PeriodPlan>{
                new PeriodPlan(getScheduledMonthlyTargetMonth(startMonth, targetDate), 1)
            };
        }

        Date yearlyTargetMonth = getScheduledYearlyTargetMonth(startMonth, targetDate);
        if (yearlyTargetMonth == null) {
            return new List<PeriodPlan>();
        }

        return new List<PeriodPlan>{
            new PeriodPlan(yearlyTargetMonth, YEARLY_MONTH_COUNT)
        };
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
        Date nextMonth = firstDayOfMonth(targetDate).addMonths(1);
        if (nextMonth.month() != contractStartMonth.month()) {
            return null;
        }

        Date renewalStartMonth = Date.newInstance(
            nextMonth.year(),
            contractStartMonth.month(),
            1
        );
        return renewalStartMonth > contractStartMonth ? renewalStartMonth : null;
    }

    private static Date firstDayOfMonth(Date sourceDate) {
        return Date.newInstance(sourceDate.year(), sourceDate.month(), 1);
    }

    private static String formatYearMonth(Date sourceDate) {
        return String.valueOf(sourceDate.year()) + '/' + String.valueOf(sourceDate.month()).leftPad(2, '0');
    }

    private static String getContractDisplayName(Contract__c contractRecord) {
        return String.isBlank(contractRecord.ContractName__c)
            ? contractRecord.Name
            : contractRecord.ContractName__c;
    }

    private static List<ContractLineItem__c> buildLinesFromTemplates(
        PendingLineGroup groupRecord,
        List<ContractLineItem__c> templateLines,
        Map<Id, Set<String>> existingLineKeysByContractId
    ) {
        List<ContractLineItem__c> lines = new List<ContractLineItem__c>();
        for (String yearMonth : buildYearMonthRange(
            groupRecord.periodPlan.periodStartDate,
            groupRecord.periodPlan.monthCount
        )) {
            Date monthStart = parseYearMonth(yearMonth);
            for (ContractLineItem__c templateLine : templateLines) {
                String lineKey = buildLineKey(yearMonth, templateLine.ProductMaster__c, templateLine.QuotationLine__c);
                if (hasExistingLine(existingLineKeysByContractId, groupRecord.contractRecord.Id, lineKey)) {
                    continue;
                }
                lines.add(buildLineFromTemplate(
                    groupRecord.contractRecord,
                    groupRecord.periodRecord.Id,
                    yearMonth,
                    monthStart,
                    templateLine
                ));
                rememberLine(existingLineKeysByContractId, groupRecord.contractRecord.Id, lineKey);
            }
        }
        return lines;
    }

    private static List<ContractLineItem__c> buildLinesFromInvoiceSummary(
        PendingLineGroup groupRecord,
        InvoiceSummary invoiceSummary,
        Map<Id, Set<String>> existingLineKeysByContractId
    ) {
        List<ContractLineItem__c> lines = new List<ContractLineItem__c>();
        for (String yearMonth : buildYearMonthRange(
            groupRecord.periodPlan.periodStartDate,
            groupRecord.periodPlan.monthCount
        )) {
            String lineKey = buildLineKey(yearMonth, null, null);
            if (hasExistingLine(existingLineKeysByContractId, groupRecord.contractRecord.Id, lineKey)) {
                continue;
            }
            Date monthStart = parseYearMonth(yearMonth);
            lines.add(buildLineFromInvoiceSummary(
                groupRecord.contractRecord,
                groupRecord.periodRecord.Id,
                yearMonth,
                monthStart,
                invoiceSummary
            ));
            rememberLine(existingLineKeysByContractId, groupRecord.contractRecord.Id, lineKey);
        }
        return lines;
    }

    private static ContractPeriod__c buildPeriod(
        Contract__c contractRecord,
        PeriodPlan periodPlan,
        LineCreationTiming timing
    ) {
        return new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = contractRecord.ContractUpdate__c,
            IsInitialPeriod__c = timing == LineCreationTiming.ACTIVATION,
            PeriodStartDate__c = periodPlan.periodStartDate,
            PeriodEndDate__c = periodPlan.periodStartDate.addMonths(periodPlan.monthCount).addDays(-1)
        );
    }

    private static ContractLineItem__c buildLineFromInvoiceSummary(
        Contract__c contractRecord,
        Id contractPeriodId,
        String yearMonth,
        Date monthStart,
        InvoiceSummary invoiceSummary
    ) {
        String sourceName = getContractDisplayName(contractRecord);

        return new ContractLineItem__c(
            Name = sourceName + '_' + yearMonth,
            Account__c = contractRecord.Account__c,
            ContractPeriod__c = contractPeriodId,
            ContractYearMonth__c = yearMonth,
            MasterContract__c = contractRecord.Id,
            Month__c = yearMonth,
            PeopleNumber__c = invoiceSummary == null ? null : invoiceSummary.peopleNumber,
            PeriodStartDate__c = monthStart,
            PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
            Plan__c = contractRecord.Plan__c,
            RevenueAmount__c = invoiceSummary == null ? null : invoiceSummary.totalAmount,
            Total__c = invoiceSummary == null ? null : invoiceSummary.totalAmount
        );
    }

    private static ContractLineItem__c buildLineFromTemplate(
        Contract__c contractRecord,
        Id contractPeriodId,
        String yearMonth,
        Date monthStart,
        ContractLineItem__c templateLine
    ) {
        Decimal amount = templateLine.RevenueAmount__c == null
            ? templateLine.Total__c
            : templateLine.RevenueAmount__c;
        String sourceName = getContractDisplayName(contractRecord);

        return new ContractLineItem__c(
            Name = sourceName + '_' + yearMonth,
            Account__c = contractRecord.Account__c,
            ARR_Target__c = templateLine.ARR_Target__c,
            ContractPeriod__c = contractPeriodId,
            ContractYearMonth__c = yearMonth,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            Month__c = yearMonth,
            MRR_Target__c = templateLine.MRR_Target__c,
            PeopleNumber__c = templateLine.PeopleNumber__c,
            PeriodStartDate__c = monthStart,
            PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
            Plan__c = String.isBlank(templateLine.Plan__c) ? contractRecord.Plan__c : templateLine.Plan__c,
            ProductMaster__c = templateLine.ProductMaster__c,
            QuotationLine__c = templateLine.QuotationLine__c,
            RevenueAmount__c = amount,
            Total__c = amount
        );
    }

    private static List<ContractLineItem__c> collapseTemplateLines(
        List<ContractLineItem__c> templateLines
    ) {
        Map<String, ContractLineItem__c> latestByProduct = new Map<String, ContractLineItem__c>();
        for (ContractLineItem__c templateLine : templateLines) {
            String key = String.valueOf(templateLine.ProductMaster__c) + ':' + String.valueOf(templateLine.QuotationLine__c);
            if (!latestByProduct.containsKey(key)) {
                latestByProduct.put(key, templateLine);
            }
        }
        return latestByProduct.values();
    }

    private static Boolean hasExistingLine(
        Map<Id, Set<String>> existingLineKeysByContractId,
        Id contractId,
        String lineKey
    ) {
        return existingLineKeysByContractId.containsKey(contractId)
            && existingLineKeysByContractId.get(contractId).contains(lineKey);
    }

    private static void rememberLine(
        Map<Id, Set<String>> existingLineKeysByContractId,
        Id contractId,
        String lineKey
    ) {
        if (!existingLineKeysByContractId.containsKey(contractId)) {
            existingLineKeysByContractId.put(contractId, new Set<String>());
        }
        existingLineKeysByContractId.get(contractId).add(lineKey);
    }

    private static String buildPeriodKey(Id contractId, Date periodStartDate) {
        return String.valueOf(contractId) + ':' + String.valueOf(periodStartDate);
    }

    private static String buildLineKey(ContractLineItem__c line) {
        return buildLineKey(line.ContractYearMonth__c, line.ProductMaster__c, line.QuotationLine__c);
    }

    private static String buildLineKey(String yearMonth, Id productMasterId, Id quotationLineId) {
        return yearMonth + ':' + String.valueOf(productMasterId) + ':' + String.valueOf(quotationLineId);
    }

    private static Date parseYearMonth(String yearMonth) {
        List<String> parts = yearMonth.split('/');
        return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 1);
    }

    private class InvoiceSummary {
        private Decimal peopleNumber;
        private Decimal totalAmount;

        private InvoiceSummary(Decimal peopleNumber, Decimal totalAmount) {
            this.peopleNumber = peopleNumber;
            this.totalAmount = totalAmount;
        }
    }

    private class PeriodPlan {
        private Date periodStartDate;
        private Integer monthCount;

        private PeriodPlan(Date periodStartDate, Integer monthCount) {
            this.periodStartDate = periodStartDate;
            this.monthCount = monthCount;
        }
    }

    private class PendingLineGroup {
        private Contract__c contractRecord;
        private ContractPeriod__c periodRecord;
        private PeriodPlan periodPlan;

        private PendingLineGroup(
            Contract__c contractRecord,
            ContractPeriod__c periodRecord,
            PeriodPlan periodPlan
        ) {
            this.contractRecord = contractRecord;
            this.periodRecord = periodRecord;
            this.periodPlan = periodPlan;
        }
    }

    public class ContractMonthlyLineException extends Exception {
    }
}
