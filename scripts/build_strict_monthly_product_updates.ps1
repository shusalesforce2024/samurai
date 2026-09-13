param([string]$DataDir = "outputs/data-integrity-fix-20260806")

$monthly=@(Import-Csv (Join-Path $DataDir 'monthly-current.csv'))
$lines=@(Import-Csv (Join-Path $DataDir 'invoice-lines-current.csv'))
$products=@(Import-Csv (Join-Path $DataDir 'products-current.csv'))
function Empty($v){[string]::IsNullOrWhiteSpace([string]$v)}
function DateValue($v){if(Empty $v){return $null};[datetime]::ParseExact($v,'yyyy-MM-dd',$null)}
function WriteCsv($path,$headers,$rows){
    $w=[IO.StreamWriter]::new($path,$false,[Text.UTF8Encoding]::new($false))
    try{
        $w.WriteLine($headers-join',')
        foreach($r in $rows){
            $values=@()
            foreach($h in $headers){$values += [string]$r.$h}
            $w.WriteLine($values-join',')
        }
    }finally{$w.Dispose()}
}
$productById=@{};foreach($p in $products){$productById[$p.Id]=$p}
$linesByInvoice=$lines|Where-Object{-not(Empty $_.ProductMaster__c)}|Group-Object Invoice__c -AsHashTable -AsString
$updates=[Collections.Generic.List[object]]::new();$rollback=[Collections.Generic.List[object]]::new();$evidence=[Collections.Generic.List[object]]::new()
foreach($m in $monthly|Where-Object{(Empty $_.ProductMaster__c)-and-not(Empty $_.RelatedInvoice__c)-and-not(Empty $_.Total__c)}){
    if($m.'RelatedInvoice__r.ParentContract__c' -ne $m.MasterContract__c -or $m.'RelatedInvoice__r.Account__c' -ne $m.Account__c -or -not $linesByInvoice.ContainsKey($m.RelatedInvoice__c)){continue}
    $ms=DateValue $m.PeriodStartDate__c;$bd=DateValue $m.'RelatedInvoice__r.Billing_Date__c';if($null-eq$ms-or$null-eq$bd){continue}
    $diff=[math]::Abs((($bd.Year-$ms.Year)*12)+$bd.Month-$ms.Month);if($diff-gt1){continue}
    $matches=@($linesByInvoice[$m.RelatedInvoice__c]|Where-Object{[decimal]$_.Line_Amount__c-eq[decimal]$m.Total__c})
    $productIds=@($matches|Select-Object -ExpandProperty ProductMaster__c -Unique);if($productIds.Count-ne1){continue}
    $p=$productById[$productIds[0]];if($null-eq$p){continue}
    $updates.Add([pscustomobject]@{Id=$m.Id;ProductMaster__c=$p.Id;MRR_Target__c=$p.MRR_Target__c;ARR_Target__c=$p.ARR_Target__c})
    $rollback.Add([pscustomobject]@{Id=$m.Id;ProductMaster__c=$m.ProductMaster__c;MRR_Target__c=$m.MRR_Target__c;ARR_Target__c=$m.ARR_Target__c})
    $evidence.Add([pscustomobject]@{Id=$m.Id;Name=$m.Name;Month=$m.Month__c;Amount=$m.Total__c;Invoice=$m.RelatedInvoice__c;ProductMaster=$p.Id;ProductName=$p.Name;Rule='同一契約・同一取引先・請求月差1か月以内・明細金額一致・商品候補1件'})
}
$headers=@('Id','ProductMaster__c','MRR_Target__c','ARR_Target__c')
WriteCsv (Join-Path $DataDir 'monthly-product-safe-update.csv') $headers $updates
WriteCsv (Join-Path $DataDir 'monthly-product-rollback.csv') $headers $rollback
$evidence|Export-Csv (Join-Path $DataDir 'monthly-product-evidence.csv') -NoTypeInformation -Encoding UTF8
"updates=$($updates.Count) contracts=$(@($monthly|Where-Object{$updates.Id-contains$_.Id}|Select-Object -ExpandProperty MasterContract__c -Unique).Count)"
$evidence|Group-Object ProductName|Sort-Object Count -Descending|Format-Table Count,Name

