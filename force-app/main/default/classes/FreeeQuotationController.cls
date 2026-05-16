public with sharing class FreeeQuotationController {
    @AuraEnabled
    public static String createQuotation(Id quotationId) {
        if (quotationId == null) {
            throw new AuraHandledException('見積IDが指定されていません。');
        }

        FreeeQuotationFacade.createQuotation(quotationId);
        return 'freeeへの見積送信が完了しました。';
    }
}