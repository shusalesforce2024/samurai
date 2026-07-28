@IsTest
private class Mig_FreeeInvoiceWorkRetentionBatchTest {
    @IsTest
    static void deletesOnlyImportedWorkOlderThanTwoMonths() {
        Account accountRecord = new Account(Name = 'Work Retention Test Account');
        insert accountRecord;

        Invoice__c invoiceRecord = new Invoice__c(
            Account__c = accountRecord.Id,
            Billing_Date__c = Date.today(),
            Freee_Account_Item_Picklist__c = 'Sales',
            PaymentStatus__c = '決済待ち',
            Subject__c = 'Work Retention Test Invoice'
        );
        insert invoiceRecord;

        Mig_FreeeInvoiceWork__c expiredImportedWork = createWork(
            '100001',
            Mig_FreeeInvoiceWorkService.STATUS_IMPORTED,
            invoiceRecord.Id
        );
        Mig_FreeeInvoiceWork__c recentImportedWork = createWork(
            '100002',
            Mig_FreeeInvoiceWorkService.STATUS_IMPORTED,
            invoiceRecord.Id
        );
        Mig_FreeeInvoiceWork__c oldNeedsReviewWork = createWork(
            '100003',
            Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW,
            invoiceRecord.Id
        );
        Mig_FreeeInvoiceWork__c oldImportedWithoutInvoiceWork = createWork(
            '100004',
            Mig_FreeeInvoiceWorkService.STATUS_IMPORTED,
            null
        );
        insert new Mig_FreeeInvoiceLineWork__c(
            ExternalKey__c = 'freee_invoice_line:1:100001:1',
            FreeeLineId__c = '1',
            InvoiceWork__c = expiredImportedWork.Id,
            ImportStatus__c = Mig_FreeeInvoiceWorkService.STATUS_IMPORTED
        );

        Test.setCreatedDate(
            expiredImportedWork.Id,
            System.now().addMonths(-2).addDays(-1)
        );
        Test.setCreatedDate(
            oldNeedsReviewWork.Id,
            System.now().addMonths(-2).addDays(-1)
        );
        Test.setCreatedDate(
            oldImportedWithoutInvoiceWork.Id,
            System.now().addMonths(-2).addDays(-1)
        );

        Test.startTest();
        Database.executeBatch(new Mig_FreeeInvoiceWorkRetentionBatch(), 1);
        Test.stopTest();

        System.assertEquals(0, [
            SELECT COUNT()
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :expiredImportedWork.Id
        ]);
        System.assertEquals(0, [
            SELECT COUNT()
            FROM Mig_FreeeInvoiceLineWork__c
            WHERE InvoiceWork__c = :expiredImportedWork.Id
        ]);
        System.assertEquals(3, [
            SELECT COUNT()
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id IN :new Set<Id>{
                recentImportedWork.Id,
                oldNeedsReviewWork.Id,
                oldImportedWithoutInvoiceWork.Id
            }
        ]);
    }

    @IsTest
    static void schedulesMonthlyRetentionJob() {
        Test.startTest();
        Id jobId = Mig_FreeeInvoiceWorkRetentionBatch.scheduleMonthly();
        Test.stopTest();

        CronTrigger triggerRecord = [
            SELECT CronExpression,
                   CronJobDetail.Name
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        System.assertEquals(Mig_FreeeInvoiceWorkRetentionBatch.SCHEDULE_NAME, triggerRecord.CronJobDetail.Name);
        System.assertEquals(Mig_FreeeInvoiceWorkRetentionBatch.MONTHLY_CRON, triggerRecord.CronExpression);
    }

    private static Mig_FreeeInvoiceWork__c createWork(
        String freeeInvoiceId,
        String statusValue,
        Id invoiceId
    ) {
        Mig_FreeeInvoiceWork__c workRecord = new Mig_FreeeInvoiceWork__c(
            CreatedInvoice__c = invoiceId,
            ExternalKey__c = Mig_FreeeInvoiceWorkService.buildInvoiceExternalKey(1, freeeInvoiceId),
            FreeeInvoiceId__c = freeeInvoiceId,
            FreeeInvoiceNumber__c = 'INV-' + freeeInvoiceId,
            ImportStatus__c = statusValue,
            InvoiceAmount__c = 1100,
            PartnerName__c = 'Retention Test Partner'
        );
        insert workRecord;
        return workRecord;
    }
}
