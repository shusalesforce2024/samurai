@IsTest
private class InvoiceActionControllerTest {
    @IsTest
    static void cancelAndRecreateFromController() {
        Account accountRecord = new Account(Name = '請求アクションテスト取引先');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.today(),
            Freee_Invoice_Status__c = '送付待ち',
            Freee_Sync_Status__c = 'Processing',
            PaymentStatus__c = '決済待ち',
            Sent_To_Freee__c = false,
            Subject__c = '請求アクションテスト',
            TargetPeriodStartDate__c = Date.today().toStartOfMonth(),
            TargetPeriodEndDate__c = Date.today().toStartOfMonth().addMonths(1).addDays(-1)
        );
        insert invoiceRecord;

        insert new InvoiceLine__c(
            Invoice__c = invoiceRecord.Id,
            Description__c = '月額利用料',
            Quantity__c = 1,
            Tax_Rate__c = 10,
            Unit_Price__c = 10000
        );

        Test.startTest();
        String cancelMessage = InvoiceActionController.cancelInvoice(invoiceRecord.Id);
        Id recreatedId = InvoiceActionController.recreateInvoice(invoiceRecord.Id);
        Test.stopTest();

        System.assertEquals('請求を取消しました。', cancelMessage);

        Invoice__c cancelled = [
            SELECT CancelStatus__c
            FROM Invoice__c
            WHERE Id = :invoiceRecord.Id
        ];
        System.assertEquals('取消済', cancelled.CancelStatus__c);

        Invoice__c recreated = [
            SELECT OriginalInvoice__c, Sent_To_Freee__c, PaymentStatus__c
            FROM Invoice__c
            WHERE Id = :recreatedId
        ];
        System.assertEquals(invoiceRecord.Id, recreated.OriginalInvoice__c);
        System.assertEquals(false, recreated.Sent_To_Freee__c);
        System.assertEquals('決済待ち', recreated.PaymentStatus__c);
    }
}