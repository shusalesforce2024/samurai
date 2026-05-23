public with sharing class OppContractInvoiceService {
    public class CreationResult {
        public Id contractId;
        public Id invoiceId;
        public Integer invoiceLineCount;
    }

    private static final String CLOSED_WON = 'Closed Won';
    private static final String ACCEPTED = 'Accepted';
    private static final String CONTRACT_STATUS_DRAFT = 'Draft';
    private static final String INVOICE_ACCOUNT_ITEM_SALES = 'Sales';
    private static final String QUOTATION_ACCOUNT_ITEM_SALES = 'sales';
    private static final String UPDATE_MONTHLY = '月';
    private static final String UPDATE_YEARLY = '年';
    private static final String INVOICE_STATUS_BILLED = '請求済';
    private static final String PERIOD_STATUS_CREATED = '作成済';
    private static final String FREEE_STATUS_NOT_SYNCED = '未連携';
    private static final String SEND_WAITING = '送付待ち';
    private static final String PAYMENT_WAITING = '決済待ち';
    private static final Decimal TAX_RATE = 10;

    public static CreationResult createFromOpportunity(Id opportunityId) {
        if (opportunityId == null) {
            throw new AuraHandledException('取引IDが指定されていません。');
        }

        Opportunity__c opportunityRecord = getOpportunity(opportunityId);
        validateOpportunity(opportunityRecord);

        if (hasExistingContract(opportunityId)) {
            throw new AuraHandledException('この取引には既に契約が作成されています。');
        }
        if (hasExistingInvoice(opportunityId)) {
            throw new AuraHandledException('この取引には既に請求が作成されています。');
        }

        Quotation__c acceptedQuotation = getAcceptedQuotation(opportunityId);
        validateAcceptedQuotation(acceptedQuotation);

        List<QuotationLine__c> quotationLines = getQuotationLines(acceptedQuotation.Id);
        validateQuotationLines(quotationLines);

        Contract__c contractRecord = createContract(opportunityRecord, acceptedQuotation);
        ContractPeriod__c periodRecord = createInitialContractPeriod(contractRecord);
        Invoice__c invoiceRecord = createInvoice(
            opportunityId,
            contractRecord.Id,
            periodRecord.Id,
            acceptedQuotation,
            periodRecord.PeriodStartDate__c,
            periodRecord.PeriodEndDate__c
        );
        Integer lineCount = createInvoiceLines(
            invoiceRecord.Id,
            contractRecord.ContractUpdate__c,
            quotationLines
        );
        createInitialContractLines(contractRecord, periodRecord.Id, invoiceRecord.Id, quotationLines);
        update new ContractPeriod__c(
            Id = periodRecord.Id,
            RelatedInvoice__c = invoiceRecord.Id,
            InvoiceCreationStatus__c = PERIOD_STATUS_CREATED,
            FreeeSyncStatus__c = FREEE_STATUS_NOT_SYNCED
        );

        CreationResult result = new CreationResult();
        result.contractId = contractRecord.Id;
        result.invoiceId = invoiceRecord.Id;
        result.invoiceLineCount = lineCount;
        return result;
    }

    private static Opportunity__c getOpportunity(Id opportunityId) {
        List<Opportunity__c> opportunities = [
            SELECT Id,
                   Name,
                   Account__c,
                   ACV__c,
                   ARR__c,
                   ContractUpdate__c,
                   Description__c,
                   ExpectedDuration__c,
                   MRR__c,
                   Pricebook2__c,
                   StageName__c,
                   StartDate__c,
                   Event__c
            FROM Opportunity__c
            WHERE Id = :opportunityId
            LIMIT 1
        ];

        if (opportunities.isEmpty()) {
            throw new AuraHandledException('対象の取引が見つかりません。');
        }

        return opportunities[0];
    }

    private static void validateOpportunity(Opportunity__c opportunityRecord) {
        List<String> errors = new List<String>();

        if (opportunityRecord.StageName__c != CLOSED_WON) {
            errors.add('取引が受注状態ではありません。');
        }
        if (opportunityRecord.Account__c == null) {
            errors.add('取引先が設定されていません。');
        }
        if (opportunityRecord.StartDate__c == null) {
            errors.add('契約日として使用する開始日が設定されていません。');
        }

        throwIfErrors(errors);
    }

    private static Boolean hasExistingContract(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Contract__c
            WHERE Oppotunity__c = :opportunityId
        ] > 0;
    }

    private static Boolean hasExistingInvoice(Id opportunityId) {
        return [
            SELECT COUNT()
            FROM Invoice__c
            WHERE ParentOpportunity__c = :opportunityId
        ] > 0;
    }

    private static Quotation__c getAcceptedQuotation(Id opportunityId) {
        List<Quotation__c> quotations = [
            SELECT Id,
                   Account__c,
                   Freee_Account_Item_Picklist__c,
                   Freee_Partner_Id__c,
                   Memo__c,
                   Oppotunity__c,
                   Quotation_Status__c,
                   Subject__c
            FROM Quotation__c
            WHERE Oppotunity__c = :opportunityId
              AND Quotation_Status__c = :ACCEPTED
            ORDER BY Issue_Date__c DESC, CreatedDate DESC
            LIMIT 2
        ];

        if (quotations.size() > 1) {
            throw new AuraHandledException('Accepted の見積が複数存在します。1件にしてから契約・請求を作成してください。');
        }
        return quotations.isEmpty() ? null : quotations[0];
    }

    private static void validateAcceptedQuotation(Quotation__c quotationRecord) {
        List<String> errors = new List<String>();

        if (quotationRecord == null) {
            errors.add('Accepted の見積が見つかりません。');
        } else {
            if (quotationRecord.Account__c == null) {
                errors.add('見積に取引先が設定されていません。');
            }
            if (String.isBlank(quotationRecord.Subject__c)) {
                errors.add('見積の件名が設定されていません。');
            }
            if (String.isBlank(quotationRecord.Freee_Account_Item_Picklist__c)) {
                errors.add('見積の Freee計上科目が設定されていません。');
            }
        }

        throwIfErrors(errors);
    }

    private static List<QuotationLine__c> getQuotationLines(Id quotationId) {
        return [
            SELECT Id,
                   Description__c,
                   Freee_Account_Item_Id__c,
                   Line_Amount__c,
                   Product2__c,
                   Quantity__c,
                   Tax_Rate__c,
                   Unit_Price__c,
                   Withholding__c,
                   Product2__r.Name,
                   Product2__r.ProductType__c,
                   Product2__r.BillingTiming__c,
                   Product2__r.AnnualMonthlyPrice__c,
                   Product2__r.MRR_Target__c,
                   Product2__r.ARR_Target__c
            FROM QuotationLine__c
            WHERE Quotation__c = :quotationId
            ORDER BY CreatedDate ASC
        ];
    }

    private static void validateQuotationLines(List<QuotationLine__c> quotationLines) {
        List<String> errors = new List<String>();

        if (quotationLines == null || quotationLines.isEmpty()) {
            errors.add('見積明細がありません。');
        } else {
            for (QuotationLine__c line : quotationLines) {
                if (String.isBlank(line.Description__c)) {
                    errors.add('見積明細の品名が設定されていません。');
                    break;
                }
                if (line.Quantity__c == null || line.Quantity__c <= 0) {
                    errors.add('見積明細の数量は 0 より大きくしてください。');
                    break;
                }
                if (line.Unit_Price__c == null || line.Unit_Price__c <= 0) {
                    errors.add('見積明細の単価は 0 より大きくしてください。');
                    break;
                }
                if (String.isBlank(line.Tax_Rate__c)) {
                    errors.add('見積明細の税率が設定されていません。');
                    break;
                }
            }
        }

        throwIfErrors(errors);
    }

    private static Contract__c createContract(
        Opportunity__c opportunityRecord,
        Quotation__c acceptedQuotation
    ) {
        Contract__c contractRecord = new Contract__c(
            Account__c = opportunityRecord.Account__c,
            ACV__c = opportunityRecord.ACV__c,
            ARR__c = opportunityRecord.ARR__c,
            ContractName__c = buildContractName(opportunityRecord),
            ContractUpdate__c = opportunityRecord.ContractUpdate__c,
            Description__c = opportunityRecord.Description__c,
            EndDate__c = calculateContractEndDate(opportunityRecord),
            Event__c = opportunityRecord.Event__c,
            ExpectedDuration__c = opportunityRecord.ExpectedDuration__c,
            MRR__c = opportunityRecord.MRR__c,
            Oppotunity__c = opportunityRecord.Id,
            Pricebook2__c = opportunityRecord.Pricebook2__c,
            SourceQuotation__c = acceptedQuotation.Id,
            StartDate__c = opportunityRecord.StartDate__c,
            Status__c = CONTRACT_STATUS_DRAFT
        );
        insert contractRecord;
        return contractRecord;
    }

    private static ContractPeriod__c createInitialContractPeriod(Contract__c contractRecord) {
        ContractPeriod__c periodRecord = new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = contractRecord.ContractUpdate__c,
            PeriodStartDate__c = contractRecord.StartDate__c,
            PeriodEndDate__c = calculatePeriodEndDate(
                contractRecord.StartDate__c,
                contractRecord.ContractUpdate__c
            ),
            RenewalCount__c = 0,
            IsInitialPeriod__c = true,
            InvoiceCreationStatus__c = '未作成',
            FreeeSyncStatus__c = FREEE_STATUS_NOT_SYNCED
        );
        insert periodRecord;
        return periodRecord;
    }

    private static Invoice__c createInvoice(
        Id opportunityId,
        Id contractId,
        Id contractPeriodId,
        Quotation__c acceptedQuotation
        ,
        Date targetPeriodStartDate,
        Date targetPeriodEndDate
    ) {
        Date billingDate = calculateInitialBillingDate(Date.today());
        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = acceptedQuotation.Account__c,
            Billing_Date__c = billingDate,
            ContractPeriod__c = contractPeriodId,
            Freee_Account_Item_Picklist__c = normalizeInvoiceAccountItemPicklist(
                acceptedQuotation.Freee_Account_Item_Picklist__c
            ),
            Freee_Invoice_Status__c = SEND_WAITING,
            Freee_Partner_Id__c = acceptedQuotation.Freee_Partner_Id__c,
            Freee_Sync_Status__c = 'Processing',
            Memo__c = acceptedQuotation.Memo__c,
            ParentContract__c = contractId,
            ParentOpportunity__c = opportunityId,
            PaymentStatus__c = PAYMENT_WAITING,
            Payment_Date__c = calculatePaymentDueDate(billingDate),
            Subject__c = acceptedQuotation.Subject__c
            ,
            TargetPeriodStartDate__c = targetPeriodStartDate,
            TargetPeriodEndDate__c = targetPeriodEndDate
        );
        insert invoiceRecord;
        return invoiceRecord;
    }

    private static Integer createInvoiceLines(
        Id invoiceId,
        String contractUpdate,
        List<QuotationLine__c> quotationLines
    ) {
        List<InvoiceLine__c> invoiceLinesToInsert = new List<InvoiceLine__c>();

        if (contractUpdate == UPDATE_YEARLY) {
            Decimal annualAmount = 0;
            List<String> annualNames = new List<String>();
            for (QuotationLine__c quotationLine : quotationLines) {
                if (isInitialFee(quotationLine)) {
                    invoiceLinesToInsert.add(buildInvoiceLine(invoiceId, quotationLine, '初期費用'));
                } else {
                    annualAmount += getLineAmount(quotationLine);
                    annualNames.add(getProductOrLineName(quotationLine));
                }
            }
            if (annualAmount > 0) {
                invoiceLinesToInsert.add(new InvoiceLine__c(
                    AmountWithTax__c = annualAmount + calculateTax(annualAmount),
                    Description__c = buildAnnualInvoiceLineName(annualNames),
                    DiscountedUnitPrice__c = annualAmount,
                    Invoice__c = invoiceId,
                    LineType__c = '年間利用料',
                    Quantity__c = 1,
                    TaxAmount__c = calculateTax(annualAmount),
                    Tax_Rate__c = TAX_RATE,
                    Unit_Price__c = annualAmount
                ));
            }
        } else {
            for (QuotationLine__c quotationLine : quotationLines) {
                invoiceLinesToInsert.add(buildInvoiceLine(
                    invoiceId,
                    quotationLine,
                    isInitialFee(quotationLine) ? '初期費用' : '継続費用'
                ));
            }
        }

        if (!invoiceLinesToInsert.isEmpty()) {
            insert invoiceLinesToInsert;
        }

        return invoiceLinesToInsert.size();
    }

    private static InvoiceLine__c buildInvoiceLine(
        Id invoiceId,
        QuotationLine__c quotationLine,
        String lineType
    ) {
        Decimal amount = getLineAmount(quotationLine);
        Decimal taxAmount = calculateTax(amount);
        return new InvoiceLine__c(
            AmountWithTax__c = amount + taxAmount,
            Description__c = quotationLine.Description__c,
            DiscountedUnitPrice__c = quotationLine.Unit_Price__c,
            Freee_Account_Item_Id__c = quotationLine.Freee_Account_Item_Id__c,
            Invoice__c = invoiceId,
            LineType__c = lineType,
            Product2__c = quotationLine.Product2__c,
            Quantity__c = quotationLine.Quantity__c,
            QuotationLine__c = quotationLine.Id,
            TaxAmount__c = taxAmount,
            Tax_Rate__c = Decimal.valueOf(quotationLine.Tax_Rate__c),
            Unit_Price__c = quotationLine.Unit_Price__c,
            Withholding__c = quotationLine.Withholding__c
        );
    }

    private static void createInitialContractLines(
        Contract__c contractRecord,
        Id contractPeriodId,
        Id invoiceId,
        List<QuotationLine__c> quotationLines
    ) {
        List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();
        Integer monthCount = contractRecord.ContractUpdate__c == UPDATE_YEARLY ? 12 : 1;
        Date periodMonth = firstDayOfMonth(contractRecord.StartDate__c);

        for (Integer monthIndex = 0; monthIndex < monthCount; monthIndex++) {
            Date monthStart = periodMonth.addMonths(monthIndex);
            for (QuotationLine__c quotationLine : quotationLines) {
                if (isInitialFee(quotationLine) && monthIndex > 0) {
                    continue;
                }

                Decimal revenueAmount = calculateMonthlyRevenueAmount(
                    quotationLine,
                    contractRecord.ContractUpdate__c
                );
                String yearMonth = formatYearMonth(monthStart);
                linesToInsert.add(new ContractLineItem__c(
                    Account__c = contractRecord.Account__c,
                    ARR_Target__c = quotationLine.Product2__r == null
                        ? false
                        : quotationLine.Product2__r.ARR_Target__c,
                    ContractPeriod__c = contractPeriodId,
                    ContractYearMonth__c = yearMonth,
                    InitialFee__c = isInitialFee(quotationLine),
                    InvoiceStatus__c = INVOICE_STATUS_BILLED,
                    MasterContract__c = contractRecord.Id,
                    Month__c = yearMonth,
                    MRR_Target__c = quotationLine.Product2__r == null
                        ? false
                        : quotationLine.Product2__r.MRR_Target__c,
                    PeopleNumber__c = quotationLine.Quantity__c,
                    PeriodStartDate__c = monthStart,
                    PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
                    Plan__c = contractRecord.Plan__c,
                    Product2__c = quotationLine.Product2__c,
                    QuotationLine__c = quotationLine.Id,
                    RelatedInvoice__c = invoiceId,
                    RevenueAmount__c = revenueAmount,
                    Total__c = revenueAmount
                ));
            }
        }

        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }
    }

    private static String buildContractName(Opportunity__c opportunityRecord) {
        if (opportunityRecord.StartDate__c == null) {
            return opportunityRecord.Name;
        }

        Date contractDate = opportunityRecord.StartDate__c;
        String month = String.valueOf(contractDate.month()).leftPad(2, '0');
        String day = String.valueOf(contractDate.day()).leftPad(2, '0');
        return opportunityRecord.Name
            + '_'
            + String.valueOf(contractDate.year())
            + '-'
            + month
            + '-'
            + day;
    }

    private static Date calculateContractEndDate(Opportunity__c opportunityRecord) {
        if (opportunityRecord.StartDate__c == null) {
            return null;
        }
        if (opportunityRecord.ContractUpdate__c == UPDATE_YEARLY) {
            return opportunityRecord.StartDate__c.addYears(1).addDays(-1);
        }
        return opportunityRecord.StartDate__c.addMonths(1).addDays(-1);
    }

    private static Date calculatePeriodEndDate(Date startDate, String contractUpdate) {
        if (startDate == null) {
            return null;
        }
        if (contractUpdate == UPDATE_YEARLY) {
            return startDate.addYears(1).addDays(-1);
        }
        return startDate.addMonths(1).addDays(-1);
    }

    private static Date calculateInitialBillingDate(Date baseDate) {
        Date candidate = Date.newInstance(baseDate.year(), baseDate.month(), 20);
        if (candidate < baseDate) {
            candidate = candidate.addMonths(1);
        }
        return previousBusinessDay(candidate);
    }

    private static Date calculatePaymentDueDate(Date billingDate) {
        if (billingDate == null) {
            return null;
        }
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
        Date weekStart = sourceDate.toStartOfWeek();
        Integer dayOffset = weekStart.daysBetween(sourceDate);
        return dayOffset == 0 || dayOffset == 6;
    }

    private static Decimal calculateMonthlyRevenueAmount(
        QuotationLine__c quotationLine,
        String contractUpdate
    ) {
        if (contractUpdate == UPDATE_YEARLY && !isInitialFee(quotationLine)) {
            if (quotationLine.Product2__r != null
                && quotationLine.Product2__r.AnnualMonthlyPrice__c != null
            ) {
                return quotationLine.Product2__r.AnnualMonthlyPrice__c
                    * nullToOne(quotationLine.Quantity__c);
            }
            return getLineAmount(quotationLine) / 12;
        }
        return getLineAmount(quotationLine);
    }

    private static Boolean isInitialFee(QuotationLine__c quotationLine) {
        if (quotationLine.Product2__r == null) {
            return false;
        }
        return quotationLine.Product2__r.ProductType__c == '初期費用'
            || quotationLine.Product2__r.BillingTiming__c == '初回のみ';
    }

    private static Decimal getLineAmount(QuotationLine__c quotationLine) {
        if (quotationLine.Line_Amount__c != null) {
            return quotationLine.Line_Amount__c;
        }
        return nullToZero(quotationLine.Unit_Price__c)
            * nullToOne(quotationLine.Quantity__c);
    }

    private static Decimal calculateTax(Decimal amount) {
        if (amount == null) {
            return 0;
        }
        return (amount * TAX_RATE / 100).round(System.RoundingMode.CEILING);
    }

    private static String buildAnnualInvoiceLineName(List<String> sourceNames) {
        List<String> names = new List<String>();
        Set<String> seen = new Set<String>();
        for (String sourceName : sourceNames) {
            if (String.isBlank(sourceName) || seen.contains(sourceName)) {
                continue;
            }
            names.add(sourceName);
            seen.add(sourceName);
        }
        return (names.isEmpty() ? '年間利用料' : String.join(names, '・') + ' 年間利用料');
    }

    private static String getProductOrLineName(QuotationLine__c quotationLine) {
        if (quotationLine.Product2__r != null
            && !String.isBlank(quotationLine.Product2__r.Name)
        ) {
            return quotationLine.Product2__r.Name;
        }
        return quotationLine.Description__c;
    }

    private static Date firstDayOfMonth(Date sourceDate) {
        return Date.newInstance(sourceDate.year(), sourceDate.month(), 1);
    }

    private static String formatYearMonth(Date sourceDate) {
        return String.valueOf(sourceDate.year()) + '/' + String.valueOf(sourceDate.month());
    }

    private static Decimal nullToZero(Decimal sourceValue) {
        return sourceValue == null ? 0 : sourceValue;
    }

    private static Decimal nullToOne(Decimal sourceValue) {
        return sourceValue == null ? 1 : sourceValue;
    }

    private static String normalizeInvoiceAccountItemPicklist(String sourceValue) {
        if (String.isBlank(sourceValue)) {
            return sourceValue;
        }
        if (sourceValue == QUOTATION_ACCOUNT_ITEM_SALES) {
            return INVOICE_ACCOUNT_ITEM_SALES;
        }
        return sourceValue;
    }

    private static void throwIfErrors(List<String> errors) {
        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '\n'));
        }
    }
}
