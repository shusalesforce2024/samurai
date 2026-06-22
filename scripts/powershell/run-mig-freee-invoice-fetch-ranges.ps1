param(
    [string]$OrgAlias = "prod",
    [int]$SleepSeconds = 70,
    [string]$StartDate = "2026-03-01",
    [string]$EndDate = "2026-06-30",
    [int]$MaxEstimatedCalloutsPerWindow = 15,
    [switch]$InitialSleep
)

$ErrorActionPreference = "Stop"

$workspace = (Get-Location).Path
$tempDir = Join-Path $workspace "docs\SamuraiData\load\prod\tmp"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
$apexFile = Join-Path $tempDir "mig-freee-invoice-fetch-range.apex"

$ranges = New-Object System.Collections.Generic.List[object]
$currentDate = [datetime]::ParseExact($StartDate, "yyyy-MM-dd", $null)
$lastDate = [datetime]::ParseExact($EndDate, "yyyy-MM-dd", $null)
while ($currentDate -le $lastDate) {
    $dateText = $currentDate.ToString("yyyy-MM-dd")
    $ranges.Add(@($dateText, $dateText))
    $currentDate = $currentDate.AddDays(1)
}

function Convert-ToApexDate([string]$dateText) {
    $date = [datetime]::ParseExact($dateText, "yyyy-MM-dd", $null)
    return "Date.newInstance($($date.Year), $($date.Month), $($date.Day))"
}

function Invoke-SfJson([string[]]$Arguments) {
    $output = & sf @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "sf command failed: sf $($Arguments -join ' ')`n$output"
    }
    return ($output | ConvertFrom-Json)
}

function Get-LatestFetchJob() {
    $query = "SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE ApexClass.Name = 'Mig_FreeeInvoiceFetchBatch' ORDER BY CreatedDate DESC LIMIT 1"
    $result = Invoke-SfJson @("data", "query", "--target-org", $OrgAlias, "--query", $query, "--json")
    return $result.result.records[0]
}

function Get-WorkCountByBillingDate([string]$dateText) {
    $query = "SELECT COUNT(Id) cnt FROM Mig_FreeeInvoiceWork__c WHERE BillingDate__c = $dateText"
    $result = Invoke-SfJson @("data", "query", "--target-org", $OrgAlias, "--query", $query, "--json")
    if ($result.result.records.Count -eq 0) {
        return 0
    }
    return [int]$result.result.records[0].cnt
}

if ($InitialSleep) {
    Write-Host "Initial wait $SleepSeconds seconds for freee API rate limit..."
    Start-Sleep -Seconds $SleepSeconds
}

$total = $ranges.Count
$index = 0
$estimatedCalloutsInWindow = 0
foreach ($range in $ranges) {
    $index++
    $startDate = $range[0]
    $endDate = $range[1]
    $startApex = Convert-ToApexDate $startDate
    $endApex = Convert-ToApexDate $endDate

    $apexBody = @"
Database.executeBatch(new Mig_FreeeInvoiceFetchBatch($startApex, $endApex), 1);
"@
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($apexFile, $apexBody, $utf8NoBom)

    Write-Host "[$index/$total] Fetching freee invoices: $startDate - $endDate"
    & sf apex run --target-org $OrgAlias --file $apexFile | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to enqueue range $startDate - $endDate"
    }

    $job = Get-LatestFetchJob
    Write-Host "  Job: $($job.Id)"
    do {
        Start-Sleep -Seconds 10
        $query = "SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = '$($job.Id)'"
        $result = Invoke-SfJson @("data", "query", "--target-org", $OrgAlias, "--query", $query, "--json")
        $job = $result.result.records[0]
        Write-Host "  Status=$($job.Status) Progress=$($job.JobItemsProcessed)/$($job.TotalJobItems) Errors=$($job.NumberOfErrors)"
    } while ($job.Status -eq "Queued" -or $job.Status -eq "Preparing" -or $job.Status -eq "Processing")

    if ($job.Status -ne "Completed" -or [int]$job.NumberOfErrors -gt 0) {
        throw "Fetch range failed: $startDate - $endDate status=$($job.Status) errors=$($job.NumberOfErrors) extended=$($job.ExtendedStatus)"
    }

    $workCountForDay = Get-WorkCountByBillingDate $startDate
    $estimatedCallouts = 1 + $workCountForDay
    $estimatedCalloutsInWindow += $estimatedCallouts
    Write-Host "  Estimated callouts for day=$estimatedCallouts, window=$estimatedCalloutsInWindow/$MaxEstimatedCalloutsPerWindow"

    if ($index -lt $total -and $estimatedCalloutsInWindow -ge $MaxEstimatedCalloutsPerWindow) {
        Write-Host "  Waiting $SleepSeconds seconds for freee API rate limit..."
        Start-Sleep -Seconds $SleepSeconds
        $estimatedCalloutsInWindow = 0
    }
}

Write-Host "Completed all freee invoice fetch ranges."
