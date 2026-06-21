public with sharing class Mig_FreeeInvoiceWorkService {
    public static final String STATUS_FETCHED = '取得済み';
    public static final String STATUS_NEEDS_REVIEW = '要確認';
    public static final String STATUS_READY = '反映可能';
    public static final String STATUS_IMPORTED = '反映済み';
    public static final String STATUS_EXCLUDED = '対象外';
    public static final String STATUS_ERROR = 'エラー';

    public static final String PRODUCT_STATUS_CANDIDATE = '候補あり';
    public static final String PRODUCT_STATUS_CONFIRMED = '確定済み';
    public static final String PRODUCT_STATUS_NEEDS_REVIEW = '要確認';
    public static final String PRODUCT_STATUS_EXCLUDED = '対象外';

    public static final String SEND_WAITING = '送付待ち';
    public static final String SEND_DONE = '送付済み';
    public static final String PAYMENT_WAITING = '決済待ち';
    public static final String PAYMENT_DONE = '決済済み';

    public class ImportResult {
        public Integer headerCount = 0;
        public Integer lineCount = 0;
    }

    public static ImportResult importResponse(HttpResponse response) {
        if (response == null) {
            throw new Mig_FreeeInvoiceMigrationException('freee response is null.');
        }
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new Mig_FreeeInvoiceMigrationException(
                'freee invoice fetch failed. status=' + response.getStatusCode() + ', body=' + left(response.getBody(), 32000)
            );
        }
        return importBody(response.getBody());
    }

    public static ImportResult importBody(String body) {
        ImportResult result = new ImportResult();
        List<Object> invoiceObjects = extractInvoiceObjects(body);
        if (invoiceObjects.isEmpty()) {
            return result;
        }

        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        List<Mig_FreeeInvoiceWork__c> works = new List<Mig_FreeeInvoiceWork__c>();
        Map<String, Map<String, Object>> rawByExternalKey = new Map<String, Map<String, Object>>();
        for (Object invoiceObject : invoiceObjects) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
            String freeeInvoiceId = firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            if (String.isBlank(freeeInvoiceId)) {
                continue;
            }
            String externalKey = buildInvoiceExternalKey(config.companyId, freeeInvoiceId);
            rawByExternalKey.put(externalKey, invoiceMap);
            works.add(toWork(config.companyId, externalKey, invoiceMap));
        }

        if (works.isEmpty()) {
            return result;
        }

        upsert works Mig_FreeeInvoiceWork__c.ExternalKey__c;
        result.headerCount = works.size();

        Map<String, Id> workIdByKey = new Map<String, Id>();
        for (Mig_FreeeInvoiceWork__c workRecord : [
            SELECT Id, ExternalKey__c
            FROM Mig_FreeeInvoiceWork__c
            WHERE ExternalKey__c IN :rawByExternalKey.keySet()
        ]) {
            workIdByKey.put(workRecord.ExternalKey__c, workRecord.Id);
        }

        List<Mig_FreeeInvoiceLineWork__c> lineWorks = new List<Mig_FreeeInvoiceLineWork__c>();
        for (String externalKey : rawByExternalKey.keySet()) {
            Id workId = workIdByKey.get(externalKey);
            if (workId == null) {
                continue;
            }
            Map<String, Object> invoiceMap = rawByExternalKey.get(externalKey);
            String freeeInvoiceId = firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            Integer fallbackLineNo = 0;
            for (Object lineObject : extractLineObjects(invoiceMap)) {
                if (!(lineObject instanceof Map<String, Object>)) {
                    continue;
                }
                fallbackLineNo++;
                Map<String, Object> lineMap = (Map<String, Object>) lineObject;
                lineWorks.add(toLineWork(config.companyId, workId, freeeInvoiceId, fallbackLineNo, lineMap));
            }
        }

        if (!lineWorks.isEmpty()) {
            upsert lineWorks Mig_FreeeInvoiceLineWork__c.ExternalKey__c;
            result.lineCount = lineWorks.size();
        }
        return result;
    }

    private static Mig_FreeeInvoiceWork__c toWork(Long companyId, String externalKey, Map<String, Object> invoiceMap) {
        String partnerId = firstString(invoiceMap, new List<String>{'partner_id', 'freee_partner_id'});
        String partnerName = firstString(invoiceMap, new List<String>{'partner_name', 'partner_display_name'});
        Object partnerObject = invoiceMap.get('partner');
        if (partnerObject instanceof Map<String, Object>) {
            Map<String, Object> partnerMap = (Map<String, Object>) partnerObject;
            if (String.isBlank(partnerId)) {
                partnerId = firstString(partnerMap, new List<String>{'id'});
            }
            if (String.isBlank(partnerName)) {
                partnerName = firstString(partnerMap, new List<String>{'name', 'display_name'});
            }
        }

        Date billingDate = firstDate(invoiceMap, new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'});
        Date dueDate = firstDate(invoiceMap, new List<String>{'payment_limit_date', 'due_date', 'payment_date'});
        Decimal amount = firstDecimal(invoiceMap, new List<String>{'total_amount', 'amount', 'invoice_amount'});
        Decimal taxAmount = firstDecimal(invoiceMap, new List<String>{'total_vat', 'tax_amount', 'vat'});
        Decimal paidAmount = firstDecimal(invoiceMap, new List<String>{'paid_amount', 'payment_amount', 'settled_amount'});
        Decimal unpaidAmount = firstDecimal(invoiceMap, new List<String>{'unpaid_amount', 'remaining_amount', 'balance'});

        return new Mig_FreeeInvoiceWork__c(
            ExternalKey__c = externalKey,
            FreeeInvoiceId__c = firstString(invoiceMap, new List<String>{'id', 'invoice_id'}),
            FreeeInvoiceNumber__c = firstString(invoiceMap, new List<String>{'invoice_number', 'number'}),
            FreeePartnerId__c = partnerId,
            PartnerName__c = partnerName,
            BillingDate__c = billingDate,
            PaymentDate__c = dueDate,
            Subject__c = firstString(invoiceMap, new List<String>{'subject', 'description', 'title'}),
            InvoiceAmount__c = amount,
            TaxAmount__c = taxAmount,
            PaidAmount__c = paidAmount,
            UnpaidAmount__c = unpaidAmount,
            SendStatus__c = mapSendStatus(firstString(invoiceMap, new List<String>{'sending_status', 'send_status', 'invoice_status', 'status'})),
            PaymentStatus__c = mapPaymentStatus(firstString(invoiceMap, new List<String>{'payment_status', 'settlement_status', 'deal_status'})),
            TargetPeriodStartDate__c = firstDate(invoiceMap, new List<String>{'target_period_start_date', 'period_start_date'}),
            TargetPeriodEndDate__c = firstDate(invoiceMap, new List<String>{'target_period_end_date', 'period_end_date'}),
            RawJson__c = left(JSON.serialize(invoiceMap), 131072),
            ImportStatus__c = STATUS_FETCHED,
            ValidationMessage__c = null
        );
    }

    private static Mig_FreeeInvoiceLineWork__c toLineWork(
        Long companyId,
        Id workId,
        String freeeInvoiceId,
        Integer fallbackLineNo,
        Map<String, Object> lineMap
    ) {
        String freeeLineId = firstString(lineMap, new List<String>{'id', 'line_id'});
        if (String.isBlank(freeeLineId)) {
            freeeLineId = String.valueOf(fallbackLineNo);
        }
        Decimal quantity = firstDecimal(lineMap, new List<String>{'quantity', 'qty'});
        Decimal unitPrice = firstDecimal(lineMap, new List<String>{'unit_price', 'price'});
        Decimal taxRate = firstDecimal(lineMap, new List<String>{'tax_rate', 'vat_rate'});
        Decimal lineAmount = firstDecimal(lineMap, new List<String>{'amount_excluding_tax', 'amount', 'line_amount', 'subtotal'});
        if (lineAmount == null && unitPrice != null && quantity != null) {
            lineAmount = unitPrice * quantity;
        }
        Decimal taxAmount = firstDecimal(lineMap, new List<String>{'tax_amount', 'vat'});
        if (taxAmount == null && lineAmount != null && taxRate != null) {
            taxAmount = (lineAmount * taxRate / 100).setScale(0, System.RoundingMode.HALF_UP);
        }

        return new Mig_FreeeInvoiceLineWork__c(
            InvoiceWork__c = workId,
            ExternalKey__c = buildInvoiceLineExternalKey(companyId, freeeInvoiceId, freeeLineId),
            FreeeLineId__c = freeeLineId,
            Description__c = firstString(lineMap, new List<String>{'description', 'name', 'item_name'}),
            Quantity__c = quantity,
            UnitPrice__c = unitPrice,
            LineAmount__c = lineAmount,
            TaxRate__c = taxRate,
            TaxAmount__c = taxAmount,
            RawJson__c = left(JSON.serialize(lineMap), 131072),
            ProductResolveStatus__c = PRODUCT_STATUS_NEEDS_REVIEW,
            ImportStatus__c = STATUS_FETCHED
        );
    }

    public static String buildInvoiceExternalKey(Long companyId, String freeeInvoiceId) {
        return 'freee_invoice:' + String.valueOf(companyId) + ':' + freeeInvoiceId;
    }

    public static String buildInvoiceLineExternalKey(Long companyId, String freeeInvoiceId, String freeeLineId) {
        return 'freee_invoice_line:' + String.valueOf(companyId) + ':' + freeeInvoiceId + ':' + freeeLineId;
    }

    public static List<String> extractInvoiceIds(String body) {
        List<String> invoiceIds = new List<String>();
        for (Object invoiceObject : extractInvoiceObjects(body)) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            String freeeInvoiceId = firstString((Map<String, Object>) invoiceObject, new List<String>{'id', 'invoice_id'});
            if (!String.isBlank(freeeInvoiceId)) {
                invoiceIds.add(freeeInvoiceId);
            }
        }
        return invoiceIds;
    }

    private static List<Object> extractInvoiceObjects(String body) {
        if (String.isBlank(body)) {
            return new List<Object>();
        }
        Object parsed = JSON.deserializeUntyped(body);
        if (parsed instanceof List<Object>) {
            return (List<Object>) parsed;
        }
        if (!(parsed instanceof Map<String, Object>)) {
            return new List<Object>();
        }
        Map<String, Object> root = (Map<String, Object>) parsed;
        for (String key : new List<String>{'invoices', 'data', 'records'}) {
            Object value = root.get(key);
            if (value instanceof List<Object>) {
                return (List<Object>) value;
            }
        }
        Object invoiceObject = root.get('invoice');
        if (invoiceObject instanceof Map<String, Object>) {
            return new List<Object>{invoiceObject};
        }
        return new List<Object>();
    }

    private static List<Object> extractLineObjects(Map<String, Object> invoiceMap) {
        for (String key : new List<String>{'invoice_lines', 'lines', 'items'}) {
            Object value = invoiceMap.get(key);
            if (value instanceof List<Object>) {
                return (List<Object>) value;
            }
        }
        return new List<Object>();
    }

    public static String firstString(Map<String, Object> source, List<String> keys) {
        if (source == null) {
            return null;
        }
        for (String key : keys) {
            Object value = source.get(key);
            if (value != null && !String.isBlank(String.valueOf(value))) {
                return String.valueOf(value);
            }
        }
        return null;
    }

    public static Decimal firstDecimal(Map<String, Object> source, List<String> keys) {
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

    public static Date firstDate(Map<String, Object> source, List<String> keys) {
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

    public static String mapSendStatus(String sourceStatus) {
        if (String.isBlank(sourceStatus)) {
            return null;
        }
        String normalized = sourceStatus.trim().toLowerCase();
        if (sourceStatus == SEND_DONE || normalized == 'sent' || normalized == 'sending' || normalized == 'delivered' || normalized == 'submitted') {
            return SEND_DONE;
        }
        if (sourceStatus == SEND_WAITING || normalized == 'unsent' || normalized == 'not_sent' || normalized == 'waiting' || normalized == 'draft') {
            return SEND_WAITING;
        }
        return sourceStatus;
    }

    public static String mapPaymentStatus(String sourceStatus) {
        if (String.isBlank(sourceStatus)) {
            return null;
        }
        String normalized = sourceStatus.trim().toLowerCase();
        if (sourceStatus == PAYMENT_DONE || normalized == 'paid' || normalized == 'settled' || normalized == 'completed') {
            return PAYMENT_DONE;
        }
        if (sourceStatus == PAYMENT_WAITING || normalized == 'unpaid' || normalized == 'waiting' || normalized == 'unsettled') {
            return PAYMENT_WAITING;
        }
        return sourceStatus;
    }

    public static Decimal toDecimal(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value);
        } catch (Exception e) {
            return null;
        }
    }

    public static String normalize(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.trim().toLowerCase().replaceAll('[\\s　_\\-・･]+', '');
    }

    public static String left(String value, Integer maxLength) {
        if (value == null || maxLength == null || value.length() <= maxLength) {
            return value;
        }
        return value.left(maxLength);
    }

    public class Mig_FreeeInvoiceMigrationException extends Exception {}
}
