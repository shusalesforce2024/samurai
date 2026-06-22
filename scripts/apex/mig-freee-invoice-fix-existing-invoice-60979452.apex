Mig_FreeeInvoiceWork__c workRecord = [
    SELECT Id,
           ExternalKey__c,
           FreeeInvoiceId__c,
           FreeeInvoiceNumber__c,
           BillingDate__c,
           PaymentDate__c,
           Subject__c,
           InvoiceAmount__c,
           TaxAmount__c,
           PaidAmount__c,
           UnpaidAmount__c,
           SendStatus__c,
           PaymentStatus__c,
           ResolvedAccount__c,
           ResolvedContract__c,
           ResolvedContractPeriod__c,
           FreeePartnerId__c,
           TargetPeriodStartDate__c,
           TargetPeriodEndDate__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c = '60979452'
    LIMIT 1
];

Invoice__c invoiceRecord = [
    SELECT Id
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c = 60979452
    LIMIT 1
];

Mig_FreeeInvoiceLineWork__c lineWork = [
    SELECT Id,
           ConfirmedProductMaster__c,
           ExternalKey__c,
           FreeeLineId__c,
           Quantity__c,
           UnitPrice__c,
           LineAmount__c,
           TaxAmount__c
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c = :workRecord.Id
    LIMIT 1
];

// Temporarily unlock the existing freee-synced invoice for this migration correction only.
update new Invoice__c(
    Id = invoiceRecord.Id,
    Sent_To_Freee__c = false
);

Decimal amountWithTax = lineWork.LineAmount__c == null ? 0 : lineWork.LineAmount__c;
if (lineWork.TaxAmount__c != null) {
    amountWithTax += lineWork.TaxAmount__c;
}

update new Invoice__c(
    Id = invoiceRecord.Id,
    Account__c = workRecord.ResolvedAccount__c,
    ParentContract__c = workRecord.ResolvedContract__c,
    ContractPeriod__c = workRecord.ResolvedContractPeriod__c,
    Billing_Date__c = workRecord.BillingDate__c,
    Payment_Date__c = workRecord.PaymentDate__c,
    Subject__c = workRecord.Subject__c,
    InvoiceAmount__c = workRecord.InvoiceAmount__c,
    TaxAmount__c = workRecord.TaxAmount__c,
    AmountWithTax__c = workRecord.InvoiceAmount__c,
    PaidAmount__c = workRecord.PaidAmount__c,
    UnpaidAmount__c = workRecord.UnpaidAmount__c,
    Freee_Invoice_Number__c = workRecord.FreeeInvoiceNumber__c,
    Freee_Partner_Id__c = Mig_FreeeInvoiceWorkService.toDecimal(workRecord.FreeePartnerId__c),
    Freee_Invoice_Status__c = workRecord.SendStatus__c,
    PaymentStatus__c = workRecord.PaymentStatus__c,
    Freee_Sync_Status__c = 'Success',
    Sent_To_Freee__c = false,
    Freee_Account_Item_Picklist__c = 'Sales',
    Freee_External_Key__c = workRecord.ExternalKey__c,
    TargetPeriodStartDate__c = workRecord.TargetPeriodStartDate__c,
    TargetPeriodEndDate__c = workRecord.TargetPeriodEndDate__c
);

List<InvoiceLine__c> existingLines = [
    SELECT Id
    FROM InvoiceLine__c
    WHERE Invoice__c = :invoiceRecord.Id
    LIMIT 1
];
if (existingLines.isEmpty()) {
    throw new AuraHandledException('Existing InvoiceLine__c not found for Freee_Invoice_Id__c=60979452');
}

update new InvoiceLine__c(
    Id = existingLines[0].Id,
    ProductMaster__c = lineWork.ConfirmedProductMaster__c,
    Quantity__c = lineWork.Quantity__c,
    Unit_Price__c = lineWork.UnitPrice__c,
    AmountWithTax__c = amountWithTax,
    TaxAmount__c = lineWork.TaxAmount__c,
    Freee_Line_Id__c = lineWork.FreeeLineId__c
);

Mig_FreeeInvoiceValidator.validateAll();
Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(new List<Id>{workRecord.Id});

update new Invoice__c(
    Id = invoiceRecord.Id,
    Sent_To_Freee__c = true,
    Freee_Sync_Status__c = 'Success'
);
System.debug('MIG_FREEE_FIXED_EXISTING_INVOICE_60979452=' + workRecord.Id);
