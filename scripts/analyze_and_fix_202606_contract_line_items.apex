Boolean dryRun = true;
String targetYearMonth = '2026/06';
Date monthStart = Date.newInstance(2026, 6, 1);
Date monthEnd = Date.newInstance(2026, 6, 30);

List<Invoice__c> invoices = [
    SELECT Id,
           Name,
           Account__c,
           Account__r.Name,
           Billing_Date__c,
           ContractPeriod__c,
           Freee_Invoice_Id__c,
           Freee_Invoice_Number__c,
           InvoiceAmount__c,
           NumberOfPeople__c,
           ParentContract__c,
           ParentContract__r.Account__c,
           ParentContract__r.ContractName__c,
           ParentContract__r.ContractUpdate__c,
           ParentContract__r.Plan__c,
           TargetPeriodStartDate__c,
           TargetPeriodEndDate__c,
           TotalAmount__c
    FROM Invoice__c
    WHERE Billing_Date__c >= :monthStart
      AND Billing_Date__c <= :monthEnd
      AND ParentContract__c != null
      AND Id NOT IN (
          SELECT RelatedInvoice__c
          FROM ContractLineItem__c
          WHERE RelatedInvoice__c != null
      )
    ORDER BY Billing_Date__c, Freee_Invoice_Id__c
];

Set<Id> contractIds = new Set<Id>();
Set<Id> invoiceIds = new Set<Id>();
for (Invoice__c invoiceRecord : invoices) {
    contractIds.add(invoiceRecord.ParentContract__c);
    invoiceIds.add(invoiceRecord.Id);
}

