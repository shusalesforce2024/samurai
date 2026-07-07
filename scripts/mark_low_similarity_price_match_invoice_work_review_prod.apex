Set<Id> lineWorkIds = new Set<Id>{
    'a0ERB00000NrwqD2AR',
    'a0ERB00000Nrx9q2AB',
    'a0ERB00000Nrx9r2AB',
    'a0ERB00000Nrx9s2AB',
    'a0ERB00000Nrx9t2AB',
    'a0ERB00000NrxJH2AZ',
    'a0ERB00000NrxJJ2AZ',
    'a0ERB00000NrxMU2AZ',
    'a0ERB00000NrxMY2AZ',
    'a0ERB00000NrxMc2AJ',
    'a0ERB00000NryiL2AR',
    'a0ERB00000Nryjy2AB',
    'a0ERB00000Nryjz2AB',
    'a0ERB00000Nryk02AB',
    'a0ERB00000Nryk12AB',
    'a0ERB00000Nryk22AB',
    'a0ERB00000Nryk32AB',
    'a0ERB00000Nryk42AB',
    'a0ERB00000NrzPt2AJ',
    'a0ERB00000Ojmil2AB'
};

List<Mig_FreeeInvoiceLineWork__c> lineUpdates = new List<Mig_FreeeInvoiceLineWork__c>();
Set<Id> workIds = new Set<Id>();
for (Mig_FreeeInvoiceLineWork__c lineWork : [
    SELECT Id,
           InvoiceWork__c,
           Description__c,
           ResolveMessage__c,
           CreatedInvoiceLine__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE Id IN :lineWorkIds
]) {
    workIds.add(lineWork.InvoiceWork__c);
    String message = '要確認: 請求明細の件名と商品マスタ名が類似していません。金額一致だけで商品が選ばれている可能性があります。商品マスタを確認してください。';
    String currentMessage = String.isBlank(lineWork.ResolveMessage__c) ? '' : lineWork.ResolveMessage__c;
    lineUpdates.add(new Mig_FreeeInvoiceLineWork__c(
        Id = lineWork.Id,
        ProductResolveStatus__c = Mig_FreeeInvoiceWorkService.PRODUCT_STATUS_NEEDS_REVIEW,
        ResolveMessage__c = currentMessage.contains(message) ? currentMessage : currentMessage + '\n' + message
    ));
}

List<Mig_FreeeInvoiceWork__c> workUpdates = new List<Mig_FreeeInvoiceWork__c>();
for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id,
           ValidationMessage__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE Id IN :workIds
]) {
    String message = '要確認: 請求明細の件名と商品マスタ名が類似していない明細があります。関連リストのFreee請求明細移行Workで商品マスタを確認してください。';
    String currentMessage = String.isBlank(workRecord.ValidationMessage__c) ? '' : workRecord.ValidationMessage__c;
    workUpdates.add(new Mig_FreeeInvoiceWork__c(
        Id = workRecord.Id,
        ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
        ValidationMessage__c = currentMessage.contains(message) ? currentMessage : currentMessage + '\n' + message
    ));
}

update lineUpdates;
update workUpdates;

System.debug('markedLineWorks=' + lineUpdates.size());
System.debug('markedWorks=' + workUpdates.size());
