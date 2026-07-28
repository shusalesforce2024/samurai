Integer expectedRecordCount = 1656;
Integer expectedFieldUpdateCount = 1798;

List<ContractLineItem__c> targets = [
    SELECT Id,
           ContractYearMonth__c,
           Month__c,
           PeriodStartDate__c,
           PeriodEndDate__c
    FROM ContractLineItem__c
    WHERE ContractYearMonth__c = null
       OR Month__c = null
       OR PeriodStartDate__c = null
       OR PeriodEndDate__c = null
    ORDER BY Id
];

if (targets.size() != expectedRecordCount) {
    throw new AuraHandledException(
        '更新対象件数が事前確認と一致しません。expected='
        + expectedRecordCount
        + ', actual='
        + targets.size()
    );
}

Integer fieldUpdateCount = 0;
for (ContractLineItem__c target : targets) {
    if (target.PeriodStartDate__c == null) {
        throw new AuraHandledException(
            '対象期間開始日が空のため年月を算出できません。Id=' + target.Id
        );
    }

    Date startDate = target.PeriodStartDate__c;
    String monthText = startDate.month() < 10
        ? '0' + String.valueOf(startDate.month())
        : String.valueOf(startDate.month());
    String yearMonth = String.valueOf(startDate.year()) + '/' + monthText;

    if (String.isBlank(target.ContractYearMonth__c)) {
        target.ContractYearMonth__c = yearMonth;
        fieldUpdateCount++;
    }
    if (String.isBlank(target.Month__c)) {
        target.Month__c = yearMonth;
        fieldUpdateCount++;
    }
    if (target.PeriodEndDate__c == null) {
        target.PeriodEndDate__c = startDate.toStartOfMonth().addMonths(1).addDays(-1);
        fieldUpdateCount++;
    }
}

if (fieldUpdateCount != expectedFieldUpdateCount) {
    throw new AuraHandledException(
        '補完項目数が事前確認と一致しません。expected='
        + expectedFieldUpdateCount
        + ', actual='
        + fieldUpdateCount
    );
}

Database.SaveResult[] results = Database.update(targets, false);
Integer successCount = 0;
List<String> errors = new List<String>();
for (Integer i = 0; i < results.size(); i++) {
    if (results[i].isSuccess()) {
        successCount++;
        continue;
    }
    for (Database.Error error : results[i].getErrors()) {
        if (errors.size() < 20) {
            errors.add(targets[i].Id + ': ' + error.getMessage());
        }
    }
}

if (successCount != expectedRecordCount || !errors.isEmpty()) {
    System.debug(LoggingLevel.ERROR, 'CONTRACT_LINE_DATE_ERRORS=' + errors);
    throw new AuraHandledException(
        '契約月次明細の補完に失敗しました。success='
        + successCount
        + ', errors='
        + errors.size()
    );
}

Integer remainingBlankCount = [
    SELECT COUNT()
    FROM ContractLineItem__c
    WHERE ContractYearMonth__c = null
       OR Month__c = null
       OR PeriodStartDate__c = null
       OR PeriodEndDate__c = null
];
if (remainingBlankCount != 0) {
    throw new AuraHandledException(
        '補完後も空欄が残っています。remaining=' + remainingBlankCount
    );
}

System.debug(LoggingLevel.ERROR, 'CONTRACT_LINE_DATE_RECORDS_UPDATED=' + successCount);
System.debug(LoggingLevel.ERROR, 'CONTRACT_LINE_DATE_FIELDS_UPDATED=' + fieldUpdateCount);
System.debug(LoggingLevel.ERROR, 'CONTRACT_LINE_DATE_REMAINING_BLANK=' + remainingBlankCount);
