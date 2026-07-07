public with sharing class FreeeQuotationController {
    @AuraEnabled
    public static String createQuotation(Id quotationId) {
        if (quotationId == null) {
            throw new AuraHandledException('見積IDが指定されていません。');
        }

        try {
            FreeeQuotationFacade.createQuotation(quotationId);
            return 'freeeへの見積送信が完了しました。';
        } catch (FreeeQuotationFacade.FreeeQuotationDebugException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(
                'freee見積連携に失敗しました。原因: ' + e.getMessage()
            );
        }
    }
}
