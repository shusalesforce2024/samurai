public with sharing class OppContractInvoiceController {
    @AuraEnabled
    public static String createContractAndInvoice(Id opportunityId) {
        OppContractInvoiceService.CreationResult result =
            OppContractInvoiceService.createFromOpportunity(opportunityId);

        return '契約・請求・請求明細を作成しました。'
            + ' 契約: 1件'
            + ' / 請求: 1件'
            + ' / 請求明細: '
            + String.valueOf(result.invoiceLineCount)
            + '件';
    }
}