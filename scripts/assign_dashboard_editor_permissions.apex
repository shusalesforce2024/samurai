PermissionSet dashboardEditor = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'SAMURAI_Public_Dashboard_Editor'
    LIMIT 1
];

Set<Id> assignedUserIds = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT AssigneeId
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :dashboardEditor.Id
]) {
    assignedUserIds.add(assignment.AssigneeId);
}

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (User targetUser : [
    SELECT Id, Name, Username
    FROM User
    WHERE IsActive = true
      AND UserType = 'Standard'
      AND Profile.UserLicense.Name = 'Salesforce Platform'
]) {
    if (!assignedUserIds.contains(targetUser.Id)) {
        assignments.add(new PermissionSetAssignment(
            AssigneeId = targetUser.Id,
            PermissionSetId = dashboardEditor.Id
        ));
    }
}

Database.SaveResult[] results = Database.insert(assignments, false);
Integer succeeded = 0;
Integer failed = 0;
for (Database.SaveResult result : results) {
    if (result.isSuccess()) {
        succeeded++;
    } else {
        failed++;
        for (Database.Error error : result.getErrors()) {
            System.debug(LoggingLevel.ERROR, error.getStatusCode() + ': ' + error.getMessage());
        }
    }
}
System.debug('Dashboard editor assignments: succeeded=' + succeeded + ', failed=' + failed);
