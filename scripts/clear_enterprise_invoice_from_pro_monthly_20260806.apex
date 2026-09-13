Id invoiceId = 'a00RB00002B5oLLYAZ';
Id enterpriseProductId = 'a0CRB0000CcXZ6W2QW';

List<ContractLineItem__c> targets = [
    SELECT Id, RelatedInvoice__c, ProductMaster__c, Month__c, Total__c
    FROM ContractLineItem__c
    WHERE RelatedInvoice__c = :invoiceId
      AND ProductMaster__c != :enterpriseProductId
    FOR UPDATE
];

if (targets.size() != 12) {
    throw new IllegalArgumentException('Proプラン側の解除対象が想定12件と異なります: ' + targets.size());
}
for (ContractLineItem__c line : targets) {
    line.RelatedInvoice__c = null;
}
update targets;

System.debug('CLEARED_PRO_LINKS=' + targets.size());
