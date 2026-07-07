Boolean dryRun = true;

List<Contract__c> targetContracts = [
    SELECT Id,
           Name,
           Account__c,
           ContractName__c,
           ContractUpdate__c,
           Payment__c,
           Plan__c,
           StartDate__c,
           Status__c
    FROM Contract__c
    WHERE Id IN (
        SELECT ParentContract__c
        FROM Invoice__c
        WHERE ParentContract__c != null
    )
    AND Id NOT IN (
        SELECT MasterContract__c
        FROM ContractLineItem__c
        WHERE MasterContract__c != null
    )
];

Set<Id> targetContractIds = new Set<Id>();
Map<Id, Contract__c> contractById = new Map<Id, Contract__c>();
for (Contract__c contractRecord : targetContracts) {
    targetContractIds.add(contractRecord.Id);
    contractById.put(contractRecord.Id, contractRecord);
}

List<Invoice__c> targetInvoices = targetContractIds.isEmpty()
    ? new List<Invoice__c>()
    : [
        SELECT Id,
               Name,
               Account__c,
               Billing_Date__c,
               Freee_Invoice_Status__c,
               Freee_Sync_Status__c,
               InvoiceAmount__c,
               NumberOfPeople__c,
               ParentContract__c,
               PaymentStatus__c,
               Payment_Type__c,
               PaymentReceivedDate__c,
               Subject__c,
               TargetPeriodEndDate__c,
               TargetPeriodStartDate__c,
               TotalAmount__c
        FROM Invoice__c
        WHERE ParentContract__c IN :targetContractIds
        ORDER BY ParentContract__c, Billing_Date__c, Id
    ];

Set<Id> invoiceIds = new Set<Id>();
for (Invoice__c invoiceRecord : targetInvoices) {
    invoiceIds.add(invoiceRecord.Id);
}

Map<Id, InvoiceLine__c> firstLineByInvoiceId = new Map<Id, InvoiceLine__c>();
if (!invoiceIds.isEmpty()) {
    for (InvoiceLine__c lineRecord : [
        SELECT Id,
               Invoice__c,
               ProductMaster__c,
               QuotationLine__c
        FROM InvoiceLine__c
        WHERE Invoice__c IN :invoiceIds
        ORDER BY Invoice__c, CreatedDate, Id
    ]) {
        if (!firstLineByInvoiceId.containsKey(lineRecord.Invoice__c)) {
            firstLineByInvoiceId.put(lineRecord.Invoice__c, lineRecord);
        }
    }
}

Map<String, ContractPeriod__c> periodByKey = new Map<String, ContractPeriod__c>();
if (!targetContractIds.isEmpty()) {
    for (ContractPeriod__c periodRecord : [
        SELECT Id,
               Contract__c,
               PeriodStartDate__c
        FROM ContractPeriod__c
        WHERE Contract__c IN :targetContractIds
    ]) {
        periodByKey.put(String.valueOf(periodRecord.Contract__c) + ':' + String.valueOf(periodRecord.PeriodStartDate__c), periodRecord);
    }
}

List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
List<Invoice__c> invoicesNeedingLine = new List<Invoice__c>();
Map<Id, Date> monthStartByInvoiceId = new Map<Id, Date>();
Map<Id, String> yearMonthByInvoiceId = new Map<Id, String>();
Map<Id, ContractPeriod__c> periodByInvoiceId = new Map<Id, ContractPeriod__c>();

