Id defaultUserId = '005RB00000eIlkbYAC';

User defaultUser = [
    SELECT Id, IsActive, Name
    FROM User
    WHERE Id = :defaultUserId
    LIMIT 1
];

if (!defaultUser.IsActive) {
    throw new AuraHandledException('デフォルト自社担当者ユーザが無効です: ' + defaultUser.Name);
}

List<Invoice__c> invoices = [
    SELECT Id, CompanyContactUser__c
    FROM Invoice__c
    WHERE CompanyContactUser__c = null
    LIMIT 10000
];

for (Invoice__c invoice : invoices) {
    invoice.CompanyContactUser__c = defaultUserId;
}

update invoices;

System.debug('updated=' + invoices.size() + ', defaultUser=' + defaultUser.Name);
