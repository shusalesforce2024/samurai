public with sharing class FreeeInvoiceCancelService {
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';

    public static void cancelInvoice(Invoice__c invoiceRecord) {
        if (invoiceRecord == null || invoiceRecord.Freee_Invoice_Id__c == null) {
            return;
        }

        HttpResponse response = FreeeInvoiceService.cancelInvoice(invoiceRecord.Freee_Invoice_Id__c);
        if (response != null
            && response.getStatusCode() >= 200
            && response.getStatusCode() < 300
        ) {
            saveLog(invoiceRecord.Id, response, STATUS_SUCCESS, null);
            return;
        }

        String body = response == null ? null : response.getBody();
        saveLog(invoiceRecord.Id, response, STATUS_FAILED, body);
        throw new AuraHandledException('freee請求書の取消に失敗しました: ' + summarize(body));
    }

    private static void saveLog(
        Id invoiceId,
        HttpResponse response,
        String result,
        String errorMessage
    ) {
        try {
            FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
            logReq.invoiceId = invoiceId;
            logReq.responseBody = response == null ? null : response.getBody();
            logReq.statusCode = response == null ? null : response.getStatusCode();
            logReq.result = result;
            logReq.errorMessage = errorMessage;
            FreeeSyncLogService.saveLog(logReq);
        } catch (Exception e) {
            System.debug('freee請求書取消ログ保存に失敗しました: ' + e.getMessage());
        }
    }

    private static String summarize(String message) {
        if (String.isBlank(message)) {
            return 'レスポンス本文が空です。';
        }
        return message.length() > 32000 ? message.left(32000) : message;
    }
}