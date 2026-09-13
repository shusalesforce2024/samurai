Id annualRenderyProductId = 'a0CRB0000CcXZ6Z2QW';

Map<Id, Id> existingInvoiceLineByWorkId = new Map<Id, Id>{
    'a0FRB00000WihDQ2AZ' => 'a01RB00001cODiVYAW',
    'a0FRB00000WihDV2AZ' => 'a01RB00001cODiWYAW'
};

List<Mig_FreeeInvoiceLineWork__c> lineUpdates =
    new List<Mig_FreeeInvoiceLineWork__c>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           InvoiceWork__c,
           ConfirmedProductMaster__c,
           CreatedInvoiceLine__c,
           ImportStatus__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c IN :existingInvoiceLineByWorkId.keySet()
]) {
    lineWork.ConfirmedProductMaster__c = annualRenderyProductId;
    lineWork.SuggestedProductMaster__c = annualRenderyProductId;
    lineWork.ProductResolveStatus__c =
        Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_CONFIRMED;
    lineWork.CreatedInvoiceLine__c =
        existingInvoiceLineByWorkId.get(lineWork.InvoiceWork__c);
    lineWork.ImportStatus__c =
        Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    lineWork.ResolveConfidence__c = 1;
    lineWork.ResolveMessage__c =
        '既存請求明細では年払い割引が主明細へ集約済みのため、'
        + '同じ既存請求明細へ紐づけました。';
    lineUpdates.add(lineWork);
}
update lineUpdates;

List<Mig_FreeeInvoiceWork__c> workUpdates =
    new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id,
           ImportStatus__c,
           ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :existingInvoiceLineByWorkId.keySet()
]) {
    workRecord.ImportStatus__c =
        Mig_FreeeInvoiceWorkService.STATUS_IMPORTED;
    workRecord.ValidationMessage__c =
        '既存Salesforce請求はfreeeの年払い本体・割引行を1明細へ'
        + '集約済みです。請求総額・税額・数量・商品を照合し、'
        + '既存請求明細へ紐づけました。';
    workUpdates.add(workRecord);
}
update workUpdates;

System.debug(
    LoggingLevel.ERROR,
    'RECONCILED_WORK_COUNT=' + workUpdates.size()
        + ', LINE_WORK_COUNT=' + lineUpdates.size()
);
