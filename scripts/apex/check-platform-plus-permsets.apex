Savepoint sp = Database.setSavepoint();

try {
    Profile platformProfile = [
        SELECT Id
        FROM Profile
        WHERE UserLicense.Name = 'Salesforce Platform'
        LIMIT 1
    ];

    Long stamp = DateTime.now().getTime();
    User platformUser = new User(
        Alias = 'pfchk',
        Email = 'platform-permset-check+' + stamp + '@example.com',
        EmailEncodingKey = 'UTF-8',
        LastName = 'PlatformPermissionCheck',
        LanguageLocaleKey = 'ja',
        LocaleSidKey = 'ja_JP',
        ProfileId = platformProfile.Id,
        TimeZoneSidKey = 'Asia/Tokyo',
        UserPermissionsSFContentUser = false,
        Username = 'platform-permset-check+' + stamp + '@example.com'
    );
    insert platformUser;

    List<PermissionSet> permissionSets = [
        SELECT Id, Name, Label
        FROM PermissionSet
        WHERE Name IN ('SAMURAI_Sales_Contract_User', 'SAMURAI_Contract_Billing_User')
        ORDER BY Name
    ];

    for (PermissionSet ps : permissionSets) {
        try {
            insert new PermissionSetAssignment(
                AssigneeId = platformUser.Id,
                PermissionSetId = ps.Id
            );
            System.debug('ASSIGN_OK: ' + ps.Name + ' / ' + ps.Label);
        } catch (Exception e) {
            System.debug('ASSIGN_NG: ' + ps.Name + ' / ' + ps.Label + ' / ' + e.getMessage());
        }
    }
} finally {
    Database.rollback(sp);
    System.debug('ROLLBACK_DONE: no test user or assignment remains.');
}
