public with sharing class Mig_FreeeInvoiceFetchService {
    public static final Integer DEFAULT_PER_PAGE = 10;
    public static final Integer MAX_THROTTLED_PER_PAGE = 10;

    public class FetchPageResult {
        public Date targetDate;
        public Integer page;
        public Integer perPage;
        public Integer invoiceCount;
        public Integer importedHeaderCount;
        public Integer importedLineCount;

        public FetchPageResult(
            Date targetDate,
            Integer page,
            Integer perPage,
            Integer invoiceCount,
            Integer importedHeaderCount,
            Integer importedLineCount
        ) {
            this.targetDate = targetDate;
            this.page = page;
            this.perPage = perPage;
            this.invoiceCount = invoiceCount;
            this.importedHeaderCount = importedHeaderCount;
            this.importedLineCount = importedLineCount;
        }
    }

    public static FetchPageResult fetchDate(Date targetDate, Integer perPage) {
        if (targetDate == null) {
            throw new IllegalArgumentException('targetDate is required.');
        }
        Integer safePerPage = perPage == null || perPage < 1 ? DEFAULT_PER_PAGE : perPage;

        Integer page = 1;
        Integer invoiceCount = 0;
        List<String> detailBodies = new List<String>();
        while (true) {
            if (Limits.getCallouts() + safePerPage + 1 > Limits.getLimitCallouts()) {
                throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException(
                    'freee invoice fetch stopped before DML because callout limit would be exceeded. targetDate=' +
                    String.valueOf(targetDate) + ', page=' + String.valueOf(page)
                );
            }

            HttpResponse response = FreeeInvoiceService.getInvoices(targetDate, targetDate, page, safePerPage);
            assertSuccessfulResponse(response, 'freee invoice list fetch failed.');

            List<String> invoiceIds = extractInvoiceIdsInPeriod(response.getBody(), targetDate, targetDate);
            invoiceCount += invoiceIds.size();
            detailBodies.addAll(fetchDetailBodiesByIds(invoiceIds));
            if (invoiceIds.size() < safePerPage) {
                break;
            }
            page++;
        }

        Integer importedHeaderCount = 0;
        Integer importedLineCount = 0;
        for (String detailBody : detailBodies) {
            Mig_FreeeInvoiceWorkService.ImportResult detailResult = Mig_FreeeInvoiceWorkService.importBody(detailBody);
            importedHeaderCount += detailResult.headerCount;
            importedLineCount += detailResult.lineCount;
            if (detailResult.headerCount > 0) {
                deleteOutOfPeriodWorks(detailBody, targetDate, targetDate);
            }
        }

        return new FetchPageResult(
            targetDate,
            1,
            safePerPage,
            invoiceCount,
            importedHeaderCount,
            importedLineCount
        );
    }

    public static FetchPageResult fetchPage(Date targetDate, Integer page, Integer perPage) {
        if (targetDate == null) {
            throw new IllegalArgumentException('targetDate is required.');
        }
        Integer safePage = page == null || page < 1 ? 1 : page;
        Integer safePerPage = perPage == null || perPage < 1 ? DEFAULT_PER_PAGE : perPage;

        HttpResponse response = FreeeInvoiceService.getInvoices(targetDate, targetDate, safePage, safePerPage);
        assertSuccessfulResponse(response, 'freee invoice list fetch failed.');

        List<String> detailBodies = fetchDetailBodies(response.getBody(), targetDate, targetDate);
        Integer importedHeaderCount = 0;
        Integer importedLineCount = 0;
        for (String detailBody : detailBodies) {
            Mig_FreeeInvoiceWorkService.ImportResult detailResult = Mig_FreeeInvoiceWorkService.importBody(detailBody);
            importedHeaderCount += detailResult.headerCount;
            importedLineCount += detailResult.lineCount;
            if (detailResult.headerCount > 0) {
                deleteOutOfPeriodWorks(detailBody, targetDate, targetDate);
            }
        }

        return new FetchPageResult(
            targetDate,
            safePage,
            safePerPage,
            detailBodies.size(),
            importedHeaderCount,
            importedLineCount
        );
    }

    public static Integer normalizeThrottledPerPage(Integer perPage) {
        if (perPage == null || perPage < 1) {
            return MAX_THROTTLED_PER_PAGE;
        }
        return Math.min(perPage, MAX_THROTTLED_PER_PAGE);
    }

    public static void runResolversAndValidation() {
        Mig_FreeeInvoiceReferenceResolver.resolveAll();
        Mig_FreeeInvoiceProductResolver.resolveAll();
        Mig_FreeeInvoiceValidator.validateAll();
    }

    private static List<String> fetchDetailBodies(String listResponseBody, Date startDate, Date endDate) {
        return fetchDetailBodiesByIds(extractInvoiceIdsInPeriod(listResponseBody, startDate, endDate));
    }

    private static List<String> fetchDetailBodiesByIds(List<String> freeeInvoiceIds) {
        List<String> detailBodies = new List<String>();
        for (String freeeInvoiceId : freeeInvoiceIds) {
            Decimal invoiceId = Mig_FreeeInvoiceWorkService.toDecimal(freeeInvoiceId);
            if (invoiceId == null) {
                continue;
            }
            HttpResponse detailResponse = FreeeInvoiceService.getInvoice(invoiceId);
            assertSuccessfulResponse(
                detailResponse,
                'freee invoice detail fetch failed. invoiceId=' + freeeInvoiceId
            );
            detailBodies.add(detailResponse.getBody());
        }
        return detailBodies;
    }

    private static void assertSuccessfulResponse(HttpResponse response, String messagePrefix) {
        if (response == null) {
            throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException(messagePrefix + ' response is null.');
        }
        if (response.getStatusCode() == 429) {
            FreeeRateLimitException rateLimitException = new FreeeRateLimitException(
                messagePrefix + ' status=429, body=' + Mig_FreeeInvoiceWorkService.left(response.getBody(), 32000)
            );
            rateLimitException.retryAfterMinutes = calculateRateLimitRetryMinutes(response.getBody());
            throw rateLimitException;
        }
        if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
            throw new Mig_FreeeInvoiceWorkService.Mig_FreeeInvoiceMigrationException(
                messagePrefix + ' status=' + response.getStatusCode() +
                ', body=' + Mig_FreeeInvoiceWorkService.left(response.getBody(), 32000)
            );
        }
    }

    private static List<String> extractInvoiceIdsInPeriod(String body, Date startDate, Date endDate) {
        List<String> invoiceIds = new List<String>();
        for (Object invoiceObject : extractInvoiceObjects(body)) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
            Date billingDate = Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            );
            if (!isInPeriod(billingDate, startDate, endDate)) {
                continue;
            }
            String freeeInvoiceId = Mig_FreeeInvoiceWorkService.firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            if (!String.isBlank(freeeInvoiceId)) {
                invoiceIds.add(freeeInvoiceId);
            }
        }
        return invoiceIds;
    }

    private static void deleteOutOfPeriodWorks(String detailBody, Date startDate, Date endDate) {
        Set<String> outOfPeriodKeys = new Set<String>();
        FreeeConfigService.Config config = FreeeConfigService.getConfig();
        for (Object invoiceObject : extractInvoiceObjects(detailBody)) {
            if (!(invoiceObject instanceof Map<String, Object>)) {
                continue;
            }
            Map<String, Object> invoiceMap = (Map<String, Object>) invoiceObject;
            Date billingDate = Mig_FreeeInvoiceWorkService.firstDate(
                invoiceMap,
                new List<String>{'issue_date', 'invoice_date', 'billing_date', 'date'}
            );
            if (isInPeriod(billingDate, startDate, endDate)) {
                continue;
            }
            String freeeInvoiceId = Mig_FreeeInvoiceWorkService.firstString(invoiceMap, new List<String>{'id', 'invoice_id'});
            if (!String.isBlank(freeeInvoiceId)) {
                outOfPeriodKeys.add(Mig_FreeeInvoiceWorkService.buildInvoiceExternalKey(config.companyId, freeeInvoiceId));
            }
        }
        if (outOfPeriodKeys.isEmpty()) {
            return;
        }
        delete [
            SELECT Id
            FROM Mig_FreeeInvoiceWork__c
            WHERE ExternalKey__c IN :outOfPeriodKeys
        ];
    }

    private static Boolean isInPeriod(Date billingDate, Date startDate, Date endDate) {
        return billingDate != null && billingDate >= startDate && billingDate <= endDate;
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
            Integer period = meta.get('period') == null ? null : Integer.valueOf(String.valueOf(meta.get('period')));
            String resetValue = meta.get('reset') == null ? null : String.valueOf(meta.get('reset'));
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
            System.debug('Failed to parse freee rate limit response: ' + e.getMessage());
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
            System.debug('Failed to parse freee rate limit reset value: ' + e.getMessage());
            return null;
        }
    }

    public class FreeeRateLimitException extends Exception {
        public Integer retryAfterMinutes;
    }
}
