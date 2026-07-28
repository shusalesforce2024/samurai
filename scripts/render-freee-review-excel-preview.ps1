param(
    [string]$WorkbookPath = "outputs/freee-review-20260724/freee請求移行Work_要確認表_20260724.xlsx",
    [string]$OutputDirectory = "outputs/freee-review-20260724/previews"
)

$ErrorActionPreference = "Stop"

function Release-ComObject($object) {
    if ($null -ne $object) {
        [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($object)
    }
}

$resolvedWorkbook = (Resolve-Path $WorkbookPath).Path
$resolvedOutput = [IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
New-Item -ItemType Directory -Path $resolvedOutput -Force | Out-Null

$targets = @(
    @{ Sheet = "サマリー"; Range = "A1:H15"; File = "01_summary.png" },
    @{ Sheet = "レコード別確認"; Range = "A1:N12"; File = "02_records_core.png" },
    @{ Sheet = "レコード別確認"; Range = "O1:U12"; File = "03_records_status.png" },
    @{ Sheet = "共通質問"; Range = "A1:D10"; File = "04_questions.png" },
    @{ Sheet = "対応履歴"; Range = "A1:E13"; File = "05_history.png" }
)

$excel = $null
$workbook = $null
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $true
    $excel.WindowState = 2
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $true
    $workbook = $excel.Workbooks.Open($resolvedWorkbook, 0, $true)

    foreach ($target in $targets) {
        $sheet = $workbook.Worksheets.Item($target.Sheet)
        $sheet.Activate()
        $range = $sheet.Range($target.Range)
        $range.Select()
        $range.CopyPicture(1, 2)
        Start-Sleep -Milliseconds 400
        $chartObject = $sheet.ChartObjects().Add(0, 0, $range.Width, $range.Height)
        $chartObject.Activate()
        $chartObject.Chart.Paste()
        Start-Sleep -Milliseconds 400
        $path = Join-Path $resolvedOutput $target.File
        if (-not $chartObject.Chart.Export($path, "PNG")) {
            throw "プレビュー画像を出力できませんでした: $path"
        }
        $chartObject.Delete()
        Write-Output $path
        Release-ComObject $chartObject
        Release-ComObject $range
        Release-ComObject $sheet
    }
}
finally {
    if ($null -ne $workbook) {
        try { $workbook.Close($false) } catch {}
    }
    if ($null -ne $excel) {
        try { $excel.Quit() } catch {}
    }
    Release-ComObject $workbook
    Release-ComObject $excel
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
