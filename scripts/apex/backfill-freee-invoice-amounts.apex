Integer invoiceUpdateCount = 0;
List<Invoice__c> invoiceUpdates = new List<Invoice__c>();

for (Invoice__c invoiceRecord : [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           PaidAmount__c,
           UnpaidAmount__c,
           PaymentStatus__c,
           Freee_Invoice_Id__c
    FROM Invoice__c
    WHERE Freee_Invoice_Id__c != null
      AND InvoiceAmount__c != null
      AND PaymentStatus__c IN ('決済待ち', '決済済み')
]) {
    Decimal paidAmount = invoiceRecord.PaymentStatus__c == '決済済み' ? invoiceRecord.InvoiceAmount__c : 0;
    Decimal unpaidAmount = invoiceRecord.PaymentStatus__c == '決済待ち' ? invoiceRecord.InvoiceAmount__c : 0;

    if (invoiceRecord.PaidAmount__c != paidAmount || invoiceRecord.UnpaidAmount__c != unpaidAmount) {
        invoiceUpdates.add(new Invoice__c(
            Id = invoiceRecord.Id,
            PaidAmount__c = paidAmount,
            UnpaidAmount__c = unpaidAmount
        ));
    }
}

if (!invoiceUpdates.isEmpty()) {
    update invoiceUpdates;
    invoiceUpdateCount = invoiceUpdates.size();
}

Integer workUpdateCount = 0;
List<Mig_FreeeInvoiceWork__c> workUpdates = new List<Mig_FreeeInvoiceWork__c>();

for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           PaidAmount__c,
           UnpaidAmount__c,
           PaymentStatus__c,
           FreeeInvoiceId__c
    FROM Mig_FreeeInvoiceWork__c
    WHERE FreeeInvoiceId__c != null
      AND InvoiceAmount__c != null
      AND PaymentStatus__c IN ('決済待ち', '決済済み')
]) {
    Decimal paidAmount = workRecord.PaymentStatus__c == '決済済み' ? workRecord.InvoiceAmount__c : 0;
    Decimal unpaidAmount = workRecord.PaymentStatus__c == '決済待ち' ? workRecord.InvoiceAmount__c : 0;

    if (workRecord.PaidAmount__c != paidAmount || workRecord.UnpaidAmount__c != unpaidAmount) {
        workUpdates.add(new Mig_FreeeInvoiceWork__c(
            Id = workRecord.Id,
            PaidAmount__c = paidAmount,
            UnpaidAmount__c = unpaidAmount
        ));
    }
}

if (!workUpdates.isEmpty()) {
    update workUpdates;
    workUpdateCount = workUpdates.size();
}

System.debug('BACKFILL_FREEE_INVOICE_AMOUNTS invoiceUpdates=' + invoiceUpdateCount + ', workUpdates=' + workUpdateCount);
