@IsTest
private class FreeeInvoiceWorkBulkActionControllerTest {
    @IsTest
    static void finalizeSelectedRequiresSelectedWork() {
        Test.setCurrentPage(Page.FreeeInvoiceWorkBulkFinalize);

        FreeeInvoiceWorkBulkActionController controller = new FreeeInvoiceWorkBulkActionController();
        controller.finalizeSelected();

        System.assertEquals(true, controller.getHasError());
        System.assert(controller.errorMessage.contains('選択'));
    }

    @IsTest
    static void finalizeSelectedSkipsNonReadyWork() {
        Mig_FreeeInvoiceWork__c workRecord = createWork(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW, '901001');
        Test.setCurrentPage(Page.FreeeInvoiceWorkBulkFinalize);
        ApexPages.currentPage().getParameters().put('selected', String.valueOf(workRecord.Id));

        FreeeInvoiceWorkBulkActionController controller = new FreeeInvoiceWorkBulkActionController();
        controller.finalizeSelected();

        System.assertEquals(true, controller.getHasError());
        System.assertEquals(1, controller.summary.selectedCount);
        System.assertEquals(0, controller.summary.readyCount);
        System.assertEquals(1, controller.summary.skippedCount);
    }

    @IsTest
    static void finalizeSelectedProcessesReadyWorkAndLeavesReviewWhenInvalid() {
        Mig_FreeeInvoiceWork__c workRecord = createWork(Mig_FreeeInvoiceWorkService.STATUS_READY, '901002');
        Test.setCurrentPage(Page.FreeeInvoiceWorkBulkFinalize);
        ApexPages.currentPage().getParameters().put('selected', '[' + String.valueOf(workRecord.Id) + ']');

        FreeeInvoiceWorkBulkActionController controller = new FreeeInvoiceWorkBulkActionController();
        controller.finalizeSelected();

        System.assertEquals(false, controller.getHasError(), controller.errorMessage == null ? '' : controller.errorMessage);
        System.assertEquals(1, controller.summary.selectedCount);
        System.assertEquals(1, controller.summary.readyCount);
        System.assertEquals(1, controller.summary.needsReviewCount);

        Mig_FreeeInvoiceWork__c updatedWork = [
            SELECT ImportStatus__c, ValidationMessage__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE Id = :workRecord.Id
        ];
        System.assertEquals(Mig_FreeeInvoiceWorkService.STATUS_NEEDS_REVIEW, updatedWork.ImportStatus__c);
        System.assertNotEquals(null, updatedWork.ValidationMessage__c);
    }

    @IsTest
    static void validateSelectedRunsValidatorForSelectedWork() {
        Mig_FreeeInvoiceWork__c workRecord = createWork(Mig_FreeeInvoiceWorkService.STATUS_FETCHED, '901003');
        Test.setCurrentPage(Page.FreeeInvoiceWorkBulkValidate);
        ApexPages.currentPage().getParameters().put('ids', String.valueOf(workRecord.Id));

        FreeeInvoiceWorkBulkActionController controller = new FreeeInvoiceWorkBulkActionController();
        controller.validateSelected();

        System.assertEquals(false, controller.getHasError(), controller.errorMessage == null ? '' : controller.errorMessage);
        System.assertEquals(1, controller.summary.selectedCount);
        System.assertEquals(1, controller.summary.needsReviewCount);
    }

    private static Mig_FreeeInvoiceWork__c createWork(String statusValue, String freeeInvoiceId) {
        Mig_FreeeInvoiceWork__c workRecord = new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = Mig_FreeeInvoiceWorkService.buildInvoiceExternalKey(1, freeeInvoiceId),
            FreeeInvoiceId__c = freeeInvoiceId,
            FreeeInvoiceNumber__c = 'INV-' + freeeInvoiceId,
            PartnerName__c = 'テスト取引先',
            BillingDate__c = Date.newInstance(2026, 6, 20),
            InvoiceAmount__c = 1100,
            ImportStatus__c = statusValue
        );
        insert workRecord;
        return workRecord;
    }
}
