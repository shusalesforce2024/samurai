public with sharing class FreeeInvoiceStatusSyncService {
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';
    private static final String DEFAULT_ACCOUNT_ITEM = 'Sales';
    private static final String SEND_WAITING = '送付待ち';
    private static final String SEND_DONE = '送付済み';
    private static final String PAYMENT_WAITING = '決済待ち';
    private static final String PAYMENT_DONE = '決済済み';

    public class SyncResult {
        public Set<Id> processedInvoiceIds = new Set<Id>();
        public Id rateLimitedInvoiceId;
        public Integer retryAfterMinutes;

        public Boolean isRateLimited() {
            return rateLimitedInvoiceId != null;
        }
    }

    public static void syncInvoices(List<Invoice__c> invoices) {
        syncInvoicesWithResult(invoices);
    }

    public static SyncResult syncInvoicesWithResult(List<Invoice__c> invoices) {
        SyncResult result = new SyncResult();
        if (invoices == null || invoices.isEmpty()) {
            return result;
        }

        List<Invoice__c> invoicesToUpdate = new List<Invoice__c>();
        List<FreeeSyncLogService.LogRequest> logsToSave = new List<FreeeSyncLogService.LogRequest>();
        for (Invoice__c invoiceRecord : invoices) {
            if (invoiceRecord.Freee_Invoice_Id__c == null) {
                continue;
            }

            HttpResponse response;
            try {
                response = FreeeInvoiceService.getInvoice(invoiceRecord.Freee_Invoice_Id__c);
                if (isSuccess(response)) {
                    invoicesToUpdate.add(buildSyncedInvoice(invoiceRecord, response));
                    logsToSave.add(buildLog(invoiceRecord.Id, null, response, STATUS_SUCCESS, null));
                } else if (response != null && response.getStatusCode() == 429) {
                    result.rateLimitedInvoiceId = invoiceRecord.Id;
                    result.retryAfterMinutes =
                        calculateRateLimitRetryMinutes(response.getBody());
                    String rateLimitMessage = buildRateLimitMessage(
                        response.getBody(),
                        result.retryAfterMinutes
                    );
                    invoicesToUpdate.add(buildFailedInvoice(invoiceRecord, rateLimitMessage));
                    logsToSave.add(buildLog(
                        invoiceRecord.Id,
                        null,
                        response,
                        STATUS_FAILED,
                        rateLimitMessage
                    ));
                    result.processedInvoiceIds.add(invoiceRecord.Id);
                    break;
                } else {
                    invoicesToUpdate.add(buildFailedInvoice(invoiceRecord, response.getBody()));
                    logsToSave.add(buildLog(
                        invoiceRecord.Id,
                        null,
                        response,
                        STATUS_FAILED,
                        summarizeError(response.getBody())
                    ));
                }
                result.processedInvoiceIds.add(invoiceRecord.Id);
            } catch (Exception e) {
                invoicesToUpdate.add(buildFailedInvoice(invoiceRecord, e.getMessage()));
                logsToSave.add(buildLog(
                    invoiceRecord.Id,
                    null,
                    response,
                    STATUS_FAILED,
                    response == null ? e.getMessage() : e.getMessage() + '\n\nRaw response:\n' + response.getBody()
                ));
                result.processedInvoiceIds.add(invoiceRecord.Id);
            }
        }

        if (!invoicesToUpdate.isEmpty()) {
            Database.SaveResult[] results = Database.update(invoicesToUpdate, false);
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    logsToSave.add(buildLog(
                        invoicesToUpdate[i].Id,
                        null,
                        null,
                        STATUS_FAILED,
                        summarizeDmlErrors(results[i].getErrors())
                    ));
                }
            }
        }

        saveLogs(logsToSave);
        return result;
    }

    private static Boolean isSuccess(HttpResponse response) {
        return response != null
            && response.getStatusCode() >= 200
            && response.getStatusCode() < 300;
    }

    private static Invoice__c buildSyncedInvoice(Invoice__c source, HttpResponse response) {
        Map<String, Object> invoiceMap = extractInvoiceMap(response.getBody());
        validateResponseInvoiceId(source, invoiceMap);

        Invoice__c invoiceToUpdate = new Invoice__c(Id = source.Id);
        invoiceToUpdate.Freee_Invoice_Status__c = mapSendStatus(firstString(invoiceMap, new List<String>{
            'sending_status',
            'send_status',
            'invoice_status',
            'status'
        }));
        invoiceToUpdate.PaymentStatus__c = mapPaymentStatus(firstString(invoiceMap, new List<String>{
            'payment_status',
            'settlement_status',
            'deal_status'
        }));
        Decimal invoiceAmount = resolveInvoiceAmount(source, invoiceMap);
        invoiceToUpdate.PaidAmount__c = resolvePaidAmount(invoiceMap, invoiceAmount, invoiceToUpdate.PaymentStatus__c);
        invoiceToUpdate.UnpaidAmount__c = resolveUnpaidAmount(invoiceMap, invoiceAmount, invoiceToUpdate.PaymentStatus__c);
        invoiceToUpdate.PaymentReceivedDate__c = firstDate(invoiceMap, new List<String>{
            'paid_at',
            'settlement_date',
            'payment_received_date'
        });
        invoiceToUpdate.Payment_Date__c = firstDate(invoiceMap, new List<String>{
            'payment_limit_date',
            'due_date',
            'payment_date'
        });
        applyRequiredDefaults(source, invoiceToUpdate);
        invoiceToUpdate.Freee_Sync_Status__c = STATUS_SUCCESS;
        invoiceToUpdate.Freee_Sync_Message__c = null;
        invoiceToUpdate.Freee_Last_Synced_At__c = System.now();
        return invoiceToUpdate;
    }

    private static void validateResponseInvoiceId(Invoice__c source, Map<String, Object> invoiceMap) {
        Decimal responseInvoiceId = firstDecimal(invoiceMap, new List<String>{'id', 'invoice_id'});
        if (responseInvoiceId == null) {
            return;
        }
        if (source.Freee_Invoice_Id__c != responseInvoiceId) {
            throw new FreeeInvoiceStatusMismatchException(
                'freee invoice id mismatch. Salesforce Freee_Invoice_Id__c='
                + String.valueOf(source.Freee_Invoice_Id__c)
                + ', freee response id='
                + String.valueOf(responseInvoiceId)
            );
        }
    }

    private static Invoice__c buildFailedInvoice(Invoice__c source, String message) {
        Invoice__c invoiceToUpdate = new Invoice__c(
            Id = source.Id,
            Freee_Sync_Status__c = STATUS_FAILED,
            Freee_Sync_Message__c = summarizeError(message),
            Freee_Last_Synced_At__c = System.now()
        );
        applyRequiredDefaults(source, invoiceToUpdate);
        return invoiceToUpdate;
    }

    private static void applyRequiredDefaults(Invoice__c source, Invoice__c invoiceToUpdate) {
        Object accountItem = source.getPopulatedFieldsAsMap().get('Freee_Account_Item_Picklist__c');
        if (accountItem == null || String.isBlank(String.valueOf(accountItem))) {
            invoiceToUpdate.Freee_Account_Item_Picklist__c = DEFAULT_ACCOUNT_ITEM;
        }
    }

    private static Decimal resolveInvoiceAmount(Invoice__c source, Map<String, Object> invoiceMap) {
        Decimal responseAmount = firstDecimal(invoiceMap, new List<String>{'total_amount', 'amount', 'invoice_amount'});
        if (responseAmount != null) {
            return responseAmount;
        }

        Object sourceAmount = source.getPopulatedFieldsAsMap().get('InvoiceAmount__c');
        if (sourceAmount instanceof Decimal) {
            return (Decimal) sourceAmount;
        }
        if (sourceAmount != null) {
            try {
                return Decimal.valueOf(String.valueOf(sourceAmount));
            } catch (Exception e) {
                return null;
            }
        }
        return null;
    }

    private static Decimal resolvePaidAmount(Map<String, Object> invoiceMap, Decimal invoiceAmount, String paymentStatus) {
        if (invoiceAmount != null && paymentStatus == PAYMENT_DONE) {
            return invoiceAmount;
        }
        if (invoiceAmount != null && paymentStatus == PAYMENT_WAITING) {
            return 0;
        }
        return firstDecimal(invoiceMap, new List<String>{'paid_amount', 'payment_amount', 'settled_amount'});
    }

    private static Decimal resolveUnpaidAmount(Map<String, Object> invoiceMap, Decimal invoiceAmount, String paymentStatus) {
        if (invoiceAmount != null && paymentStatus == PAYMENT_DONE) {
            return 0;
        }
        if (invoiceAmount != null && paymentStatus == PAYMENT_WAITING) {
            return invoiceAmount;
        }
        return firstDecimal(invoiceMap, new List<String>{'unpaid_amount', 'remaining_amount', 'balance'});
    }

    private static Map<String, Object> extractInvoiceMap(String body) {
        if (String.isBlank(body)) {
            return new Map<String, Object>();
        }

        Object parsed = JSON.deserializeUntyped(body);
        if (!(parsed instanceof Map<String, Object>)) {
            return new Map<String, Object>();
        }

        Map<String, Object> root = (Map<String, Object>) parsed;
        Object invoiceObject = root.get('invoice');
        if (invoiceObject instanceof Map<String, Object>) {
            return (Map<String, Object>) invoiceObject;
        }
        return root;
    }

    private static String mapSendStatus(String sourceStatus) {
        if (String.isBlank(sourceStatus)) {
            return null;
        }
        String normalized = sourceStatus.trim().toLowerCase();
        if (sourceStatus == SEND_DONE
            || normalized == 'sent'
            || normalized == 'sending'
            || normalized == 'delivered'
            || normalized == 'submitted'
        ) {
            return SEND_DONE;
        }
        if (sourceStatus == SEND_WAITING
            || normalized == 'unsent'
            || normalized == 'not_sent'
            || normalized == 'waiting'
            || normalized == 'draft'
        ) {
            return SEND_WAITING;
        }
        return sourceStatus;
    }

    private static String mapPaymentStatus(String sourceStatus) {
        if (String.isBlank(sourceStatus)) {
            return null;
        }
        String normalized = sourceStatus.trim().toLowerCase();
        if (sourceStatus == PAYMENT_DONE
            || normalized == 'paid'
            || normalized == 'settled'
            || normalized == 'completed'
        ) {
            return PAYMENT_DONE;
        }
        if (sourceStatus == PAYMENT_WAITING
            || normalized == 'unpaid'
            || normalized == 'waiting'
            || normalized == 'unsettled'
        ) {
            return PAYMENT_WAITING;
        }
        return sourceStatus;
    }

    private static String firstString(Map<String, Object> source, List<String> keys) {
        for (String key : keys) {
            Object value = source.get(key);
            if (value != null && !String.isBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }
        return null;
    }

    private static Decimal firstDecimal(Map<String, Object> source, List<String> keys) {
        String value = firstString(source, keys);
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    private static Date firstDate(Map<String, Object> source, List<String> keys) {
        String value = firstString(source, keys);
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(value.left(10));
        } catch (Exception e) {
            return null;
        }
    }

    private static String summarizeError(String body) {
        if (String.isBlank(body)) {
            return 'freeeからレスポンスを取得できませんでした。';
        }
        return body.length() > 32000 ? body.left(32000) : body;
    }

    private static String buildRateLimitMessage(String responseBody, Integer retryAfterMinutes) {
        String message = 'freee APIの利用上限に達しました。';
        if (retryAfterMinutes != null) {
            message += String.valueOf(retryAfterMinutes) + '分後に自動再開します。';
        }
        if (!String.isBlank(responseBody)) {
            message += ' response=' + responseBody;
        }
        return summarizeError(message);
    }

    @TestVisible
    private static Integer calculateRateLimitRetryMinutes(String responseBody) {
        Integer fallbackMinutes = 30;
        if (String.isBlank(responseBody)) {
            return fallbackMinutes;
        }

        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (!(parsed instanceof Map<String, Object>)) {
                return fallbackMinutes;
            }
            Map<String, Object> root = (Map<String, Object>) parsed;
            Object metaObject = root.get('meta');
            if (!(metaObject instanceof Map<String, Object>)) {
                return fallbackMinutes;
            }
            Map<String, Object> meta = (Map<String, Object>) metaObject;
            Integer period = meta.get('period') == null
                ? null
                : Integer.valueOf(String.valueOf(meta.get('period')));
            String resetValue = meta.get('reset') == null
                ? null
                : String.valueOf(meta.get('reset'));
            Integer resetDelay = minutesUntilReset(resetValue);
            if (resetDelay != null) {
                return Math.max(2, resetDelay + 2);
            }
            if (period != null && period >= 86400) {
                return 480;
            }
            if (period != null && period >= 60) {
                return 3;
            }
        } catch (Exception e) {
            System.debug('freee API制限レスポンスの解析に失敗しました: ' + e.getMessage());
        }
        return fallbackMinutes;
    }

    private static Integer minutesUntilReset(String resetValue) {
        if (String.isBlank(resetValue) || resetValue.length() < 25) {
            return null;
        }

        try {
            Date resetDate = Date.valueOf(resetValue.substring(0, 10));
            Time resetTime = Time.newInstance(
                Integer.valueOf(resetValue.substring(11, 13)),
                Integer.valueOf(resetValue.substring(14, 16)),
                Integer.valueOf(resetValue.substring(17, 19)),
                0
            );
            String offset = resetValue.substring(19);
            Integer sign = offset.startsWith('-') ? -1 : 1;
            Integer offsetHours = Integer.valueOf(offset.substring(1, 3));
            Integer offsetMinutes = Integer.valueOf(offset.substring(4, 6));
            Integer totalOffsetMinutes = sign * ((offsetHours * 60) + offsetMinutes);

            DateTime resetDateTimeGmt = DateTime.newInstanceGmt(resetDate, resetTime)
                .addMinutes(-totalOffsetMinutes);
            Long diffMillis = resetDateTimeGmt.getTime() - System.now().getTime();
            if (diffMillis <= 0) {
                return 2;
            }
            Long minutes = (diffMillis + 59999) / 60000;
            return Integer.valueOf(String.valueOf(minutes));
        } catch (Exception e) {
            System.debug('freee API制限リセット時刻の解析に失敗しました: ' + e.getMessage());
            return null;
        }
    }

    private static String summarizeDmlErrors(Database.Error[] errors) {
        List<String> messages = new List<String>();
        for (Database.Error error : errors) {
            messages.add(error.getStatusCode() + ': ' + error.getMessage());
        }
        return summarizeError(String.join(messages, '\n'));
    }

    private static FreeeSyncLogService.LogRequest buildLog(
        Id invoiceId,
        String requestBody,
        HttpResponse response,
        String result,
        String errorMessage
    ) {
        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = invoiceId;
        logReq.requestBody = requestBody;
        logReq.responseBody = response == null ? null : response.getBody();
        logReq.statusCode = response == null ? null : response.getStatusCode();
        logReq.result = result;
        logReq.errorMessage = errorMessage;
        return logReq;
    }

    private static void saveLogs(List<FreeeSyncLogService.LogRequest> logRequests) {
        if (logRequests == null || logRequests.isEmpty()) {
            return;
        }

        for (FreeeSyncLogService.LogRequest logReq : logRequests) {
            saveLog(logReq);
        }
    }

    private static void saveLog(FreeeSyncLogService.LogRequest logReq) {
        try {
            FreeeSyncLogService.saveLog(logReq);
        } catch (Exception e) {
            System.debug('freee請求書ステータス同期ログ保存に失敗しました: ' + e.getMessage());
        }
    }

    private class FreeeInvoiceStatusMismatchException extends Exception {}
}
