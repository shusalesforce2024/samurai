Set<Id> targetIds = new Set<Id>{
    'a03RB00001NswhHYAR','a03RB00001NswhzYAB','a03RB00001Nswi0YAB','a03RB00001NswiOYAR',
    'a03RB00001NswieYAB','a03RB00001NswifYAB','a03RB00001NswirYAB','a03RB00001NswisYAB',
    'a03RB00001NswitYAB','a03RB00001NswiuYAB','a03RB00001NswivYAB','a03RB00001NswiwYAB',
    'a03RB00001NswixYAB','a03RB00001NswiyYAB','a03RB00001NswizYAB','a03RB00001Nswj0YAB',
    'a03RB00001Nswj1YAB','a03RB00001Nswj2YAB','a03RB00001NswjCYAR','a03RB00001NswjDYAR',
    'a03RB00001NswjEYAR','a03RB00001NswjFYAR','a03RB00001NswjGYAR','a03RB00001NswjHYAR',
    'a03RB00001NswjIYAR','a03RB00001NswjJYAR','a03RB00001NswjKYAR','a03RB00001NswjLYAR',
    'a03RB00001NswjMYAR','a03RB00001NswjNYAR','a03RB00001UyZX6YAN'
};

List<ContractLineItem__c> records = [
    SELECT Id, MasterContract__c, Account__c, RelatedInvoice__c,
           RelatedInvoice__r.ParentContract__c, RelatedInvoice__r.Account__c
    FROM ContractLineItem__c
    WHERE Id IN :targetIds
];

List<ContractLineItem__c> updates = new List<ContractLineItem__c>();
for (ContractLineItem__c record : records) {
    Boolean isStillWrong = record.RelatedInvoice__c != null &&
        (record.RelatedInvoice__r.ParentContract__c != record.MasterContract__c ||
         record.RelatedInvoice__r.Account__c != record.Account__c);
    if (isStillWrong) {
        updates.add(new ContractLineItem__c(Id = record.Id, RelatedInvoice__c = null));
    }
}

Database.SaveResult[] results = Database.update(updates, false);
Integer successCount = 0;
List<String> errors = new List<String>();
for (Integer index = 0; index < results.size(); index++) {
    if (results[index].isSuccess()) {
        successCount++;
    } else {
        for (Database.Error error : results[index].getErrors()) {
            errors.add(String.valueOf(updates[index].Id) + ': ' + error.getMessage());
        }
    }
}
System.debug(LoggingLevel.ERROR, 'TARGET=' + targetIds.size() + ', RECHECKED=' + updates.size() + ', SUCCESS=' + successCount + ', ERRORS=' + errors);
