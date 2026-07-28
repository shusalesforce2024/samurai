public inherited sharing class ContractLineItemPeriodService {
    public static void populatePeriodFields(List<ContractLineItem__c> records) {
        if (records == null) {
            return;
        }

        for (ContractLineItem__c record : records) {
            Date startDate = resolveStartDate(record);
            if (startDate == null) {
                continue;
            }

            String yearMonth = formatYearMonth(startDate);
            if (String.isBlank(record.ContractYearMonth__c)) {
                record.ContractYearMonth__c = yearMonth;
            }
            if (String.isBlank(record.Month__c)) {
                record.Month__c = yearMonth;
            }
            if (record.PeriodStartDate__c == null) {
                record.PeriodStartDate__c = startDate.toStartOfMonth();
            }
            if (record.PeriodEndDate__c == null) {
                record.PeriodEndDate__c = startDate.toStartOfMonth().addMonths(1).addDays(-1);
            }
        }
    }

    private static Date resolveStartDate(ContractLineItem__c record) {
        if (record.PeriodStartDate__c != null) {
            return record.PeriodStartDate__c;
        }

        String yearMonth = String.isBlank(record.ContractYearMonth__c)
            ? record.Month__c
            : record.ContractYearMonth__c;
        if (String.isBlank(yearMonth)) {
            record.addError('対象期間開始日、契約年月、対象年月のいずれかを入力してください。');
            return null;
        }

        List<String> parts = yearMonth.split('/');
        if (parts.size() != 2) {
            record.addError('契約年月または対象年月はYYYY/MM形式で入力してください。');
            return null;
        }

        try {
            Integer year = Integer.valueOf(parts[0]);
            Integer month = Integer.valueOf(parts[1]);
            if (parts[0].length() != 4 || month < 1 || month > 12) {
                record.addError('契約年月または対象年月は有効なYYYY/MM形式で入力してください。');
                return null;
            }
            return Date.newInstance(year, month, 1);
        } catch (Exception error) {
            record.addError('契約年月または対象年月は有効なYYYY/MM形式で入力してください。');
            return null;
        }
    }

    private static String formatYearMonth(Date targetDate) {
        String monthText = targetDate.month() < 10
            ? '0' + String.valueOf(targetDate.month())
            : String.valueOf(targetDate.month());
        return String.valueOf(targetDate.year()) + '/' + monthText;
    }
}
