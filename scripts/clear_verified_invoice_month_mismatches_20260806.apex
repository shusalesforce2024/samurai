Set<Id> invoiceIds = new Set<Id>{
    'a00RB00002B5oL9YAJ',
    'a00RB00002Am2BgYAJ',
    'a00RB00002B5oLFYAZ',
    'a00RB00002B5oL3YAJ'
};

List<ContractLineItem__c> allLinked = [
    SELECT Id, RelatedInvoice__c, Month__c, Total__c, ProductMaster__c, CreatedDate
    FROM ContractLineItem__c
    WHERE RelatedInvoice__c IN :invoiceIds
    FOR UPDATE
];

List<ContractLineItem__c> targets = new List<ContractLineItem__c>();
for (ContractLineItem__c line : allLinked) {
    if (line.RelatedInvoice__c == 'a00RB00002B5oL9YAJ') {
        if (!(line.Month__c == '2026/04' && line.Total__c == 8000)) {
            targets.add(line);
        }
    } else if (line.RelatedInvoice__c == 'a00RB00002Am2BgYAJ') {
        targets.add(line);
    } else if (line.RelatedInvoice__c == 'a00RB00002B5oLFYAZ') {
        if (line.Month__c == '2026/02' || line.Month__c == '2026/03') {
            targets.add(line);
        }
    } else if (line.RelatedInvoice__c == 'a00RB00002B5oL3YAJ') {
        if (line.Id == 'a03RB00001VUaoVYAT' || line.Id == 'a03RB00001VUaoWYAT') {
            targets.add(line);
        }
    }
}

if (targets.size() != 44) {
    throw new IllegalArgumentException('解除対象件数が想定44件と異なります: ' + targets.size());
}

for (ContractLineItem__c line : targets) {
    line.RelatedInvoice__c = null;
}
update targets;

System.debug('CLEARED=' + targets.size());
