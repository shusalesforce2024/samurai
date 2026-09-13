List<ContractLineItem__c> targets = [
    SELECT Id, RelatedInvoice__c
    FROM ContractLineItem__c
    WHERE Id IN (
        'a03RB00001VWEogYAH',
        'a03RB00001VWEohYAH',
        'a03RB00001WZCQ3YAP'
    )
];

for (ContractLineItem__c target : targets) {
    target.RelatedInvoice__c = null;
}

Database.SaveResult[] results = Database.update(targets, false);
Integer successCount = 0;
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
    } else {
        for (Database.Error error : results[i].getErrors()) {
            System.debug(LoggingLevel.ERROR,
                'FAILED id=' + targets[i].Id +
                ' status=' + error.getStatusCode() +
                ' message=' + error.getMessage());
        }
    }
}

System.debug('TARGETS=' + targets.size());
System.debug('UPDATED=' + successCount);
