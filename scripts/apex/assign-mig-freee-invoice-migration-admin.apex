PermissionSet permissionSetRecord = [
    SELECT Id
    FROM PermissionSet
    WHERE Name = 'Mig_FreeeInvoiceMigrationAdmin'
    LIMIT 1
];

List<PermissionSetAssignment> existingAssignments = [
    SELECT Id
    FROM PermissionSetAssignment
    WHERE PermissionSetId = :permissionSetRecord.Id
      AND AssigneeId = :UserInfo.getUserId()
    LIMIT 1
];

if (existingAssignments.isEmpty()) {
    insert new PermissionSetAssignment(
        PermissionSetId = permissionSetRecord.Id,
        AssigneeId = UserInfo.getUserId()
    );
    System.debug('MIG_PERMISSION_SET_ASSIGNED=true');
} else {
    System.debug('MIG_PERMISSION_SET_ALREADY_ASSIGNED=true');
}
