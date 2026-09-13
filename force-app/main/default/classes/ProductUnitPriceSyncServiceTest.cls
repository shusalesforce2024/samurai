@isTest
private class ProductUnitPriceSyncServiceTest {
    @isTest
    static void preservesMigrationWorkUnitPriceOnInvoiceLineInsert() {
        ProductMaster__c productRecord = new ProductMaster__c(
            Name = 'Migration Price Product',
            UnitPrice__c = 2500
        );
        insert productRecord;

        Account accountRecord = new Account(Name = 'Migration Price Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.newInstance(2026, 7, 20),
            Freee_Account_Item_Picklist__c = 'Sales',
            Subject__c = 'Migration price invoice'
        );
        insert invoiceRecord;

        Mig_FreeeInvoiceWork__c workRecord = new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = 'freee_invoice:12345:price-preservation',
            FreeeInvoiceId__c = '990001',
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
        );
        insert workRecord;

        Mig_FreeeInvoiceLineWork__c lineWork =
            new Mig_FreeeInvoiceLineWork__c(
                InvoiceWork__c = workRecord.Id,
                ExternalKey__c = 'freee_invoice_line:12345:990001:1',
                FreeeLineId__c = '1',
                Description__c = 'Migration line',
                Quantity__c = 2,
                UnitPrice__c = 1200,
                LineAmount__c = 2400,
                ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_FETCHED
            );
        insert lineWork;

        InvoiceLine__c invoiceLine = new InvoiceLine__c(
            Invoice__c = invoiceRecord.Id,
            ProductMaster__c = productRecord.Id,
            Description__c = 'Migration line',
            Quantity__c = 2,
            Unit_Price__c = 1200,
            Tax_Rate__c = 10,
            MigrationSourceLineWork__c = lineWork.Id
        );
        insert invoiceLine;

        invoiceLine = [
            SELECT Unit_Price__c
            FROM InvoiceLine__c
            WHERE Id = :invoiceLine.Id
        ];
        System.assertEquals(
            1200,
            invoiceLine.Unit_Price__c,
            'Migration work unit price must not be overwritten by ProductMaster.'
        );
    }
}
