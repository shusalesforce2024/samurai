String billedStatus = String.fromCharArray(new List<Integer>{35531, 27714, 28168});
List<ContractLineItem__c> rows = [
    SELECT Id, InvoiceStatus__c
    FROM ContractLineItem__c
    WHERE RelatedInvoice__c != null
    AND InvoiceStatus__c != :billedStatus
];
for (ContractLineItem__c row : rows) {
    row.InvoiceStatus__c = billedStatus;
}
update rows;
System.debug('updated=' + rows.size());
