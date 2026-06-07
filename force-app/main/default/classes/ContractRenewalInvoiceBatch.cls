public with sharing class ContractRenewalInvoiceBatch
    implements Database.Batchable<SObject>, Database.AllowsCallouts, Schedulable {
    private static final String STATUS_ACTIVATED = 'Activated';
    private static final String UPDATE_MONTHLY = '月';
    private static final String UPDATE_YEARLY = '年';
    private static final String SEND_WAITING = '送付待ち';
    private static final String PAYMENT_WAITING = '決済待ち';
    private static final String PERIOD_STATUS_CREATED = '作成済';
    private static final String FREEE_STATUS_NOT_SYNCED = '未連携';
    private static final String INVOICE_STATUS_BILLED = '請求済';
    private static final Decimal TAX_RATE = 10;

    private Date runDate;

    public ContractRenewalInvoiceBatch() {
        this(Date.today());
    }

    @TestVisible
    private ContractRenewalInvoiceBatch(Date runDate) {
        this.runDate = runDate;
    }

    public void execute(SchedulableContext context) {
        Database.executeBatch(new ContractRenewalInvoiceBatch(), 100);
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        if (runDate == null || runDate.day() != 11) {
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
                   Account__r.Freee_Partner_Id__c,
                   ContractName__c,
                   ContractUpdate__c,
                   Plan__c,
                   RenewalStop__c,
                   StartDate__c,
                   Status__c
            FROM Contract__c
            WHERE Status__c = :STATUS_ACTIVATED
              AND StartDate__c != null
              AND ContractUpdate__c IN (:UPDATE_MONTHLY, :UPDATE_YEARLY)
              AND (RenewalStop__c = false OR RenewalStop__c = null)
        ]);
    }

    public void execute(Database.BatchableContext context, List<Contract__c> scope) {
        List<Contract__c> targetContracts = filterTargets(scope);
        if (targetContracts.isEmpty()) {
            return;
        }

        Map<Id, List<ContractLineItem__c>> templateLinesByContractId =
            getTemplateLinesByContractId(targetContracts);
        Map<Id, Set<Date>> existingPeriodStartDatesByContractId =
            getExistingPeriodStartDatesByContractId(targetContracts);

        List<Id> invoiceIdsForFreeeCreation = new List<Id>();
        for (Contract__c contractRecord : targetContracts) {
            Date periodStartDate = calculateTargetPeriodStartDate(contractRecord);
            if (periodStartDate == null || hasExistingPeriod(
                existingPeriodStartDatesByContractId,
                contractRecord.Id,
                periodStartDate
            )) {
                continue;
            }

            List<ContractLineItem__c> templateLines =
                templateLinesByContractId.get(contractRecord.Id);
            if (templateLines == null || templateLines.isEmpty()) {
                continue;
            }

            Id invoiceId = createRenewalSet(contractRecord, periodStartDate, templateLines);
            if (invoiceId != null) {
                invoiceIdsForFreeeCreation.add(invoiceId);
            }
        }

        if (!invoiceIdsForFreeeCreation.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new FreeeInvoiceCreateQueueable(invoiceIdsForFreeeCreation));
        }
    }

    public void finish(Database.BatchableContext context) {
    }

    private List<Contract__c> filterTargets(List<Contract__c> scope) {
        List<Contract__c> targets = new List<Contract__c>();
        for (Contract__c contractRecord : scope) {
            if (calculateTargetPeriodStartDate(contractRecord) != null) {
                targets.add(contractRecord);
            }
        }
        return targets;
    }

    private Date calculateTargetPeriodStartDate(Contract__c contractRecord) {
        if (contractRecord.ContractUpdate__c == UPDATE_MONTHLY) {
            return firstDayOfMonth(runDate).addMonths(1);
        }

        Date nextMonth = runDate.addMonths(1);
        if (nextMonth.month() != contractRecord.StartDate__c.month()) {
            return null;
        }

        Date targetStartDate = Date.newInstance(
            nextMonth.year(),
            contractRecord.StartDate__c.month(),
            contractRecord.StartDate__c.day()
        );
        return targetStartDate > contractRecord.StartDate__c ? targetStartDate : null;
    }

    private static Map<Id, List<ContractLineItem__c>> getTemplateLinesByContractId(
        List<Contract__c> contracts
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contracts) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, List<ContractLineItem__c>> linesByContractId =
            new Map<Id, List<ContractLineItem__c>>();
        for (ContractLineItem__c line : [
            SELECT Id,
                   MasterContract__c,
                   ProductMaster__c,
                   ProductMaster__r.Name,
                   QuotationLine__c,
                   RevenueAmount__c,
                   Total__c,
                   PeopleNumber__c,
                   MRR_Target__c,
                   ARR_Target__c
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

    private static Map<Id, Set<Date>> getExistingPeriodStartDatesByContractId(
        List<Contract__c> contracts
    ) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract__c contractRecord : contracts) {
            contractIds.add(contractRecord.Id);
        }

        Map<Id, Set<Date>> datesByContractId = new Map<Id, Set<Date>>();
        for (ContractPeriod__c periodRecord : [
            SELECT Contract__c,
                   PeriodStartDate__c
            FROM ContractPeriod__c
            WHERE Contract__c IN :contractIds
        ]) {
            if (!datesByContractId.containsKey(periodRecord.Contract__c)) {
                datesByContractId.put(periodRecord.Contract__c, new Set<Date>());
            }
            datesByContractId.get(periodRecord.Contract__c).add(periodRecord.PeriodStartDate__c);
        }
        return datesByContractId;
    }

    private static Boolean hasExistingPeriod(
        Map<Id, Set<Date>> datesByContractId,
        Id contractId,
        Date periodStartDate
    ) {
        return datesByContractId.containsKey(contractId)
            && datesByContractId.get(contractId).contains(periodStartDate);
    }

    private Id createRenewalSet(
        Contract__c contractRecord,
        Date periodStartDate,
        List<ContractLineItem__c> templateLines
    ) {
        Integer monthCount = contractRecord.ContractUpdate__c == UPDATE_YEARLY ? 12 : 1;
        Date periodEndDate = periodStartDate.addMonths(monthCount).addDays(-1);

        ContractPeriod__c periodRecord = new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = contractRecord.ContractUpdate__c,
            PeriodStartDate__c = periodStartDate,
            PeriodEndDate__c = periodEndDate,
            IsInitialPeriod__c = false,
            InvoiceCreationStatus__c = PERIOD_STATUS_CREATED,
            FreeeSyncStatus__c = FREEE_STATUS_NOT_SYNCED
        );
        insert periodRecord;

        Date billingDate = previousBusinessDay(Date.newInstance(runDate.year(), runDate.month(), 20));
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = contractRecord.Account__c,
            Billing_Date__c = billingDate,
            ContractPeriod__c = periodRecord.Id,
            Freee_Account_Item_Picklist__c = 'Sales',
            Freee_Invoice_Status__c = SEND_WAITING,
            Freee_Partner_Id__c = contractRecord.Account__r == null
                ? null
                : contractRecord.Account__r.Freee_Partner_Id__c,
            Freee_Sync_Status__c = 'Processing',
            ParentContract__c = contractRecord.Id,
            PaymentStatus__c = PAYMENT_WAITING,
            Payment_Date__c = calculatePaymentDueDate(billingDate),
            Subject__c = buildInvoiceSubject(contractRecord, periodStartDate, periodEndDate),
            TargetPeriodStartDate__c = periodStartDate,
            TargetPeriodEndDate__c = periodEndDate
        );
        insert invoiceRecord;

        insert buildInvoiceLines(invoiceRecord.Id, contractRecord.ContractUpdate__c, templateLines);
        insert buildContractLines(
            contractRecord,
            periodRecord.Id,
            invoiceRecord.Id,
            periodStartDate,
            monthCount,
            templateLines
        );

        periodRecord.RelatedInvoice__c = invoiceRecord.Id;
        update periodRecord;
        return invoiceRecord.Id;
    }

    private static List<InvoiceLine__c> buildInvoiceLines(
        Id invoiceId,
        String contractUpdate,
        List<ContractLineItem__c> templateLines
    ) {
        List<InvoiceLine__c> invoiceLines = new List<InvoiceLine__c>();
        if (contractUpdate == UPDATE_YEARLY) {
            Decimal amount = 0;
            List<String> productNames = new List<String>();
            for (ContractLineItem__c templateLine : collapseTemplateLines(templateLines)) {
                amount += getRevenueAmount(templateLine) * 12;
                productNames.add(getTemplateLineName(templateLine));
            }
            Decimal taxAmount = calculateTax(amount);
            invoiceLines.add(new InvoiceLine__c(
                AmountWithTax__c = amount + taxAmount,
                Description__c = buildAnnualLineName(productNames),
                DiscountedUnitPrice__c = amount,
                Invoice__c = invoiceId,
                LineType__c = '年間利用料',
                Quantity__c = 1,
                TaxAmount__c = taxAmount,
                Tax_Rate__c = TAX_RATE,
                Unit_Price__c = amount
            ));
            return invoiceLines;
        }

        for (ContractLineItem__c templateLine : collapseTemplateLines(templateLines)) {
            Decimal amount = getRevenueAmount(templateLine);
            Decimal taxAmount = calculateTax(amount);
            invoiceLines.add(new InvoiceLine__c(
                AmountWithTax__c = amount + taxAmount,
                Description__c = getTemplateLineName(templateLine),
                DiscountedUnitPrice__c = amount,
                Invoice__c = invoiceId,
                LineType__c = '継続費用',
                ProductMaster__c = templateLine.ProductMaster__c,
                Quantity__c = nullToOne(templateLine.PeopleNumber__c),
                TaxAmount__c = taxAmount,
                Tax_Rate__c = TAX_RATE,
                Unit_Price__c = amount
            ));
        }
        return invoiceLines;
    }

    private static List<ContractLineItem__c> buildContractLines(
        Contract__c contractRecord,
        Id periodId,
        Id invoiceId,
        Date periodStartDate,
        Integer monthCount,
        List<ContractLineItem__c> templateLines
    ) {
        List<ContractLineItem__c> lines = new List<ContractLineItem__c>();
        List<ContractLineItem__c> collapsedTemplateLines = collapseTemplateLines(templateLines);
        for (Integer monthIndex = 0; monthIndex < monthCount; monthIndex++) {
            Date monthStart = firstDayOfMonth(periodStartDate).addMonths(monthIndex);
            String yearMonth = formatYearMonth(monthStart);
            for (ContractLineItem__c templateLine : collapsedTemplateLines) {
                Decimal amount = getRevenueAmount(templateLine);
                lines.add(new ContractLineItem__c(
                    Account__c = contractRecord.Account__c,
                    ARR_Target__c = templateLine.ARR_Target__c,
                    ContractPeriod__c = periodId,
                    ContractYearMonth__c = yearMonth,
                    InitialFee__c = false,
                    InvoiceStatus__c = INVOICE_STATUS_BILLED,
                    MasterContract__c = contractRecord.Id,
                    Month__c = yearMonth,
                    MRR_Target__c = templateLine.MRR_Target__c,
                    PeopleNumber__c = templateLine.PeopleNumber__c,
                    PeriodStartDate__c = monthStart,
                    PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
                    Plan__c = contractRecord.Plan__c,
                    ProductMaster__c = templateLine.ProductMaster__c,
                    QuotationLine__c = templateLine.QuotationLine__c,
                    RelatedInvoice__c = invoiceId,
                    RevenueAmount__c = amount,
                    Total__c = amount
                ));
            }
        }
        return lines;
    }

    private static List<ContractLineItem__c> collapseTemplateLines(
        List<ContractLineItem__c> templateLines
    ) {
        Map<String, ContractLineItem__c> latestByProduct = new Map<String, ContractLineItem__c>();
        for (ContractLineItem__c templateLine : templateLines) {
            String key = templateLine.ProductMaster__c == null
                ? String.valueOf(templateLine.QuotationLine__c)
                : String.valueOf(templateLine.ProductMaster__c);
            if (!latestByProduct.containsKey(key)) {
                latestByProduct.put(key, templateLine);
            }
        }
        return latestByProduct.values();
    }

    private static String buildInvoiceSubject(
        Contract__c contractRecord,
        Date periodStartDate,
        Date periodEndDate
    ) {
        return getContractDisplayName(contractRecord)
            + ' '
            + formatYearMonth(periodStartDate)
            + '-'
            + formatYearMonth(periodEndDate);
    }

    private static String buildAnnualLineName(List<String> productNames) {
        List<String> names = new List<String>();
        Set<String> seen = new Set<String>();
        for (String productName : productNames) {
            if (String.isBlank(productName) || seen.contains(productName)) {
                continue;
            }
            names.add(productName);
            seen.add(productName);
        }
        return names.isEmpty() ? '年間利用料' : String.join(names, '・') + ' 年間利用料';
    }

    private static String getTemplateLineName(ContractLineItem__c templateLine) {
        if (templateLine.ProductMaster__r != null && !String.isBlank(templateLine.ProductMaster__r.Name)) {
            return templateLine.ProductMaster__r.Name;
        }
        return '利用料';
    }

    private static Decimal getRevenueAmount(ContractLineItem__c templateLine) {
        return templateLine.RevenueAmount__c == null
            ? nullToZero(templateLine.Total__c)
            : templateLine.RevenueAmount__c;
    }

    private static String getContractDisplayName(Contract__c contractRecord) {
        return String.isBlank(contractRecord.ContractName__c)
            ? contractRecord.Name
            : contractRecord.ContractName__c;
    }

    private static Date calculatePaymentDueDate(Date billingDate) {
        Date nextMonth = billingDate.addMonths(1);
        return Date.newInstance(nextMonth.year(), nextMonth.month(), 1)
            .addMonths(1)
            .addDays(-1);
    }

    private static Date previousBusinessDay(Date sourceDate) {
        Date adjustedDate = sourceDate;
        while (isWeekend(adjustedDate)) {
            adjustedDate = adjustedDate.addDays(-1);
        }
        return adjustedDate;
    }

    private static Boolean isWeekend(Date sourceDate) {
        Integer dayOffset = sourceDate.toStartOfWeek().daysBetween(sourceDate);
        return dayOffset == 0 || dayOffset == 6;
    }

    private static Date firstDayOfMonth(Date sourceDate) {
        return Date.newInstance(sourceDate.year(), sourceDate.month(), 1);
    }

    private static String formatYearMonth(Date sourceDate) {
        return String.valueOf(sourceDate.year()) + '/' + String.valueOf(sourceDate.month()).leftPad(2, '0');
    }

    private static Decimal calculateTax(Decimal amount) {
        return (nullToZero(amount) * TAX_RATE / 100).round(System.RoundingMode.CEILING);
    }

    private static Decimal nullToZero(Decimal sourceValue) {
        return sourceValue == null ? 0 : sourceValue;
    }

    private static Decimal nullToOne(Decimal sourceValue) {
        return sourceValue == null ? 1 : sourceValue;
    }
}
