List<Contract__c> updates = new List<Contract__c>{
    new Contract__c(
        Id = 'a04RB00000kUAOkYAO',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 10
    ),
    new Contract__c(
        Id = 'a04RB00000kUAOoYAO',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 10
    ),
    new Contract__c(
        Id = 'a04RB00000kUAOrYAO',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 10
    ),
    new Contract__c(
        Id = 'a04RB00000kUAOsYAO',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 10
    ),
    new Contract__c(
        Id = 'a04RB00000kUAP2YAO',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 5
    ),
    new Contract__c(
        Id = 'a04RB00000n5JdhYAE',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Pro',
        AccountCount__c = 3
    ),
    new Contract__c(
        Id = 'a04RB00000n5JeAYAU',
        ProductCategory__c = 'Rendery',
        PlanCategory__c = 'Enterprise',
        AccountCount__c = 5
    )
};

Database.SaveResult[] results = Database.update(updates, false);
Integer successCount = 0;
List<String> errors = new List<String>();
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
        continue;
    }
    for (Database.Error error : results[i].getErrors()) {
        errors.add(String.valueOf(updates[i].Id) + ': ' + error.getMessage());
    }
}

System.debug(LoggingLevel.ERROR, 'updated=' + successCount + ', failed=' + errors.size());
System.debug(LoggingLevel.ERROR, 'errors=' + JSON.serialize(errors));
