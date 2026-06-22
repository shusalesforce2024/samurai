Integer invoiceUpdateCount = 0;
List<Invoice__c> invoiceUpdates = new List<Invoice__c>();
Map<Id, Decimal> invoiceLineTaxByInvoiceId = new Map<Id, Decimal>();

for (AggregateResult result : [
    SELECT Invoice__c invoiceId,
           SUM(TaxAmount__c) taxTotal
    FROM InvoiceLine__c
    WHERE Invoice__c != null
      AND TaxAmount__c != null
    GROUP BY Invoice__c
]) {
    invoiceLineTaxByInvoiceId.put((Id) result.get('invoiceId'), (Decimal) result.get('taxTotal'));
}

for (Invoice__c invoiceRecord : [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           TaxAmount__c,
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
    Decimal taxAmount = invoiceRecord.TaxAmount__c == null
        ? invoiceLineTaxByInvoiceId.get(invoiceRecord.Id)
        : invoiceRecord.TaxAmount__c;

    if (invoiceRecord.PaidAmount__c != paidAmount
        || invoiceRecord.UnpaidAmount__c != unpaidAmount
        || invoiceRecord.TaxAmount__c != taxAmount
    ) {
        invoiceUpdates.add(new Invoice__c(
            Id = invoiceRecord.Id,
            TaxAmount__c = taxAmount,
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
Map<Id, Decimal> lineWorkTaxByWorkId = new Map<Id, Decimal>();

for (AggregateResult result : [
    SELECT InvoiceWork__c workId,
           SUM(TaxAmount__c) taxTotal
    FROM Mig_FreeeInvoiceLineWork__c
    WHERE InvoiceWork__c != null
      AND TaxAmount__c != null
    GROUP BY InvoiceWork__c
]) {
    lineWorkTaxByWorkId.put((Id) result.get('workId'), (Decimal) result.get('taxTotal'));
}

for (Mig_FreeeInvoiceWork__c workRecord : [
    SELECT Id,
           Name,
           InvoiceAmount__c,
           TaxAmount__c,
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
    Decimal taxAmount = workRecord.TaxAmount__c == null
        ? lineWorkTaxByWorkId.get(workRecord.Id)
        : workRecord.TaxAmount__c;

    if (workRecord.PaidAmount__c != paidAmount
        || workRecord.UnpaidAmount__c != unpaidAmount
        || workRecord.TaxAmount__c != taxAmount
    ) {
        workUpdates.add(new Mig_FreeeInvoiceWork__c(
            Id = workRecord.Id,
            TaxAmount__c = taxAmount,
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
