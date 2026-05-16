public with sharing class FreeeQuotationFacade {
    public class FreeeQuotationDebugException extends Exception {}

    private static final String STATUS_SUCCESS = 'Success';
    private static final String STATUS_FAILED = 'Failed';

    public static void createQuotation(Id quotationId) {
        FreeeQuotationContext ctx = new FreeeQuotationContext();

        try {
            ctx.quotation = getQuotation(quotationId);
            ctx.lines = getQuotationLines(quotationId);

            validateBeforeSync(ctx.quotation, ctx.lines);

            ctx.config = FreeeConfigService.getConfig();
            ctx.requestBody = FreeeQuotationMapper.toRequestBody(
                ctx.quotation,
                ctx.lines,
                ctx.config
            );

            ctx.response = executeCreateQuotation(ctx.requestBody);
            processResponse(ctx);
        } catch (Exception e) {
            if (!(e instanceof FreeeQuotationDebugException)) {
                handleExceptionSafely(ctx, e);
            }
            throw e;
        }
    }

    private static Quotation__c getQuotation(Id quotationId) {
        if (!Schema.sObjectType.Quotation__c.isAccessible()) {
            throw new AuraHandledException('Quotation__c の参照権限がありません。');
        }

        List<Quotation__c> quotations = [
            SELECT Id,
                   Account__c,
                   Account__r.Freee_Partner_Id__c,
                   Subject__c,
                   Memo__c,
                   Issue_Date__c,
                   Expiration_Date__c,
                   Quotation_Status__c,
                   Freee_Partner_Id__c,
                   Freee_Quotation_Id__c,
                   Freee_Quotation_Number__c,
                   Freee_Quotation_URL__c,
                   Freee_Sync_Status__c,
                   Freee_Sync_Message__c,
                   Freee_Last_Synced_At__c,
                   Sent_To_Freee__c,
                   Retry_Count__c
            FROM Quotation__c
            WHERE Id = :quotationId
            LIMIT 1
        ];

        if (quotations.isEmpty()) {
            throw new AuraHandledException('対象の見積が見つかりません。');
        }

        return quotations[0];
    }

    private static List<QuotationLine__c> getQuotationLines(Id quotationId) {
        if (!Schema.sObjectType.QuotationLine__c.isAccessible()) {
            throw new AuraHandledException('QuotationLine__c の参照権限がありません。');
        }

        return [
            SELECT Id,
                   Description__c,
                   Quantity__c,
                   Unit_Price__c,
                   Tax_Rate__c,
                   Withholding__c
            FROM QuotationLine__c
            WHERE Quotation__c = :quotationId
            ORDER BY CreatedDate ASC
        ];
    }

    private static void validateBeforeSync(
        Quotation__c quotation,
        List<QuotationLine__c> lines
    ) {
        validateHeader(quotation, lines);
        validateLines(lines);
        validateNotAlreadySynced(quotation);
    }

    private static void validateNotAlreadySynced(Quotation__c quotation) {
        if (quotation.Sent_To_Freee__c == true || quotation.Freee_Quotation_Id__c != null) {
            throw new AuraHandledException('この見積はすでに freee へ送信済みです。');
        }
    }

    private static void validateHeader(
        Quotation__c quotation,
        List<QuotationLine__c> lines
    ) {
        List<String> errors = new List<String>();

        if (quotation.Account__c == null) {
            errors.add('取引先が設定されていません。');
        }
        if (quotation.Account__r == null || quotation.Account__r.Freee_Partner_Id__c == null) {
            errors.add('取引先の freee取引先ID が設定されていません。');
        }
        if (quotation.Issue_Date__c == null) {
            errors.add('見積日が設定されていません。');
        }
        if (lines == null || lines.isEmpty()) {
            errors.add('見積明細がありません。');
        }

        throwIfErrors(errors);
    }

    private static void validateLines(List<QuotationLine__c> lines) {
        List<String> errors = new List<String>();

        for (QuotationLine__c line : lines) {
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

    private static HttpResponse executeCreateQuotation(String requestBody) {
        return FreeeQuotationService.createQuotation(requestBody);
    }

    private static void processResponse(FreeeQuotationContext ctx) {
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

    private static void handleSuccess(FreeeQuotationContext ctx) {
        Map<String, Object> responseMap =
            (Map<String, Object>) JSON.deserializeUntyped(ctx.response.getBody());
        Map<String, Object> quotationMap =
            (Map<String, Object>) responseMap.get('quotation');

        if (quotationMap == null || quotationMap.get('id') == null) {
            throw new AuraHandledException('freee のレスポンスから見積IDを取得できませんでした。');
        }

        Long freeeQuotationId = Long.valueOf(String.valueOf(quotationMap.get('id')));
        String freeeQuotationNumber = String.valueOf(quotationMap.get('quotation_number'));
        String freeeUrl = buildQuotationUrl(ctx.config.invoiceBaseUrl, freeeQuotationId);

        if (!Schema.sObjectType.Quotation__c.isUpdateable()) {
            throw new AuraHandledException('Quotation__c の更新権限がありません。');
        }

        ctx.quotation.Freee_Quotation_Id__c = freeeQuotationId;
        ctx.quotation.Freee_Quotation_Number__c = freeeQuotationNumber;
        ctx.quotation.Freee_Quotation_URL__c = freeeUrl;
        ctx.quotation.Freee_Partner_Id__c = ctx.quotation.Account__r.Freee_Partner_Id__c;
        ctx.quotation.Freee_Sync_Status__c = STATUS_SUCCESS;
        ctx.quotation.Freee_Sync_Message__c = null;
        ctx.quotation.Freee_Last_Synced_At__c = System.now();
        ctx.quotation.Sent_To_Freee__c = true;
        update ctx.quotation;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.quotation.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response.getBody();
        logReq.statusCode = ctx.response.getStatusCode();
        logReq.result = STATUS_SUCCESS;
        saveLogSafely(logReq);
    }

    private static void handleFailure(FreeeQuotationContext ctx) {
        Integer retryCount = getRetryCount(ctx.quotation);
        String detailedError = buildDetailedFreeeError(ctx.response.getBody());

        if (!Schema.sObjectType.Quotation__c.isUpdateable()) {
            throw new FreeeQuotationDebugException('Quotation__c の更新権限がありません。');
        }

        ctx.quotation.Retry_Count__c = retryCount + 1;
        ctx.quotation.Freee_Sync_Status__c = STATUS_FAILED;
        ctx.quotation.Freee_Sync_Message__c = detailedError;
        update ctx.quotation;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.quotation.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response.getBody();
        logReq.statusCode = ctx.response.getStatusCode();
        logReq.result = STATUS_FAILED;
        logReq.errorMessage = detailedError;
        saveLogSafely(logReq);

        throw new FreeeQuotationDebugException(
            'freee 見積連携に失敗しました: ' + detailedError
        );
    }

    private static void handleExceptionSafely(FreeeQuotationContext ctx, Exception e) {
        if (ctx == null || ctx.quotation == null) {
            System.debug('freee 見積連携エラー(見積取得前): ' + e.getMessage());
            return;
        }

        Integer retryCount = getRetryCount(ctx.quotation);
        if (!Schema.sObjectType.Quotation__c.isUpdateable()) {
            System.debug('Quotation__c の更新権限がありません。エラー: ' + e.getMessage());
            return;
        }

        ctx.quotation.Retry_Count__c = retryCount + 1;
        ctx.quotation.Freee_Sync_Status__c = STATUS_FAILED;
        ctx.quotation.Freee_Sync_Message__c = e.getMessage();
        update ctx.quotation;

        FreeeSyncLogService.LogRequest logReq = new FreeeSyncLogService.LogRequest();
        logReq.invoiceId = ctx.quotation.Id;
        logReq.requestBody = ctx.requestBody;
        logReq.responseBody = ctx.response == null ? null : ctx.response.getBody();
        logReq.statusCode = ctx.response == null ? null : ctx.response.getStatusCode();
        logReq.result = STATUS_FAILED;
        logReq.errorMessage = buildExceptionLogMessage(e, ctx.response);
        saveLogSafely(logReq);
    }

    private static Integer getRetryCount(Quotation__c quotation) {
        if (quotation.Retry_Count__c == null) {
            return 0;
        }
        return Integer.valueOf(quotation.Retry_Count__c);
    }

    private static void saveLogSafely(FreeeSyncLogService.LogRequest logReq) {
        try {
            FreeeSyncLogService.saveLog(logReq);
        } catch (Exception logException) {
            System.debug('freee 見積連携ログ保存に失敗しました: ' + logException.getMessage());
        }
    }

    private static String buildQuotationUrl(String invoiceBaseUrl, Long freeeQuotationId) {
        if (String.isBlank(invoiceBaseUrl)) {
            return null;
        }

        String quotationBaseUrl = invoiceBaseUrl.replace('/invoices/', '/quotations/');
        return quotationBaseUrl + String.valueOf(freeeQuotationId);
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
