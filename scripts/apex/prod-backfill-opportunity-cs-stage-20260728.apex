List<Opportunity__c> targets = [
    SELECT Id, CsStage__c
    FROM Opportunity__c
    WHERE ProductCategory__c = 'Rendery'
      AND PlanCategory__c = 'Enterprise'
      AND StageName__c = 'Closed Won'
      AND CsStage__c = null
];

for (Opportunity__c target : targets) {
    target.CsStage__c = 'S1';
}

Database.SaveResult[] results = Database.update(targets, false);
Integer successCount = 0;
List<String> errors = new List<String>();
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
        continue;
    }
    for (Database.Error error : results[i].getErrors()) {
        errors.add(targets[i].Id + ': ' + error.getMessage());
    }
}

System.debug(LoggingLevel.ERROR, 'CS_STAGE_TARGET_COUNT=' + targets.size());
System.debug(LoggingLevel.ERROR, 'CS_STAGE_SUCCESS_COUNT=' + successCount);
System.debug(LoggingLevel.ERROR, 'CS_STAGE_ERRORS=' + errors);

if (!errors.isEmpty()) {
    throw new AuraHandledException(String.join(errors, ' / '));
}
