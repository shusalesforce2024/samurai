public with sharing class InvoiceActionController {
    @AuraEnabled
    public static String cancelInvoice(Id invoiceId) {
        InvoiceCancelService.cancelInvoice(invoiceId);
        return '請求を取消しました。';
    }

    @AuraEnabled
    public static Id recreateInvoice(Id invoiceId) {
        return InvoiceRecreateService.recreateInvoice(invoiceId);
    }
}