for (Invoice__c invoiceRecord : targetInvoices) {
    Date sourceDate = invoiceRecord.TargetPeriodStartDate__c;
    if (sourceDate == null) {
        sourceDate = invoiceRecord.Billing_Date__c;
    }
    if (sourceDate == null) {
        System.debug(LoggingLevel.WARN, 'Skipped invoice without target month. invoiceId=' + invoiceRecord.Id);
        continue;
    }

    Date monthStart = Date.newInstance(sourceDate.year(), sourceDate.month(), 1);
    String yearMonth = String.valueOf(monthStart.year()) + '/' + String.valueOf(monthStart.month()).leftPad(2, '0');
    String periodKey = String.valueOf(invoiceRecord.ParentContract__c) + ':' + String.valueOf(monthStart);
    ContractPeriod__c periodRecord = periodByKey.get(periodKey);
    if (periodRecord == null) {
        Contract__c contractRecord = contractById.get(invoiceRecord.ParentContract__c);
        periodRecord = new ContractPeriod__c(
            Contract__c = invoiceRecord.ParentContract__c,
            ContractUpdate__c = contractRecord == null ? null : contractRecord.ContractUpdate__c,
            IsInitialPeriod__c = false,
            PeriodStartDate__c = monthStart,
            PeriodEndDate__c = monthStart.addMonths(1).addDays(-1)
        );
        periodsToInsert.add(periodRecord);
        periodByKey.put(periodKey, periodRecord);
    }
    invoicesNeedingLine.add(invoiceRecord);
    monthStartByInvoiceId.put(invoiceRecord.Id, monthStart);
    yearMonthByInvoiceId.put(invoiceRecord.Id, yearMonth);
    periodByInvoiceId.put(invoiceRecord.Id, periodRecord);
}

System.debug('dryRun=' + dryRun);
System.debug('targetContracts=' + targetContracts.size());
System.debug('targetInvoices=' + targetInvoices.size());
System.debug('invoicesNeedingLine=' + invoicesNeedingLine.size());
System.debug('periodsToInsert=' + periodsToInsert.size());

if (!dryRun) {
    Savepoint sp = Database.setSavepoint();
    try {
        if (!periodsToInsert.isEmpty()) {
            insert periodsToInsert;
        }

        List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();
        for (Invoice__c invoiceRecord : invoicesNeedingLine) {
            Contract__c contractRecord = contractById.get(invoiceRecord.ParentContract__c);
            Date monthStart = monthStartByInvoiceId.get(invoiceRecord.Id);
            String yearMonth = yearMonthByInvoiceId.get(invoiceRecord.Id);
            ContractPeriod__c periodRecord = periodByInvoiceId.get(invoiceRecord.Id);
            InvoiceLine__c firstLine = firstLineByInvoiceId.get(invoiceRecord.Id);
            Decimal amount = invoiceRecord.TotalAmount__c;
            if (amount == null) {
                amount = invoiceRecord.InvoiceAmount__c;
            }
            String contractName = contractRecord == null || String.isBlank(contractRecord.ContractName__c)
                ? String.valueOf(invoiceRecord.ParentContract__c)
                : contractRecord.ContractName__c;
            String lineName = contractName + '_' + yearMonth + '_' + invoiceRecord.Name;
            if (lineName.length() > 80) {
                lineName = lineName.substring(0, 80);
            }

            linesToInsert.add(new ContractLineItem__c(
                Name = lineName,
                Account__c = invoiceRecord.Account__c == null && contractRecord != null
                    ? contractRecord.Account__c
                    : invoiceRecord.Account__c,
                ContractPeriod__c = periodRecord.Id,
                ContractYearMonth__c = yearMonth,
                InitialFee__c = false,
                MasterContract__c = invoiceRecord.ParentContract__c,
                Month__c = yearMonth,
                PeopleNumber__c = invoiceRecord.NumberOfPeople__c,
                PeriodStartDate__c = monthStart,
                PeriodEndDate__c = monthStart.addMonths(1).addDays(-1),
                Plan__c = contractRecord == null ? null : contractRecord.Plan__c,
                ProductMaster__c = firstLine == null ? null : firstLine.ProductMaster__c,
                QuotationLine__c = firstLine == null ? null : firstLine.QuotationLine__c,
                RelatedInvoice__c = invoiceRecord.Id,
                RevenueAmount__c = amount,
                Total__c = amount
            ));
        }

        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }
        System.debug('insertedPeriods=' + periodsToInsert.size());
        System.debug('insertedLines=' + linesToInsert.size());
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug(LoggingLevel.ERROR, e.getTypeName() + ': ' + e.getMessage() + ' line=' + e.getLineNumber());
        throw e;
    }
}
