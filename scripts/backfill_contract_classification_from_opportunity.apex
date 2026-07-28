List<Contract__c> contractsToUpdate = new List<Contract__c>();

for (Contract__c contractRecord : [
    SELECT Id,
           Oppotunity__c,
           ProductCategory__c,
           PlanCategory__c,
           AccountCount__c,
           Oppotunity__r.ProductCategory__c,
           Oppotunity__r.PlanCategory__c,
           Oppotunity__r.AccountCount__c
    FROM Contract__c
    WHERE Oppotunity__c != null
    LIMIT 10000
]) {
    if (
        contractRecord.ProductCategory__c != contractRecord.Oppotunity__r.ProductCategory__c
        || contractRecord.PlanCategory__c != contractRecord.Oppotunity__r.PlanCategory__c
        || contractRecord.AccountCount__c != contractRecord.Oppotunity__r.AccountCount__c
    ) {
        contractsToUpdate.add(new Contract__c(
            Id = contractRecord.Id,
            ProductCategory__c = contractRecord.Oppotunity__r.ProductCategory__c,
            PlanCategory__c = contractRecord.Oppotunity__r.PlanCategory__c,
            AccountCount__c = contractRecord.Oppotunity__r.AccountCount__c
        ));
    }
}

update contractsToUpdate;
System.debug('updated=' + contractsToUpdate.size());
