String monthlyUpdateValue = '月';
String migrationPrefix = 'Mig_freee請求移行_';

List<Mig_FreeeInvoiceWork__c> works = [
    SELECT Id,
           Name,
           BillingDate__c,
           TargetPeriodStartDate__c,
           TargetPeriodEndDate__c,
           ResolvedAccount__c,
           ResolvedAccount__r.Name,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           ImportStatus__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE ImportStatus__c = '要確認'
      AND ResolvedAccount__c != null
      AND (ResolvedContract__c = null OR ResolvedContractPeriod__c = null)
    ORDER BY ResolvedAccount__r.Name, BillingDate__c
];

System.debug('target works=' + works.size());
if (works.isEmpty()) {
    return;
}

Set<Id> accountIds = new Set<Id>();
Map<Id, Date> minStartByAccount = new Map<Id, Date>();
Map<Id, Date> maxEndByAccount = new Map<Id, Date>();
Map<Id, String> accountNameById = new Map<Id, String>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    accountIds.add(workRecord.ResolvedAccount__c);
    accountNameById.put(workRecord.ResolvedAccount__c, workRecord.ResolvedAccount__r.Name);
    Date targetDate = workRecord.TargetPeriodStartDate__c == null ? workRecord.BillingDate__c : workRecord.TargetPeriodStartDate__c;
    if (targetDate == null) {
        continue;
    }
    Date monthStart = Date.newInstance(targetDate.year(), targetDate.month(), 1);
    Date monthEnd = Date.newInstance(targetDate.year(), targetDate.month(), Date.daysInMonth(targetDate.year(), targetDate.month()));
    if (!minStartByAccount.containsKey(workRecord.ResolvedAccount__c) || minStartByAccount.get(workRecord.ResolvedAccount__c) > monthStart) {
        minStartByAccount.put(workRecord.ResolvedAccount__c, monthStart);
    }
    if (!maxEndByAccount.containsKey(workRecord.ResolvedAccount__c) || maxEndByAccount.get(workRecord.ResolvedAccount__c) < monthEnd) {
        maxEndByAccount.put(workRecord.ResolvedAccount__c, monthEnd);
    }
}

Map<Id, Contract__c> contractByAccount = new Map<Id, Contract__c>();
for (Contract__c contractRecord : [
    SELECT Id, Account__c, ContractName__c, StartDate__c, EndDate__c
    FROM Contract__c
    WHERE Account__c IN :accountIds
      AND ContractName__c LIKE 'Mig_freee請求移行_%'
]) {
    if (!contractByAccount.containsKey(contractRecord.Account__c)) {
        contractByAccount.put(contractRecord.Account__c, contractRecord);
    }
}

List<Contract__c> contractsToInsert = new List<Contract__c>();
for (Id accountId : accountIds) {
    if (contractByAccount.containsKey(accountId)) {
        continue;
    }
    String accountName = accountNameById.get(accountId);
    String contractName = migrationPrefix + (String.isBlank(accountName) ? String.valueOf(accountId) : accountName);
    if (contractName.length() > 80) {
        contractName = contractName.substring(0, 80);
    }
    contractsToInsert.add(new Contract__c(
        Account__c = accountId,
        ContractName__c = contractName,
        ContractUpdate__c = monthlyUpdateValue,
        StartDate__c = minStartByAccount.get(accountId),
        EndDate__c = maxEndByAccount.get(accountId),
        Status__c = 'Draft',
        Description__c = 'freee請求移行用に作成した契約管理。既存請求の移行紐づけ専用。'
    ));
}

if (!contractsToInsert.isEmpty()) {
    insert contractsToInsert;
    for (Contract__c contractRecord : contractsToInsert) {
        contractByAccount.put(contractRecord.Account__c, contractRecord);
    }
}
System.debug('inserted contracts=' + contractsToInsert.size());

Set<Id> migrationContractIds = new Set<Id>();
for (Contract__c contractRecord : contractByAccount.values()) {
    migrationContractIds.add(contractRecord.Id);
}

Map<String, ContractPeriod__c> periodByKey = new Map<String, ContractPeriod__c>();
if (!migrationContractIds.isEmpty()) {
    for (ContractPeriod__c periodRecord : [
        SELECT Id, Contract__c, PeriodStartDate__c, PeriodEndDate__c
        FROM ContractPeriod__c
        WHERE Contract__c IN :migrationContractIds
    ]) {
        periodByKey.put(String.valueOf(periodRecord.Contract__c) + ':' + String.valueOf(periodRecord.PeriodStartDate__c), periodRecord);
    }
}

List<ContractPeriod__c> periodsToInsert = new List<ContractPeriod__c>();
Map<String, ContractPeriod__c> pendingPeriodByKey = new Map<String, ContractPeriod__c>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    Contract__c contractRecord = contractByAccount.get(workRecord.ResolvedAccount__c);
    if (contractRecord == null) {
        continue;
    }
    Date targetDate = workRecord.TargetPeriodStartDate__c == null ? workRecord.BillingDate__c : workRecord.TargetPeriodStartDate__c;
    if (targetDate == null) {
        continue;
    }
    Date monthStart = Date.newInstance(targetDate.year(), targetDate.month(), 1);
    Date monthEnd = Date.newInstance(targetDate.year(), targetDate.month(), Date.daysInMonth(targetDate.year(), targetDate.month()));
    String key = String.valueOf(contractRecord.Id) + ':' + String.valueOf(monthStart);
    if (periodByKey.containsKey(key) || pendingPeriodByKey.containsKey(key)) {
        continue;
    }
    ContractPeriod__c newPeriod = new ContractPeriod__c(
        Contract__c = contractRecord.Id,
        ContractUpdate__c = monthlyUpdateValue,
        PeriodStartDate__c = monthStart,
        PeriodEndDate__c = monthEnd,
        IsInitialPeriod__c = false
    );
    periodsToInsert.add(newPeriod);
    pendingPeriodByKey.put(key, newPeriod);
}

if (!periodsToInsert.isEmpty()) {
    insert periodsToInsert;
    for (ContractPeriod__c periodRecord : periodsToInsert) {
        periodByKey.put(String.valueOf(periodRecord.Contract__c) + ':' + String.valueOf(periodRecord.PeriodStartDate__c), periodRecord);
    }
}
System.debug('inserted periods=' + periodsToInsert.size());

List<Mig_FreeeInvoiceWork__c> worksToUpdate = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : works) {
    Contract__c contractRecord = contractByAccount.get(workRecord.ResolvedAccount__c);
    if (contractRecord == null) {
        continue;
    }
    Date targetDate = workRecord.TargetPeriodStartDate__c == null ? workRecord.BillingDate__c : workRecord.TargetPeriodStartDate__c;
    if (targetDate == null) {
        continue;
    }
    Date monthStart = Date.newInstance(targetDate.year(), targetDate.month(), 1);
    ContractPeriod__c periodRecord = periodByKey.get(String.valueOf(contractRecord.Id) + ':' + String.valueOf(monthStart));
    if (periodRecord == null) {
        continue;
    }
    worksToUpdate.add(new Mig_FreeeInvoiceWork__c(
        Id = workRecord.Id,
        ResolvedContract__c = contractRecord.Id,
        ResolvedContractPeriod__c = periodRecord.Id
    ));
}

if (!worksToUpdate.isEmpty()) {
    update worksToUpdate;
}
System.debug('updated works=' + worksToUpdate.size());

Mig_FreeeInvoiceMigrationController.validateAll();
System.debug('validation completed');
