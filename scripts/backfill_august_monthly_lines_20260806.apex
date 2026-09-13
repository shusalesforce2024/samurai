Date targetStart = Date.newInstance(2026, 8, 1);
Date targetEnd = Date.newInstance(2026, 8, 31);
String targetYearMonth = '2026/08';

List<Contract__c> contracts = [
    SELECT Id, Name, ContractName__c, Account__c, ContractUpdate__c, Plan__c, StartDate__c
    FROM Contract__c
    WHERE Status__c = 'Activated'
      AND StartDate__c <= :targetEnd
      AND ContractUpdate__c IN ('月', '年')
      AND Id NOT IN (
          SELECT MasterContract__c
          FROM ContractLineItem__c
          WHERE Month__c = :targetYearMonth
      )
];
Set<Id> contractIds = new Map<Id, Contract__c>(contracts).keySet();
Map<Id, Contract__c> contractById = new Map<Id, Contract__c>(contracts);

Map<Id, String> latestMonthByContract = new Map<Id, String>();
Map<Id, List<ContractLineItem__c>> templatesByContract = new Map<Id, List<ContractLineItem__c>>();
for (ContractLineItem__c line : [
    SELECT Id, MasterContract__c, Month__c, ProductMaster__c, QuotationLine__c,
           ARR_Target__c, MRR_Target__c, InitialFee__c, PeopleNumber__c,
           Plan__c, RevenueAmount__c, Total__c
    FROM ContractLineItem__c
    WHERE MasterContract__c IN :contractIds
      AND Month__c < :targetYearMonth
    ORDER BY MasterContract__c, Month__c DESC
]) {
    if (!latestMonthByContract.containsKey(line.MasterContract__c)) {
        latestMonthByContract.put(line.MasterContract__c, line.Month__c);
        templatesByContract.put(line.MasterContract__c, new List<ContractLineItem__c>());
    }
    if (line.Month__c == latestMonthByContract.get(line.MasterContract__c)) {
        templatesByContract.get(line.MasterContract__c).add(line);
    }
}

Map<Id, List<ContractPeriod__c>> augustPeriodsByContract = new Map<Id, List<ContractPeriod__c>>();
for (ContractPeriod__c period : [
    SELECT Id, Contract__c, PeriodStartDate__c, PeriodEndDate__c
    FROM ContractPeriod__c
    WHERE Contract__c IN :contractIds
      AND PeriodStartDate__c <= :targetStart
      AND PeriodEndDate__c >= :targetEnd
]) {
    if (!augustPeriodsByContract.containsKey(period.Contract__c)) {
        augustPeriodsByContract.put(period.Contract__c, new List<ContractPeriod__c>());
    }
    augustPeriodsByContract.get(period.Contract__c).add(period);
}

List<Contract__c> eligibleContracts = new List<Contract__c>();
for (Contract__c contractRecord : contracts) {
    List<ContractLineItem__c> templates = templatesByContract.get(contractRecord.Id);
    if (templates == null || templates.isEmpty()) {
        continue;
    }
    Boolean complete = true;
    for (ContractLineItem__c template : templates) {
        if (template.ProductMaster__c == null || template.RevenueAmount__c == null) {
            complete = false;
            break;
        }
    }
    if (!complete) {
        continue;
    }
    List<ContractPeriod__c> periods = augustPeriodsByContract.get(contractRecord.Id);
    Integer periodCount = periods == null ? 0 : periods.size();
    if (periodCount > 1 || (contractRecord.ContractUpdate__c == '年' && periodCount != 1)) {
        continue;
    }
    eligibleContracts.add(contractRecord);
}

Integer plannedLineCount = 0;
Integer plannedPeriodCount = 0;
for (Contract__c contractRecord : eligibleContracts) {
    plannedLineCount += templatesByContract.get(contractRecord.Id).size();
    if (contractRecord.ContractUpdate__c == '月' && !augustPeriodsByContract.containsKey(contractRecord.Id)) {
        plannedPeriodCount++;
    }
}
System.assertEquals(38, eligibleContracts.size(), 'Preflight contract count changed');
System.assertEquals(43, plannedLineCount, 'Preflight line count changed');
System.assertEquals(35, plannedPeriodCount, 'Preflight period count changed');

List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
for (Contract__c contractRecord : eligibleContracts) {
    if (contractRecord.ContractUpdate__c == '月' && !augustPeriodsByContract.containsKey(contractRecord.Id)) {
        periodsToInsert.add(new ContractPeriod__c(
            Contract__c = contractRecord.Id,
            ContractUpdate__c = '月',
            IsInitialPeriod__c = false,
            PeriodStartDate__c = targetStart,
            PeriodEndDate__c = targetEnd
        ));
    }
}
insert periodsToInsert;
for (ContractPeriod__c period : periodsToInsert) {
    augustPeriodsByContract.put(period.Contract__c, new List<ContractPeriod__c>{ period });
}

List<ContractLineItem__c> linesToInsert = new List<ContractLineItem__c>();
for (Contract__c contractRecord : eligibleContracts) {
    ContractPeriod__c period = augustPeriodsByContract.get(contractRecord.Id)[0];
    String sourceName = String.isBlank(contractRecord.ContractName__c)
        ? contractRecord.Name
        : contractRecord.ContractName__c;
    for (ContractLineItem__c template : templatesByContract.get(contractRecord.Id)) {
        linesToInsert.add(new ContractLineItem__c(
            Name = (sourceName + '_' + targetYearMonth).left(80),
            Account__c = contractRecord.Account__c,
            ARR_Target__c = template.ARR_Target__c,
            ContractPeriod__c = period.Id,
            ContractYearMonth__c = targetYearMonth,
            InitialFee__c = false,
            MasterContract__c = contractRecord.Id,
            Month__c = targetYearMonth,
            MRR_Target__c = template.MRR_Target__c,
            PeopleNumber__c = template.PeopleNumber__c,
            PeriodStartDate__c = targetStart,
            PeriodEndDate__c = targetEnd,
            Plan__c = String.isBlank(template.Plan__c) ? contractRecord.Plan__c : template.Plan__c,
            ProductMaster__c = template.ProductMaster__c,
            QuotationLine__c = template.QuotationLine__c,
            RevenueAmount__c = template.RevenueAmount__c,
            Total__c = template.RevenueAmount__c
        ));
    }
}
insert linesToInsert;
System.debug(LoggingLevel.ERROR,
    'CONTRACTS=' + eligibleContracts.size() + ', PERIODS=' + periodsToInsert.size() +
    ', LINES=' + linesToInsert.size()
);
