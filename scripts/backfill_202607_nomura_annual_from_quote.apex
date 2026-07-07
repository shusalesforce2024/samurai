Boolean dryRun = true;
Id contractId = 'a04RB00000lZ54zYAC';
String targetYearMonth = '2026/07';
Date monthStart = Date.newInstance(2026, 7, 1);
Date monthEnd = Date.newInstance(2026, 7, 31);

Contract__c contractRecord = [
    SELECT Id,
           Name,
           Account__c,
           ContractName__c,
           ContractUpdate__c,
           Plan__c,
           SourceQuotation__c
    FROM Contract__c
    WHERE Id = :contractId
    LIMIT 1
];

ContractPeriod__c periodRecord = [
    SELECT Id,
           Contract__c,
           PeriodStartDate__c,
           PeriodEndDate__c
    FROM ContractPeriod__c
    WHERE Contract__c = :contractId
      AND PeriodStartDate__c <= :monthStart
      AND PeriodEndDate__c >= :monthEnd
    LIMIT 1
];

Set<Id> existingQuotationLineIds = new Set<Id>();
for (ContractLineItem__c existingLine : [
    SELECT QuotationLine__c
    FROM ContractLineItem__c
    WHERE MasterContract__c = :contractId
      AND ContractYearMonth__c = :targetYearMonth
      AND QuotationLine__c != null
]) {
    existingQuotationLineIds.add(existingLine.QuotationLine__c);
}

List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();
for (QuotationLine__c quotationLine : [
    SELECT Id,
           Name,
           Line_Amount__c,
           ProductMaster__c,
           ProductMaster__r.MRR_Target__c,
           ProductMaster__r.ARR_Target__c,
           Quantity__c,
           Unit_Price__c
    FROM QuotationLine__c
    WHERE Quotation__c = :contractRecord.SourceQuotation__c
    ORDER BY CreatedDate ASC
]) {
    if (existingQuotationLineIds.contains(quotationLine.Id)) {
        continue;
    }

    Decimal annualAmount = quotationLine.Line_Amount__c == null
        ? (quotationLine.Unit_Price__c == null ? 0 : quotationLine.Unit_Price__c)
            * (quotationLine.Quantity__c == null ? 1 : quotationLine.Quantity__c)
        : quotationLine.Line_Amount__c;
    Decimal monthlyAmount = annualAmount / 12;
    String contractName = String.isBlank(contractRecord.ContractName__c)
        ? contractRecord.Name
        : contractRecord.ContractName__c;
    String lineName = contractName + '_' + targetYearMonth;
    if (lineName.length() > 80) {
        lineName = lineName.substring(0, 80);
    }

    linesToInsert.add(new ContractLineItem__c(
        Name = lineName,
        Account__c = contractRecord.Account__c,
        ARR_Target__c = quotationLine.ProductMaster__r == null ? false : quotationLine.ProductMaster__r.ARR_Target__c,
        ContractPeriod__c = periodRecord.Id,
        ContractYearMonth__c = targetYearMonth,
        InitialFee__c = false,
        MasterContract__c = contractRecord.Id,
        Month__c = targetYearMonth,
        MRR_Target__c = quotationLine.ProductMaster__r == null ? false : quotationLine.ProductMaster__r.MRR_Target__c,
        PeopleNumber__c = quotationLine.Quantity__c,
        PeriodStartDate__c = monthStart,
        PeriodEndDate__c = monthEnd,
        Plan__c = contractRecord.Plan__c,
        ProductMaster__c = quotationLine.ProductMaster__c,
        QuotationLine__c = quotationLine.Id,
        RevenueAmount__c = monthlyAmount,
        Total__c = monthlyAmount
    ));
    System.debug('INSERT annual quote CLI ql=' + quotationLine.Name + ' annual=' + annualAmount + ' monthly=' + monthlyAmount);
}

System.debug('dryRun=' + dryRun);
System.debug('linesToInsert=' + linesToInsert.size());

if (!dryRun) {
    Savepoint sp = Database.setSavepoint();
    try {
        if (!linesToInsert.isEmpty()) {
            insert linesToInsert;
        }
        System.debug('DONE insertedLines=' + linesToInsert.size());
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug(LoggingLevel.ERROR, e.getTypeName() + ': ' + e.getMessage() + ' line=' + e.getLineNumber());
        throw e;
    }
}
