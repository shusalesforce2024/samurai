Boolean dryRun = true;
String targetYearMonth = '2026/06';
Date monthStart = Date.newInstance(2026, 6, 1);
Date monthEnd = Date.newInstance(2026, 6, 30);

List<Contract__c> contracts = [
    SELECT Id,
           Name,
           Account__c,
           ContractName__c,
           ContractUpdate__c,
           Plan__c,
           StartDate__c,
           Status__c
    FROM Contract__c
    WHERE Status__c = 'Activated'
      AND StartDate__c <= :monthEnd
      AND Id IN (
          SELECT MasterContract__c
          FROM ContractLineItem__c
          WHERE MasterContract__c != null
      )
      AND Id NOT IN (
          SELECT MasterContract__c
          FROM ContractLineItem__c
          WHERE ContractYearMonth__c = :targetYearMonth
            AND MasterContract__c != null
      )
    ORDER BY StartDate__c, Name
];

Set<Id> contractIds = new Set<Id>();
Map<Id, Contract__c> contractById = new Map<Id, Contract__c>();
for (Contract__c contractRecord : contracts) {
    contractIds.add(contractRecord.Id);
    contractById.put(contractRecord.Id, contractRecord);
}

Map<Id, Map<String, ContractLineItem__c>> latestTemplateByContractAndProduct =
    new Map<Id, Map<String, ContractLineItem__c>>();
if (!contractIds.isEmpty()) {
    for (ContractLineItem__c templateLine : [
        SELECT Id,
               Account__c,
               ContractPeriod__c,
               MasterContract__c,
               PeopleNumber__c,
               PeriodStartDate__c,
               Plan__c,
               ProductMaster__c,
               QuotationLine__c,
               RevenueAmount__c,
               Total__c
        FROM ContractLineItem__c
        WHERE MasterContract__c IN :contractIds
          AND ContractYearMonth__c != :targetYearMonth
        ORDER BY MasterContract__c, ProductMaster__c, PeriodStartDate__c DESC, CreatedDate DESC
    ]) {
        if (!latestTemplateByContractAndProduct.containsKey(templateLine.MasterContract__c)) {
            latestTemplateByContractAndProduct.put(templateLine.MasterContract__c, new Map<String, ContractLineItem__c>());
        }
        String productKey = String.valueOf(templateLine.ProductMaster__c);
        Map<String, ContractLineItem__c> byProduct = latestTemplateByContractAndProduct.get(templateLine.MasterContract__c);
        if (!byProduct.containsKey(productKey)) {
            byProduct.put(productKey, templateLine);
        }
    }
}

List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();
List<String> skippedContracts = new List<String>();

for (Contract__c contractRecord : contracts) {
    Map<String, ContractLineItem__c> templateByProduct =
        latestTemplateByContractAndProduct.get(contractRecord.Id);
    if (templateByProduct == null || templateByProduct.isEmpty()) {
        skippedContracts.add(contractRecord.Name + ':' + contractRecord.ContractName__c);
        continue;
    }

    for (ContractLineItem__c templateLine : templateByProduct.values()) {
        Decimal amount = templateLine.Total__c == null ? templateLine.RevenueAmount__c : templateLine.Total__c;
        String contractName = String.isBlank(contractRecord.ContractName__c)
            ? contractRecord.Name
            : contractRecord.ContractName__c;
        String lineName = contractName + '_' + targetYearMonth;
        if (lineName.length() > 80) {
            lineName = lineName.substring(0, 80);
        }

        linesToInsert.add(new ContractLineItem__c(
            Name = lineName,
            Account__c = templateLine.Account__c == null ? contractRecord.Account__c : templateLine.Account__c,
            ContractPeriod__c = templateLine.ContractPeriod__c,
            ContractYearMonth__c = targetYearMonth,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            Month__c = targetYearMonth,
            PeopleNumber__c = templateLine.PeopleNumber__c,
            PeriodStartDate__c = monthStart,
            PeriodEndDate__c = monthEnd,
            Plan__c = templateLine.Plan__c == null ? contractRecord.Plan__c : templateLine.Plan__c,
            ProductMaster__c = templateLine.ProductMaster__c,
            QuotationLine__c = templateLine.QuotationLine__c,
            RevenueAmount__c = amount,
            Total__c = amount
        ));
        System.debug('INSERT template CLI contract=' + contractRecord.Name + ' account=' + contractRecord.ContractName__c + ' product=' + templateLine.ProductMaster__c + ' amount=' + amount);
    }
}

System.debug('dryRun=' + dryRun);
System.debug('targetContracts=' + contracts.size());
System.debug('linesToInsert=' + linesToInsert.size());
System.debug('skippedContracts=' + skippedContracts.size() + ' ' + String.join(skippedContracts, ' / '));

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
