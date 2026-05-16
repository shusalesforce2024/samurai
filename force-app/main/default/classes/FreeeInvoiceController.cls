public with sharing class FreeeInvoiceController {
    @AuraEnabled
    public static String createInvoice(Id invoiceId) {
        if (invoiceId == null) {
            throw new AuraHandledException('請求書IDが指定されていません。');
        }

        FreeeInvoiceFacade.createInvoice(invoiceId);
        return 'freeeへの請求書送信が完了しました。';
    }
}