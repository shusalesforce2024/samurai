List<Invoice__c> invoiceHeaders = new List<Invoice__c>{
    new Invoice__c(Id = 'a00RB00002BbzTPYAZ', Sent_To_Freee__c = false),
    new Invoice__c(Id = 'a00RB00002BbzTQYAZ', Sent_To_Freee__c = false)
};
update invoiceHeaders;

List<InvoiceLine__c> corrections = new List<InvoiceLine__c>{
    new InvoiceLine__c(
        Id = 'a01RB00001cr7wEYAQ',
        Unit_Price__c = 24000
    ),
    new InvoiceLine__c(
        Id = 'a01RB00001cr7wFYAQ',
        Unit_Price__c = 30000
    )
};

Database.SaveResult[] results = Database.update(corrections, false);
Integer successCount = 0;
List<String> errors = new List<String>();
for (Integer index = 0; index < results.size(); index++) {
    if (results[index].isSuccess()) {
        successCount++;
        continue;
    }
    for (Database.Error error : results[index].getErrors()) {
        errors.add(String.valueOf(corrections[index].Id) + ': ' + error.getMessage());
    }
}
System.debug(LoggingLevel.ERROR,
    'SUMMARY requested=' + corrections.size() +
    ', updated=' + successCount +
    ', errors=' + errors.size()
);
System.debug(LoggingLevel.ERROR, 'ERRORS=' + JSON.serialize(errors));

for (Invoice__c invoiceRecord : invoiceHeaders) {
    invoiceRecord.Sent_To_Freee__c = true;
}
update invoiceHeaders;
