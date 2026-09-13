Id testUserId = '005dL00001q5dHiQAI';
Set<String> permissionSetNames = new Set<String>{
    'SAMURAI_Fixed_Dashboard_Editor',
    'SAMURAI_System_Admin',
    'SAMURAI_Sales_Contract_User',
    'SAMURAI_Contract_Billing_User'
};

List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
for (PermissionSet permissionSet : [
    SELECT Id
    FROM PermissionSet
    WHERE Name IN :permissionSetNames
]) {
    assignments.add(new PermissionSetAssignment(
        AssigneeId = testUserId,
        PermissionSetId = permissionSet.Id
    ));
}
insert assignments;
System.debug('ASSIGNED_PERMISSION_SETS=' + assignments.size());