Map<Id, InvoiceLine__c> firstLineByInvoiceId = new Map<Id, InvoiceLine__c>();
if (!invoiceIds.isEmpty()) {
    for (InvoiceLine__c lineRecord : [
        SELECT Id, Invoice__c, ProductMaster__c, QuotationLine__c
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
if (!contractIds.isEmpty()) {
    for (ContractPeriod__c periodRecord : [
        SELECT Id, Contract__c, PeriodStartDate__c, PeriodEndDate__c
        FROM ContractPeriod__c
        WHERE Contract__c IN :contractIds
    ]) {
        periodByKey.put(String.valueOf(periodRecord.Contract__c) + ':' + String.valueOf(periodRecord.PeriodStartDate__c), periodRecord);
    }
}

Map<Id, List<ContractLineItem__c>> existingLinesByContract = new Map<Id, List<ContractLineItem__c>>();
if (!contractIds.isEmpty()) {
    for (ContractLineItem__c lineRecord : [
        SELECT Id,
               MasterContract__c,
               ContractPeriod__c,
               ContractYearMonth__c,
               RelatedInvoice__c,
               ProductMaster__c,
               RevenueAmount__c,
               Total__c
        FROM ContractLineItem__c
        WHERE MasterContract__c IN :contractIds
          AND ContractYearMonth__c = :targetYearMonth
    ]) {
        if (!existingLinesByContract.containsKey(lineRecord.MasterContract__c)) {
            existingLinesByContract.put(lineRecord.MasterContract__c, new List<ContractLineItem__c>());
        }
        existingLinesByContract.get(lineRecord.MasterContract__c).add(lineRecord);
    }
}

List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
Map<Id, ContractPeriod__c> periodByInvoiceId = new Map<Id, ContractPeriod__c>();
List<ContractLineItem__c> linesToUpdate = new List<ContractLineItem__c>();
List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();

for (Invoice__c invoiceRecord : invoices) {
    Decimal amount = invoiceRecord.TotalAmount__c == null ? invoiceRecord.InvoiceAmount__c : invoiceRecord.TotalAmount__c;
    InvoiceLine__c firstLine = firstLineByInvoiceId.get(invoiceRecord.Id);
    ContractLineItem__c match = null;
    List<ContractLineItem__c> candidateLines = existingLinesByContract.get(invoiceRecord.ParentContract__c);
    if (candidateLines != null) {
        for (ContractLineItem__c candidate : candidateLines) {
            if (candidate.RelatedInvoice__c != null) {
                continue;
            }
            Decimal candidateAmount = candidate.Total__c == null ? candidate.RevenueAmount__c : candidate.Total__c;
            Boolean amountMatches = amount == null || candidateAmount == null || candidateAmount == amount;
            Boolean productMatches = firstLine == null
                || firstLine.ProductMaster__c == null
                || candidate.ProductMaster__c == null
                || candidate.ProductMaster__c == firstLine.ProductMaster__c;
            if (amountMatches && productMatches) {
                match = candidate;
                break;
            }
        }
    }

    if (match != null) {
        linesToUpdate.add(new ContractLineItem__c(
            Id = match.Id,
            RelatedInvoice__c = invoiceRecord.Id,
            ProductMaster__c = match.ProductMaster__c == null && firstLine != null ? firstLine.ProductMaster__c : match.ProductMaster__c
        ));
        System.debug('LINK existing CLI invoice=' + invoiceRecord.Name + ' freee=' + invoiceRecord.Freee_Invoice_Id__c + ' cli=' + match.Id + ' account=' + invoiceRecord.Account__r.Name + ' amount=' + amount);
        continue;
    }

    ContractPeriod__c periodRecord;
    if (invoiceRecord.ContractPeriod__c != null) {
        periodRecord = new ContractPeriod__c(Id = invoiceRecord.ContractPeriod__c);
    } else {
        String periodKey = String.valueOf(invoiceRecord.ParentContract__c) + ':' + String.valueOf(monthStart);
        periodRecord = periodByKey.get(periodKey);
    }
    if (periodRecord == null) {
        periodRecord = new ContractPeriod__c(
            Contract__c = invoiceRecord.ParentContract__c,
            ContractUpdate__c = invoiceRecord.ParentContract__r.ContractUpdate__c,
            IsInitialPeriod__c = false,
            PeriodStartDate__c = monthStart,
            PeriodEndDate__c = monthEnd
        );
        periodsToInsert.add(periodRecord);
        periodByKey.put(String.valueOf(invoiceRecord.ParentContract__c) + ':' + String.valueOf(monthStart), periodRecord);
    }
    periodByInvoiceId.put(invoiceRecord.Id, periodRecord);

    String contractName = String.isBlank(invoiceRecord.ParentContract__r.ContractName__c)
        ? String.valueOf(invoiceRecord.ParentContract__c)
        : invoiceRecord.ParentContract__r.ContractName__c;
    String lineName = 'Mig_freee請求移行_' + contractName + '_' + targetYearMonth + '_' + invoiceRecord.Name;
    if (lineName.length() > 80) {
        lineName = lineName.substring(0, 80);
    }
    linesToInsert.add(new ContractLineItem__c(
        Name = lineName,
        Account__c = invoiceRecord.Account__c == null ? invoiceRecord.ParentContract__r.Account__c : invoiceRecord.Account__c,
        ContractPeriod__c = periodRecord.Id,
        ContractYearMonth__c = targetYearMonth,
        InitialFee__c = false,
        MasterContract__c = invoiceRecord.ParentContract__c,
        Month__c = targetYearMonth,
        PeopleNumber__c = invoiceRecord.NumberOfPeople__c,
        PeriodStartDate__c = monthStart,
        PeriodEndDate__c = monthEnd,
        Plan__c = invoiceRecord.ParentContract__r.Plan__c,
        ProductMaster__c = firstLine == null ? null : firstLine.ProductMaster__c,
        QuotationLine__c = firstLine == null ? null : firstLine.QuotationLine__c,
        RelatedInvoice__c = invoiceRecord.Id,
        RevenueAmount__c = amount,
        Total__c = amount
    ));
    System.debug('INSERT new CLI invoice=' + invoiceRecord.Name + ' freee=' + invoiceRecord.Freee_Invoice_Id__c + ' account=' + invoiceRecord.Account__r.Name + ' amount=' + amount);
}

System.debug('dryRun=' + dryRun);
System.debug('targetInvoices=' + invoices.size());
System.debug('existingLinksToUpdate=' + linesToUpdate.size());
System.debug('periodsToInsert=' + periodsToInsert.size());
System.debug('linesToInsert=' + linesToInsert.size());

if (!dryRun) {
    Savepoint sp = Database.setSavepoint();
    try {
        if (!periodsToInsert.isEmpty()) {
            insert periodsToInsert;
        }
        if (!linesToUpdate.isEmpty()) {
            update linesToUpdate;
        }
        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }
        System.debug('DONE updated=' + linesToUpdate.size() + ' insertedPeriods=' + periodsToInsert.size() + ' insertedLines=' + linesToInsert.size());
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug(LoggingLevel.ERROR, e.getTypeName() + ': ' + e.getMessage() + ' line=' + e.getLineNumber());
        throw e;
    }
}
