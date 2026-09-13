Id contractId = 'a04RB00000kUAPzYAO';

List<ContractLineItem__c> lines = [
    SELECT Id, MasterContract__c, ContractPeriod__c,
           PeriodStartDate__c, PeriodEndDate__c
    FROM ContractLineItem__c
    WHERE Id IN (
        'a03RB00001NswrEYAR', 'a03RB00001NswrFYAR',
        'a03RB00001NswrGYAR', 'a03RB00001NswrHYAR',
        'a03RB00001NswrIYAR', 'a03RB00001NswrJYAR',
        'a03RB00001NswrKYAR', 'a03RB00001NswrLYAR',
        'a03RB00001NswrMYAR', 'a03RB00001NswrNYAR',
        'a03RB00001RcABeYAN', 'a03RB00001STmHqYAL'
    )
    FOR UPDATE
];

Set<Date> targetStarts = new Set<Date>();
for (ContractLineItem__c line : lines) {
    if (line.MasterContract__c != contractId || line.ContractPeriod__c != null ||
        line.PeriodStartDate__c == null || line.PeriodEndDate__c == null) {
        throw new IllegalArgumentException('月次明細の前提条件が変わっています: ' + line.Id);
    }
    targetStarts.add(line.PeriodStartDate__c);
}
if (lines.size() != 12 || targetStarts.size() != 12) {
    throw new IllegalArgumentException('対象件数または対象月が想定と異なります');
}

List<ContractPeriod__c> overlaps = [
    SELECT Id, PeriodStartDate__c, PeriodEndDate__c
    FROM ContractPeriod__c
    WHERE Contract__c = :contractId
      AND PeriodStartDate__c <= :Date.newInstance(2026, 8, 31)
      AND PeriodEndDate__c >= :Date.newInstance(2025, 7, 1)
];
for (ContractPeriod__c period : overlaps) {
    if (targetStarts.contains(period.PeriodStartDate__c)) {
        throw new IllegalArgumentException('対象月の契約期間が既に存在します: ' + period.Id);
    }
}

List<ContractPeriod__c> periods = new List<ContractPeriod__c>();
for (Date startDate : targetStarts) {
    periods.add(new ContractPeriod__c(
        Contract__c = contractId,
        ContractUpdate__c = '月',
        IsInitialPeriod__c = false,
        PeriodStartDate__c = startDate,
        PeriodEndDate__c = startDate.addMonths(1).addDays(-1)
    ));
}
insert periods;

Map<Date, Id> periodIdByStart = new Map<Date, Id>();
for (ContractPeriod__c period : periods) {
    periodIdByStart.put(period.PeriodStartDate__c, period.Id);
}
for (ContractLineItem__c line : lines) {
    line.ContractPeriod__c = periodIdByStart.get(line.PeriodStartDate__c);
}
update lines;

System.debug('PERIODS_INSERTED=' + periods.size());
System.debug('LINES_UPDATED=' + lines.size());
