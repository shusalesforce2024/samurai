Profile platformProfile = [
    SELECT Id
    FROM Profile
    WHERE Name = '標準 Platform ユーザー'
    LIMIT 1
];

String username = 'dashboard.editor.test.' + DateTime.now().getTime() + '@samurai.example';
User testUser = new User(
    Alias = 'dbtest',
    Email = 'dashboard.editor.test@samurai.example',
    EmailEncodingKey = 'UTF-8',
    LastName = 'ダッシュボード編集テスト',
    LanguageLocaleKey = 'ja',
    LocaleSidKey = 'ja_JP',
    ProfileId = platformProfile.Id,
    TimeZoneSidKey = 'Asia/Tokyo',
    UserPermissionsSFContentUser = false,
    UserPermissionsKnowledgeUser = false,
    UserPermissionsMarketingUser = false,
    Username = username
);
insert testUser;
System.debug('DASHBOARD_TEST_USER_ID=' + testUser.Id);
System.debug('DASHBOARD_TEST_USERNAME=' + username);
