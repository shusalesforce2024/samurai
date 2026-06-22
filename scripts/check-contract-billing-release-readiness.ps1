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

function Add-ScheduleCheck {
    param(
        [System.Collections.Generic.List[object]]$Results,
        [string]$CheckName,
        [string]$NameLike,
        [string]$ExpectedCron
    )

    $records = Invoke-SfQuery -Query "SELECT CronJobDetail.Name, State, CronExpression FROM CronTrigger WHERE CronJobDetail.Name LIKE '$NameLike'"
    $matched = @($records | Where-Object { $_.State -eq "WAITING" -and $_.CronExpression -eq $ExpectedCron })
    if ($matched.Count -eq 0) {
        $detail = if (@($records).Count -eq 0) {
            "No schedule found"
        } else {
            (@($records) | ForEach-Object { "$($_.CronJobDetail.Name) / $($_.State) / $($_.CronExpression)" }) -join "; "
        }
        $Results.Add((Add-Result "Schedule" $CheckName "NG" $detail))
    } else {
        $detail = ($matched | ForEach-Object { "$($_.CronJobDetail.Name) / $($_.State) / $($_.CronExpression)" }) -join "; "
        $Results.Add((Add-Result "Schedule" $CheckName "OK" $detail))
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
    "ContractMonthlyLineBatch",
    "FreeeInvoiceImportScheduler",
    "FreeeInvoiceImportService",
    "FreeeInvoiceCreateQueueable",
    "FreeeInvoiceStatusSyncBatch",
    "InvoiceCancelService",
    "InvoiceRecreateService",
    "FreeeInvoiceCancelService"
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

Add-ScheduleCheck $results "ContractMonthlyLineBatch" "ContractMonthlyLineBatch%" "0 30 1 11 * ?"
Add-ScheduleCheck $results "FreeeInvoiceImportScheduler" "FreeeInvoiceImportScheduler%" "0 30 2 * * ?"
Add-ScheduleCheck $results "FreeeInvoiceStatusSyncBatch" "FreeeInvoiceStatusSyncBatch" "0 0 3 * * ?"

$renewalSchedules = Invoke-SfQuery -Query "SELECT CronJobDetail.Name, State, CronExpression FROM CronTrigger WHERE CronJobDetail.Name LIKE 'ContractRenewalInvoiceBatch%'"
if (@($renewalSchedules).Count -gt 0) {
    $detail = ($renewalSchedules | ForEach-Object { "$($_.CronJobDetail.Name) / $($_.State) / $($_.CronExpression)" }) -join "; "
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch disabled" "NG" "ContractRenewalInvoiceBatch must not be scheduled. Found: $detail"))
} else {
    $results.Add((Add-Result "Schedule" "ContractRenewalInvoiceBatch disabled" "OK" "No ContractRenewalInvoiceBatch schedule"))
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
