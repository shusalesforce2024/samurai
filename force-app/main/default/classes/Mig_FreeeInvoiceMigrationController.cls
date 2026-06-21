public with sharing class Mig_FreeeInvoiceMigrationController {
    @AuraEnabled
    public static void validateAll() {
        Mig_FreeeInvoiceValidator.validateAll();
    }

    @AuraEnabled
    public static void finalizeReady() {
        Mig_FreeeInvoiceFinalizeService.finalizeAllReady();
    }

    @AuraEnabled
    public static void finalizeByIds(List<Id> workIds) {
        Mig_FreeeInvoiceFinalizeService.finalizeByWorkIds(workIds);
    }
}
