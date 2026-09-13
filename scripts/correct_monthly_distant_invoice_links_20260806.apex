List<Invoice__c> invoices = [
    SELECT Id, ParentContract__c, Account__c, Billing_Date__c
    FROM Invoice__c
    WHERE CancelStatus__c = '通常'
      AND ParentContract__c != null
      AND Account__c != null
      AND Billing_Date__c != null
];

Map<String, List<Id>> invoiceIdsByKey = new Map<String, List<Id>>();
for (Invoice__c invoiceRecord : invoices) {
    String yearMonth = String.valueOf(invoiceRecord.Billing_Date__c.year()) + '/' +
        String.valueOf(invoiceRecord.Billing_Date__c.month()).leftPad(2, '0');
    String key = String.valueOf(invoiceRecord.ParentContract__c) + '|' +
        String.valueOf(invoiceRecord.Account__c) + '|' + yearMonth;
    if (!invoiceIdsByKey.containsKey(key)) {
        invoiceIdsByKey.put(key, new List<Id>());
    }
    invoiceIdsByKey.get(key).add(invoiceRecord.Id);
}

List<ContractLineItem__c> monthlyLines = [
    SELECT Id, MasterContract__c, MasterContract__r.ContractUpdate__c,
           Account__c, Month__c, PeriodStartDate__c, RelatedInvoice__c,
           RelatedInvoice__r.Billing_Date__c
    FROM ContractLineItem__c
    WHERE MasterContract__r.ContractUpdate__c = '月'
      AND RelatedInvoice__c != null
      AND PeriodStartDate__c != null
      AND RelatedInvoice__r.Billing_Date__c != null
];

List<ContractLineItem__c> updates = new List<ContractLineItem__c>();
Integer replaceCount = 0;
Integer clearCount = 0;
for (ContractLineItem__c line : monthlyLines) {
    Date monthlyDate = line.PeriodStartDate__c;
    Date billingDate = line.RelatedInvoice__r.Billing_Date__c;
    Integer monthDifference = Math.abs(
        (billingDate.year() - monthlyDate.year()) * 12 + billingDate.month() - monthlyDate.month()
    );
    if (monthDifference <= 1) {
        continue;
    }

    String key = String.valueOf(line.MasterContract__c) + '|' +
        String.valueOf(line.Account__c) + '|' + line.Month__c;
    List<Id> candidates = invoiceIdsByKey.get(key);
    Id correctedInvoiceId = candidates != null && candidates.size() == 1 ? candidates[0] : null;
    updates.add(new ContractLineItem__c(Id = line.Id, RelatedInvoice__c = correctedInvoiceId));
    if (correctedInvoiceId == null) {
        clearCount++;
    } else {
        replaceCount++;
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
System.debug(LoggingLevel.ERROR,
    'TARGET=' + updates.size() + ', REPLACE=' + replaceCount + ', CLEAR=' + clearCount +
    ', SUCCESS=' + successCount + ', ERRORS=' + errors
);
