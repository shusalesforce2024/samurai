param(
    [string]$OrgAlias = "dev1"
)

$ErrorActionPreference = "Stop"

function Invoke-SfQuery {
    param(
        [string]$Query,
        [switch]$Tooling
    )

    $args = @("data", "query", "--target-org", $OrgAlias, "--query", $Query, "--result-format", "json")
    if ($Tooling) {
        $args += "--use-tooling-api"
    }

    $json = sf @args | ConvertFrom-Json
    return $json.result.records
}

function Add-Result {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,
        [string]$Detail
    )

    [PSCustomObject]@{
        Category = $Category
        Check    = $Check
        Status   = $Status
        Detail   = $Detail
    }
}

$results = New-Object System.Collections.Generic.List[object]

$requiredPermissionSets = @(
    "SAMURAI_Sales_Contract_User",
    "SAMURAI_Contract_Billing_User",
    "SAMURAI_System_Admin"
)

$requiredApexClasses = @(
    "OppContractInvoiceService",
    "ContractRenewalInvoiceBatch",
    "FreeeInvoiceCreateQueueable",
    "FreeeInvoiceStatusSyncBatch",
    "InvoiceCancelService",
    "InvoiceRecreateService",
    "FreeeInvoiceCancelService"
)

$requiredExactSchedules = @(
    "FreeeInvoiceStatusSyncBatch"
)

$permissionSets = Invoke-SfQuery -Query ("SELECT Name FROM PermissionSet WHERE Name IN ('" + ($requiredPermissionSets -join "','") + "')")
$permissionSetNames = @($permissionSets | ForEach-Object { $_.Name })
foreach ($name in $requiredPermissionSets) {
    $status = if ($permissionSetNames -contains $name) { "OK" } else { "NG" }
    $results.Add((Add-Result "PermissionSet" $name $status "Required permission set"))
}

$apexClasses = Invoke-SfQuery -Tooling -Query ("SELECT Name FROM ApexClass WHERE Name IN ('" + ($requiredApexClasses -join "','") + "')")
$apexClassNames = @($apexClasses | ForEach-Object { $_.Name })
foreach ($name in $requiredApexClasses) {
    $status = if ($apexClassNames -contains $name) { "OK" } else { "NG" }
    $results.Add((Add-Result "ApexClass" $name $status "Required Apex class"))
}

$exactSchedules = Invoke-SfQuery -Query ("SELECT CronJobDetail.Name, State, CronExpression FROM CronTrigger WHERE CronJobDetail.Name IN ('" + ($requiredExactSchedules -join "','") + "')")
$exactScheduleNames = @($exactSchedules | ForEach-Object { $_.CronJobDetail.Name })
foreach ($name in $requiredExactSchedules) {
    $matched = @($exactSchedules | Where-Object { $_.CronJobDetail.Name -eq $name })
    if ($matched.Count -eq 0) {
        $results.Add((Add-Result "Schedule" $name "NG" "Schedule is not registered"))
    } else {
        $detail = ($matched | ForEach-Object { "$($_.State) / $($_.CronExpression)" }) -join "; "
        $results.Add((Add-Result "Schedule" $name "OK" $detail))
    }
}

$renewalSchedules = Invoke-SfQuery -Query "SELECT CronJobDetail.Name, State, CronExpression FROM CronTrigger WHERE CronJobDetail.Name LIKE 'ContractRenewalInvoiceBatch_%'"
if (@($renewalSchedules).Count -eq 0) {
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch monthly" "NG" "Monthly renewal schedule is not registered"))
} else {
    $detail = ($renewalSchedules | ForEach-Object { "$($_.CronJobDetail.Name) / $($_.State) / $($_.CronExpression)" }) -join "; "
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch monthly" "OK" $detail))
}

$duplicateRenewalSchedules = Invoke-SfQuery -Query "SELECT CronJobDetail.Name, State, CronExpression FROM CronTrigger WHERE CronJobDetail.Name = 'ContractRenewalInvoiceBatch'"
if (@($duplicateRenewalSchedules).Count -gt 0) {
    $detail = ($duplicateRenewalSchedules | ForEach-Object { "$($_.State) / $($_.CronExpression)" }) -join "; "
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch duplicate" "WARN" $detail))
} else {
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch duplicate" "OK" "No duplicate daily renewal schedule"))
}

$productMasters = Invoke-SfQuery -Query "SELECT Id FROM ProductMaster__c LIMIT 1"
$productStatus = if (@($productMasters).Count -gt 0) { "OK" } else { "WARN" }
$results.Add((Add-Result "Data" "ProductMaster__c" $productStatus "Product master records are required before UAT/production operation"))

$freeeConfigs = Invoke-SfQuery -Query "SELECT Id FROM Freee_Configs__c LIMIT 1"
$freeeConfigStatus = if (@($freeeConfigs).Count -gt 0) { "OK" } else { "WARN" }
$results.Add((Add-Result "Data" "Freee_Configs__c" $freeeConfigStatus "Freee runtime settings are required before integration"))

$results | Format-Table -AutoSize

$ngCount = @($results | Where-Object { $_.Status -eq "NG" }).Count
if ($ngCount -gt 0) {
    throw "Release readiness check failed. NG count: $ngCount"
}
