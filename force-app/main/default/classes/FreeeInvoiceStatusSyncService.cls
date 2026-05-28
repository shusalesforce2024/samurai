public with sharing class FreeeInvoiceStatusSyncService {
    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';
    private static final String DEFAULT_ACCOUNT_ITEM = 'Sales';
    private static final String SEND_WAITING = '送付待ち';
    private static final String SEND_DONE = '送付済み';
    private static final String PAYMENT_WAITING = '決済待ち';
    private static final String PAYMENT_DONE = '決済済み';

    public static void syncInvoices(List<Invoice__c> invoices) {
        if (invoices == null || invoices.isEmpty()) {
            return;
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
            } catch (Exception e) {
                invoicesToUpdate.add(buildFailedInvoice(invoiceRecord, e.getMessage()));
                logsToSave.add(buildLog(
                    invoiceRecord.Id,
                    null,
                    response,
                    STATUS_FAILED,
                    response == null ? e.getMessage() : e.getMessage() + '\n\nRaw response:\n' + response.getBody()
                ));
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
    }

    private static Boolean isSuccess(HttpResponse response) {
        return response != null
            && response.getStatusCode() >= 200
            && response.getStatusCode() < 300;
    }

    private static Invoice__c buildSyncedInvoice(Invoice__c source, HttpResponse response) {
        Map<String, Object> invoiceMap = extractInvoiceMap(response.getBody());

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
        invoiceToUpdate.PaidAmount__c = firstDecimal(invoiceMap, new List<String>{
            'paid_amount',
            'payment_amount',
            'settled_amount'
        });
        invoiceToUpdate.UnpaidAmount__c = firstDecimal(invoiceMap, new List<String>{
            'unpaid_amount',
            'remaining_amount',
            'balance'
        });
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
}
