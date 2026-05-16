public with sharing class FreeeInvoiceFacade {
    public class FreeeInvoiceDebugException extends Exception {}

    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';

    public static void createInvoice(Id invoiceId) {
        FreeeInvoiceContext ctx = new FreeeInvoiceContext();

        try {
            ctx.invoice = getInvoice(invoiceId);
            ctx.lines = getInvoiceLines(invoiceId);

            validateBeforeSync(ctx.invoice, ctx.lines);

            ctx.config = FreeeConfigService.getConfig();
            ctx.requestBody = FreeeInvoiceMapper.toRequestBody(
                ctx.invoice,
                ctx.lines,
                ctx.config
            );

            ctx.response = executeCreateInvoice(ctx.requestBody);
            processResponse(ctx);
        } catch (Exception e) {
            if (!(e instanceof FreeeInvoiceDebugException)) {
                handleExceptionSafely(ctx, e);
            }
            throw e;
        }
    }

    private static Invoice__c getInvoice(Id invoiceId) {
        if (!Schema.sObjectType.Invoice__c.isAccessible()) {
            throw new AuraHandledException('Invoice__c の参照権限がありません。');
        }

        List<Invoice__c> invoices = [
            SELECT Id,
                   Account__c,
                   Account__r.Freee_Partner_Id__c,
                   Subject__c,
                   Billing_Date__c,
                   Payment_Date__c,
                   Payment_Type__c,
                   Memo__c,
                   Freee_Account_Item_Picklist__c,
                   Freee_Partner_Id__c,
                   Freee_Invoice_Id__c,
                   Freee_Invoice_Number__c,
                   Freee_Invoice_Url__c,
                   Freee_Sync_Status__c,
                   Freee_Sync_Message__c,
                   Freee_Last_Synced_At__c,
                   Sent_To_Freee__c,
                   Retry_Count__c
            FROM Invoice__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        if (invoices.isEmpty()) {
            throw new AuraHandledException('対象の請求書が見つかりません。');
        }

        return invoices[0];
    }

    private static List<InvoiceLine__c> getInvoiceLines(Id invoiceId) {
        if (!Schema.sObjectType.InvoiceLine__c.isAccessible()) {
            throw new AuraHandledException('InvoiceLine__c の参照権限がありません。');
        }

        return [
            SELECT Id,
                   Description__c,
                   Quantity__c,
                   Unit_Price__c,
                   Tax_Rate__c,
                   Reduced_Tax__c,
                   Withholding__c
            FROM InvoiceLine__c
            WHERE Invoice__c = :invoiceId
            ORDER BY CreatedDate ASC
        ];
    }

    private static void validateBeforeSync(Invoice__c invoice, List<InvoiceLine__c> lines) {
        validateHeader(invoice, lines);
        validateLines(lines);
        validateNotAlreadySynced(invoice);
    }

    private static void validateNotAlreadySynced(Invoice__c invoice) {
        if (invoice.Sent_To_Freee__c == true || invoice.Freee_Invoice_Id__c != null) {
            throw new AuraHandledException('この請求書はすでに freee へ送信済みです。');
        }
    }

    private static void validateHeader(Invoice__c invoice, List<InvoiceLine__c> lines) {
        List<String> errors = new List<String>();

        if (invoice.Account__c == null) {
            errors.add('取引先が設定されていません。');
        }
        if (invoice.Account__r == null || invoice.Account__r.Freee_Partner_Id__c == null) {
            errors.add('取引先の freee取引先ID が設定されていません。');
        }
        if (invoice.Billing_Date__c == null) {
            errors.add('請求日が設定されていません。');
        }
        if (String.isBlank(invoice.Freee_Account_Item_Picklist__c)) {
            errors.add('Freee計上科目が設定されていません。');
        }
        if (lines == null || lines.isEmpty()) {
            errors.add('請求書明細がありません。');
        }

        throwIfErrors(errors);
    }

    private static void validateLines(List<InvoiceLine__c> lines) {
        List<String> errors = new List<String>();

        for (InvoiceLine__c line : lines) {
            if (String.isBlank(line.Description__c)) {
                errors.add('明細名が設定されていません。');
            }
            if (line.Quantity__c == null || line.Quantity__c <= 0) {
                errors.add('数量は 0 より大きくしてください。');
            }
            if (line.Unit_Price__c == null || line.Unit_Price__c <= 0) {
                errors.add('単価は 0 より大きくしてください。');
            }
            if (line.Tax_Rate__c == null) {
                errors.add('税率が設定されていません。');
            }
        }

        throwIfErrors(errors);
    }

    private static void throwIfErrors(List<String> errors) {
        if (!errors.isEmpty()) {
            throw new AuraHandledException(String.join(errors, '\n'));
        }
    }

    private static HttpResponse executeCreateInvoice(String requestBody) {
        return FreeeInvoiceService.createInvoice(requestBody);
    }

    private static void processResponse(FreeeInvoiceContext ctx) {
        if (isSuccessStatus(ctx.response)) {
            handleSuccess(ctx);
        } else {
            handleFailure(ctx);
        }
    }

    private static Boolean isSuccessStatus(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        return statusCode >= 200 && statusCode < 300;
    }

    private static void handleSuccess(FreeeInvoiceContext ctx) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(ctx.response.getBody());
        Map<String, Object> invoiceMap =
            (Map<String, Object>) responseMap.get('invoice');

        if (invoiceMap == null || invoiceMap.get('id') == null) {
            throw new AuraHandledException('freee のレスポンスから請求書IDを取得できませんでした。');
        }

        Long freeeInvoiceId = Long.valueOf(String.valueOf(invoiceMap.get('id')));
        String freeeInvoiceNumber = String.valueOf(invoiceMap.get('invoice_number'));
        String freeeUrl = buildInvoiceUrl(ctx.config.invoiceBaseUrl, freeeInvoiceId);

        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            throw new AuraHandledException('Invoice__c の更新権限がありません。');
        }

        ctx.invoice.Freee_Invoice_Id__c = freeeInvoiceId;
        ctx.invoice.Freee_Invoice_Number__c = freeeInvoiceNumber;
        ctx.invoice.Freee_Invoice_Url__c = freeeUrl;
        ctx.invoice.Freee_Partner_Id__c = ctx.invoice.Account__r.Freee_Partner_Id__c;
        ctx.invoice.Freee_Sync_Status__c = STATUS_SUCCESS;
        ctx.invoice.Freee_Sync_Message__c = null;
        ctx.invoice.Freee_Last_Synced_At__c = System.now();
        ctx.invoice.Sent_To_Freee__c = true;
        update ctx.invoice;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.invoice.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response.getBody();
        logReq.statusCode = ctx.response.getStatusCode();
        logReq.result = STATUS_SUCCESS;
        saveLogSafely(logReq);
    }

    private static void handleFailure(FreeeInvoiceContext ctx) {
        Integer retryCount = getRetryCount(ctx.invoice);
        String detailedError = buildDetailedFreeeError(ctx.response.getBody());

        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            throw new FreeeInvoiceDebugException('Invoice__c の更新権限がありません。');
        }

        ctx.invoice.Retry_Count__c = retryCount + 1;
        ctx.invoice.Freee_Sync_Status__c = STATUS_FAILED;
        ctx.invoice.Freee_Sync_Message__c = detailedError;
        update ctx.invoice;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.invoice.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response.getBody();
        logReq.statusCode = ctx.response.getStatusCode();
        logReq.result = STATUS_FAILED;
        logReq.errorMessage = detailedError;
        saveLogSafely(logReq);

        throw new FreeeInvoiceDebugException(
            'freee 請求書連携に失敗しました: ' + detailedError
        );
    }

    private static void handleExceptionSafely(FreeeInvoiceContext ctx, Exception e) {
        if (ctx == null || ctx.invoice == null) {
            System.debug('freee 請求書連携エラー(請求書取得前): ' + e.getMessage());
            return;
        }

        Integer retryCount = getRetryCount(ctx.invoice);
        if (!Schema.sObjectType.Invoice__c.isUpdateable()) {
            System.debug('Invoice__c の更新権限がありません。エラー: ' + e.getMessage());
            return;
        }

        ctx.invoice.Retry_Count__c = retryCount + 1;
        ctx.invoice.Freee_Sync_Status__c = STATUS_FAILED;
        ctx.invoice.Freee_Sync_Message__c = e.getMessage();
        update ctx.invoice;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.invoice.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response == null ? null : ctx.response.getBody();
        logReq.statusCode = ctx.response == null ? null : ctx.response.getStatusCode();
        logReq.result = STATUS_FAILED;
        logReq.errorMessage = buildExceptionLogMessage(e, ctx.response);
        saveLogSafely(logReq);
    }

    private static Integer getRetryCount(Invoice__c invoice) {
        if (invoice.Retry_Count__c == null) {
            return 0;
        }
        return Integer.valueOf(invoice.Retry_Count__c);
    }

    private static void saveLogSafely(FreeeSyncLogService.LogRequest logReq) {
        try {
            FreeeSyncLogService.saveLog(logReq);
        } catch (Exception logException) {
            System.debug('freee 請求書連携ログ保存に失敗しました: ' + logException.getMessage());
        }
    }

    private static String buildInvoiceUrl(String invoiceBaseUrl, Long freeeInvoiceId) {
        if (String.isBlank(invoiceBaseUrl)) {
            return null;
        }

        return invoiceBaseUrl + String.valueOf(freeeInvoiceId);
    }

    private static String summarizeFreeeError(String responseBody) {
        if (String.isBlank(responseBody)) {
            return 'freee からエラー詳細を取得できませんでした。';
        }

        try {
            Object parsed = JSON.deserializeUntyped(responseBody);
            if (!(parsed instanceof Map<String, Object>)) {
                return responseBody;
            }

            Map<String, Object> bodyMap = (Map<String, Object>) parsed;
            if (bodyMap.containsKey('message') && bodyMap.get('message') != null) {
                return String.valueOf(bodyMap.get('message'));
            }

            if (bodyMap.containsKey('errors') && bodyMap.get('errors') instanceof List<Object>) {
                List<Object> errors = (List<Object>) bodyMap.get('errors');
                List<String> messages = new List<String>();

                for (Object errorItem : errors) {
                    if (errorItem instanceof Map<String, Object>) {
                        Map<String, Object> errorMap = (Map<String, Object>) errorItem;
                        if (errorMap.containsKey('messages')
                            && errorMap.get('messages') instanceof List<Object>
                        ) {
                            List<Object> errorMessages = (List<Object>) errorMap.get('messages');
                            for (Object errorMessage : errorMessages) {
                                if (errorMessage != null) {
                                    messages.add(String.valueOf(errorMessage));
                                }
                            }
                        } else if (errorMap.containsKey('message')
                            && errorMap.get('message') != null
                        ) {
                            messages.add(String.valueOf(errorMap.get('message')));
                        } else {
                            messages.add(JSON.serialize(errorMap));
                        }
                    } else if (errorItem != null) {
                        messages.add(String.valueOf(errorItem));
                    }
                }

                if (!messages.isEmpty()) {
                    return String.join(messages, ' / ');
                }
            }
        } catch (Exception e) {
            System.debug('freee エラーレスポンスの解析に失敗しました: ' + e.getMessage());
        }

        return responseBody;
    }

    private static String buildDetailedFreeeError(String responseBody) {
        String summary = summarizeFreeeError(responseBody);

        if (String.isBlank(responseBody)) {
            return summary;
        }
        if (summary == responseBody) {
            return responseBody;
        }

        return summary + '\n\nRaw response:\n' + responseBody;
    }

    private static String buildExceptionLogMessage(Exception e, HttpResponse response) {
        if (response == null || String.isBlank(response.getBody())) {
            return e.getMessage();
        }

        return e.getMessage() + '\n\nRaw response:\n' + response.getBody();
    }
}