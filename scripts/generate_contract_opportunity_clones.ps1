$ErrorActionPreference = 'Stop'

function New-Directory($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Escape-Xml($Value) {
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape([string]$Value)
}

function Picklist-Xml($Values, [bool]$Restricted = $true, [bool]$Multi = $false, [int]$VisibleLines = 4) {
    $lines = @()
    if ($Restricted) {
        $lines += '    <valueSet>'
        $lines += '        <restricted>true</restricted>'
    } else {
        $lines += '    <valueSet>'
    }
    $lines += '        <valueSetDefinition>'
    $lines += '            <sorted>false</sorted>'
    foreach ($value in $Values) {
        $fullName = if ($value -is [hashtable]) { $value.fullName } else { $value }
        $label = if ($value -is [hashtable] -and $value.label) { $value.label } else { $fullName }
        $default = if ($value -is [hashtable] -and $value.default) { 'true' } else { 'false' }
        $lines += '            <value>'
        $lines += "                <fullName>$(Escape-Xml $fullName)</fullName>"
        $lines += "                <default>$default</default>"
        $lines += "                <label>$(Escape-Xml $label)</label>"
        $lines += '            </value>'
    }
    $lines += '        </valueSetDefinition>'
    $lines += '    </valueSet>'
    if ($Multi) {
        $lines += "    <visibleLines>$VisibleLines</visibleLines>"
    }
    return $lines
}

function Field-Xml($Field) {
    $lines = @(
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">',
        "    <fullName>$($Field.fullName)</fullName>"
    )
    if ($Field.type -eq 'Lookup') {
        if ($Field.deleteConstraint) {
            $lines += "    <deleteConstraint>$($Field.deleteConstraint)</deleteConstraint>"
        }
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <referenceTo>$($Field.referenceTo)</referenceTo>"
        $lines += "    <relationshipLabel>$(Escape-Xml $Field.relationshipLabel)</relationshipLabel>"
        $lines += "    <relationshipName>$($Field.relationshipName)</relationshipName>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += '    <type>Lookup</type>'
    } elseif ($Field.type -eq 'Picklist' -or $Field.type -eq 'MultiselectPicklist') {
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += "    <type>$($Field.type)</type>"
        $lines += Picklist-Xml -Values $Field.values -Restricted $true -Multi:($Field.type -eq 'MultiselectPicklist')
    } elseif ($Field.type -eq 'LongTextArea') {
        $lines += '    <externalId>false</externalId>'
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <length>$($Field.length)</length>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += "    <type>$($Field.type)</type>"
        $lines += "    <visibleLines>$($Field.visibleLines)</visibleLines>"
    } elseif ($Field.type -eq 'TextArea') {
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += '    <type>TextArea</type>'
    } elseif ($Field.type -eq 'Text') {
        $lines += '    <externalId>false</externalId>'
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <length>$($Field.length)</length>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += '    <type>Text</type>'
        $lines += '    <unique>false</unique>'
    } elseif ($Field.type -eq 'Number' -or $Field.type -eq 'Currency' -or $Field.type -eq 'Percent') {
        $lines += '    <externalId>false</externalId>'
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <precision>$($Field.precision)</precision>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += "    <scale>$($Field.scale)</scale>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += "    <type>$($Field.type)</type>"
        $lines += '    <unique>false</unique>'
    } elseif ($Field.type -eq 'Checkbox') {
        $default = if ($Field.defaultValue) { $Field.defaultValue } else { 'false' }
        $lines += "    <defaultValue>$default</defaultValue>"
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += '    <type>Checkbox</type>'
    } elseif ($Field.type -eq 'Date' -or $Field.type -eq 'DateTime') {
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <required>$([string]$Field.required).ToLower()</required>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <trackTrending>false</trackTrending>'
        $lines += "    <type>$($Field.type)</type>"
    } elseif ($Field.type -eq 'AutoNumber') {
        $lines += "    <displayFormat>$($Field.displayFormat)</displayFormat>"
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        $lines += "    <startingNumber>$($Field.startingNumber)</startingNumber>"
        $lines += '    <trackHistory>false</trackHistory>'
        $lines += '    <type>AutoNumber</type>'
    } elseif ($Field.type -eq 'Formula') {
        $lines += "    <formula>$(Escape-Xml $Field.formula)</formula>"
        if ($Field.formulaTreatBlanksAs) {
            $lines += "    <formulaTreatBlanksAs>$($Field.formulaTreatBlanksAs)</formulaTreatBlanksAs>"
        }
        $lines += "    <label>$(Escape-Xml $Field.label)</label>"
        if ($Field.formulaType -eq 'Checkbox') {
            $lines += '    <type>Checkbox</type>'
        } elseif ($Field.formulaType -eq 'Currency' -or $Field.formulaType -eq 'Number' -or $Field.formulaType -eq 'Percent') {
            $lines += "    <precision>$($Field.precision)</precision>"
            $lines += "    <scale>$($Field.scale)</scale>"
            $lines += "    <type>$($Field.formulaType)</type>"
        } else {
            $lines += "    <type>$($Field.formulaType)</type>"
        }
    } else {
        throw "Unsupported field type: $($Field.type)"
    }
    $lines += '</CustomField>'
    return ($lines -join "`r`n") + "`r`n"
}

function Write-Field($ObjectName, $Field) {
    $dir = Join-Path $Root "force-app\main\default\objects\$ObjectName\fields"
    New-Directory $dir
    $path = Join-Path $dir "$($Field.fullName).field-meta.xml"
    Field-Xml $Field | Set-Content -LiteralPath $path -Encoding UTF8
}

function Layout-Item($Field, $Behavior = 'Edit') {
@"
            <layoutItems>
                <behavior>$Behavior</behavior>
                <field>$Field</field>
            </layoutItems>
"@
}

function Layout-Section($Label, $Left, $Right, $Style = 'TwoColumnsTopToBottom', [bool]$CustomLabel = $false, [bool]$DetailHeading = $false) {
    $custom = [string]$CustomLabel
    $detail = [string]$DetailHeading
    $leftXml = ($Left -join "`r`n")
    $rightXml = ($Right -join "`r`n")
    if ($Style -eq 'OneColumn') {
@"
    <layoutSections>
        <customLabel>$($custom.ToLower())</customLabel>
        <detailHeading>$($detail.ToLower())</detailHeading>
        <editHeading>true</editHeading>
        <label>$(Escape-Xml $Label)</label>
        <layoutColumns>
$leftXml
        </layoutColumns>
        <style>$Style</style>
    </layoutSections>
"@
        return
    }
@"
    <layoutSections>
        <customLabel>$($custom.ToLower())</customLabel>
        <detailHeading>$($detail.ToLower())</detailHeading>
        <editHeading>true</editHeading>
        <label>$(Escape-Xml $Label)</label>
        <layoutColumns>
$leftXml
        </layoutColumns>
        <layoutColumns>
$rightXml
        </layoutColumns>
        <style>$Style</style>
    </layoutSections>
"@
}

$Root = Resolve-Path (Join-Path $PSScriptRoot '..')

$contractFields = @(
    @{ fullName='Account__c'; label='Account'; type='Lookup'; referenceTo='Account'; relationshipLabel='Custom Contracts'; relationshipName='CustomContracts'; required=$true; deleteConstraint='Restrict' },
    @{ fullName='Pricebook2__c'; label='Price Book'; type='Lookup'; referenceTo='Pricebook2'; relationshipLabel='Custom Contracts'; relationshipName='CustomContracts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='OwnerExpirationNotice__c'; label='Owner Expiration Notice'; type='Picklist'; required=$false; values=@('15','30','45','60','90','120') },
    @{ fullName='StartDate__c'; label='Contract Start Date'; type='Date'; required=$false },
    @{ fullName='EndDate__c'; label='Contract End Date'; type='Date'; required=$false },
    @{ fullName='ContractNumber__c'; label='Contract Number'; type='AutoNumber'; displayFormat='CN-{000000}'; startingNumber='1' },
    @{ fullName='ContractTerm__c'; label='Contract Term'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='Status__c'; label='Status'; type='Picklist'; required=$true; values=@('In Approval Process','Activated','Draft') },
    @{ fullName='StatusCode__c'; label='Status Category'; type='Picklist'; required=$false; values=@('Draft','InApproval','Activated','Terminated','Expired','Rejected','Negotiating','AwaitingSignature','SignatureDeclined','Signed','Cancelled','Expired2','Terminated2') },
    @{ fullName='CompanySigned__c'; label='Company Signed By'; type='Lookup'; referenceTo='User'; relationshipLabel='Company Signed Custom Contracts'; relationshipName='CompanySignedCustomContracts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='CompanySignedDate__c'; label='Company Signed Date'; type='Date'; required=$false },
    @{ fullName='CustomerSigned__c'; label='Customer Signed By'; type='Lookup'; referenceTo='Contact'; relationshipLabel='Customer Signed Custom Contracts'; relationshipName='CustomerSignedCustomContracts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='CustomerSignedTitle__c'; label='Customer Signed Title'; type='Text'; length='255'; required=$false },
    @{ fullName='CustomerSignedDate__c'; label='Customer Signed Date'; type='Date'; required=$false },
    @{ fullName='SpecialTerms__c'; label='Special Terms'; type='LongTextArea'; length='32768'; visibleLines='4'; required=$false },
    @{ fullName='Description__c'; label='Description'; type='LongTextArea'; length='32768'; visibleLines='4'; required=$false },
    @{ fullName='ActivatedBy__c'; label='Activated By'; type='Lookup'; referenceTo='User'; relationshipLabel='Activated Custom Contracts'; relationshipName='ActivatedCustomContracts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='ActivatedDate__c'; label='Activated Date'; type='DateTime'; required=$false },
    @{ fullName='LastApprovedDate__c'; label='Last Approved Date'; type='DateTime'; required=$false },
    @{ fullName='BillingStreet__c'; label='Billing Street'; type='TextArea'; required=$false },
    @{ fullName='BillingCity__c'; label='Billing City'; type='Text'; length='255'; required=$false },
    @{ fullName='BillingState__c'; label='Billing State/Province'; type='Text'; length='255'; required=$false },
    @{ fullName='BillingPostalCode__c'; label='Billing Zip/Postal Code'; type='Text'; length='255'; required=$false },
    @{ fullName='BillingCountry__c'; label='Billing Country'; type='Text'; length='255'; required=$false },
    @{ fullName='BillingLatitude__c'; label='Billing Latitude'; type='Number'; precision='18'; scale='8'; required=$false },
    @{ fullName='BillingLongitude__c'; label='Billing Longitude'; type='Number'; precision='18'; scale='8'; required=$false },
    @{ fullName='BillingGeocodeAccuracy__c'; label='Billing Geocode Accuracy'; type='Picklist'; required=$false; values=@('Address','NearAddress','Block','Street','ExtendedZip','Zip','Neighborhood','City','County','State','Unknown') },
    @{ fullName='ShippingStreet__c'; label='Shipping Street'; type='TextArea'; required=$false },
    @{ fullName='ShippingCity__c'; label='Shipping City'; type='Text'; length='255'; required=$false },
    @{ fullName='ShippingState__c'; label='Shipping State/Province'; type='Text'; length='255'; required=$false },
    @{ fullName='ShippingPostalCode__c'; label='Shipping Zip/Postal Code'; type='Text'; length='255'; required=$false },
    @{ fullName='ShippingCountry__c'; label='Shipping Country'; type='Text'; length='255'; required=$false },
    @{ fullName='ShippingLatitude__c'; label='Shipping Latitude'; type='Number'; precision='18'; scale='8'; required=$false },
    @{ fullName='ShippingLongitude__c'; label='Shipping Longitude'; type='Number'; precision='18'; scale='8'; required=$false },
    @{ fullName='ShippingGeocodeAccuracy__c'; label='Shipping Geocode Accuracy'; type='Picklist'; required=$false; values=@('Address','NearAddress','Block','Street','ExtendedZip','Zip','Neighborhood','City','County','State','Unknown') }
)

$opportunityFields = @(
    @{ fullName='Account__c'; label='Account'; type='Lookup'; referenceTo='Account'; relationshipLabel='Custom Opportunities'; relationshipName='CustomOpportunities'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='IsPrivate__c'; label='Private'; type='Checkbox'; defaultValue='false' },
    @{ fullName='Description__c'; label='Description'; type='LongTextArea'; length='32768'; visibleLines='4'; required=$false },
    @{ fullName='StageName__c'; label='Stage'; type='Picklist'; required=$true; values=@('Prospecting','Qualification','Needs Analysis','Value Proposition','Id. Decision Makers','Perception Analysis','Proposal/Price Quote','Negotiation/Review','Closed Won','Closed Lost') },
    @{ fullName='Amount__c'; label='Amount'; type='Currency'; precision='18'; scale='2'; required=$false },
    @{ fullName='StandardProbability__c'; label='Probability (%)'; type='Percent'; precision='3'; scale='0'; required=$false },
    @{ fullName='ExpectedRevenue__c'; label='Expected Amount'; type='Formula'; formulaType='Currency'; precision='18'; scale='2'; formula='Amount__c * StandardProbability__c / 100'; formulaTreatBlanksAs='BlankAsZero' },
    @{ fullName='TotalOpportunityQuantity__c'; label='Quantity'; type='Number'; precision='18'; scale='2'; required=$false },
    @{ fullName='StandardCloseDate__c'; label='Close Date'; type='Date'; required=$true },
    @{ fullName='Type__c'; label='Opportunity Type'; type='Picklist'; required=$false; values=@('Existing Customer - Upgrade','Existing Customer - Replacement','Existing Customer - Downgrade','New Customer') },
    @{ fullName='NextStep__c'; label='Next Step'; type='Text'; length='255'; required=$false },
    @{ fullName='LeadSource__c'; label='Lead Source'; type='Picklist'; required=$false; values=@('Web','Phone Inquiry','Partner Referral','Purchased List','Other') },
    @{ fullName='IsClosed__c'; label='Closed'; type='Formula'; formulaType='Checkbox'; formula='OR(ISPICKVAL(StageName__c, "Closed Won"), ISPICKVAL(StageName__c, "Closed Lost"))' },
    @{ fullName='IsWon__c'; label='Won'; type='Formula'; formulaType='Checkbox'; formula='ISPICKVAL(StageName__c, "Closed Won")' },
    @{ fullName='ForecastCategory__c'; label='Forecast Category'; type='Picklist'; required=$false; values=@('Omitted','Pipeline','BestCase','MostLikely','Forecast','Closed') },
    @{ fullName='ForecastCategoryName__c'; label='Forecast Category'; type='Picklist'; required=$false; values=@('Omitted','Pipeline','Best Case','Commit','Closed') },
    @{ fullName='Campaign__c'; label='Campaign'; type='Lookup'; referenceTo='Campaign'; relationshipLabel='Custom Opportunities'; relationshipName='CustomCampaignOpportunities'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='HasOpportunityLineItem__c'; label='Has Line Item'; type='Checkbox'; defaultValue='false' },
    @{ fullName='Pricebook2__c'; label='Price Book'; type='Lookup'; referenceTo='Pricebook2'; relationshipLabel='Custom Opportunities'; relationshipName='CustomOpportunityPricebooks'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='PushCount__c'; label='Push Count'; type='Number'; precision='18'; scale='0'; required=$false },
    @{ fullName='LastStageChangeDate__c'; label='Last Stage Change Date'; type='DateTime'; required=$false },
    @{ fullName='FiscalQuarter__c'; label='Fiscal Quarter'; type='Number'; precision='1'; scale='0'; required=$false },
    @{ fullName='FiscalYear__c'; label='Fiscal Year'; type='Number'; precision='4'; scale='0'; required=$false },
    @{ fullName='Fiscal__c'; label='Fiscal Period'; type='Text'; length='255'; required=$false },
    @{ fullName='Contact__c'; label='Contact'; type='Lookup'; referenceTo='Contact'; relationshipLabel='Custom Opportunities'; relationshipName='CustomContactOpportunities'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='ACV__c'; label='ACV'; type='Currency'; precision='18'; scale='2'; required=$false },
    @{ fullName='ARR__c'; label='ARR'; type='Currency'; precision='18'; scale='0'; required=$false },
    @{ fullName='MRR__c'; label='MRR'; type='Currency'; precision='18'; scale='2'; required=$false },
    @{ fullName='Channel__c'; label='Order Channel'; type='Picklist'; required=$false; values=@('Cloudworks','Company Website','Customer Referral') },
    @{ fullName='CloseDate__c'; label='Deal End Date'; type='Date'; required=$false },
    @{ fullName='ExpectedCloseDate__c'; label='Expected Close Date'; type='Date'; required=$false },
    @{ fullName='Labels__c'; label='Labels'; type='MultiselectPicklist'; required=$false; values=@(@{ fullName='Undefined'; label='Undefined'; default=$true }) },
    @{ fullName='LostDate__c'; label='Lost Date'; type='Date'; required=$false },
    @{ fullName='LostReason__c'; label='Lost Reason'; type='Picklist'; required=$false; values=@('Out of scope','No agreement on issue or setup','Customer concern unresolved','Needs mismatch','Key person unreachable','Budget shortage - running cost','Budget shortage - initial or migration cost','Competitor comparison','Timing mismatch','Support or track record concern','No response or other reason') },
    @{ fullName='NextActivityDate__c'; label='Next Activity Date'; type='Date'; required=$false },
    @{ fullName='PrimaryContact__c'; label='Primary Contact'; type='Lookup'; referenceTo='Contact'; relationshipLabel='Custom Opportunity Primary Contacts'; relationshipName='CustomOpportunityPrimaryContacts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='Probability__c'; label='Win Probability'; type='Text'; length='255'; required=$false },
    @{ fullName='Product__c'; label='Product'; type='Lookup'; referenceTo='Product2'; relationshipLabel='Custom Opportunity Products'; relationshipName='CustomOpportunityProducts'; required=$false; deleteConstraint='SetNull' },
    @{ fullName='ProductQuantity__c'; label='Product Quantity'; type='Number'; precision='18'; scale='2'; required=$false },
    @{ fullName='ProductTotalAmount__c'; label='Product Total Amount'; type='Number'; precision='18'; scale='2'; required=$false },
    @{ fullName='SourceChannel__c'; label='Source Channel'; type='Picklist'; required=$false; values=@('Event','HP','Advertisement','Referral') },
    @{ fullName='SourceChannelId__c'; label='Source Channel ID'; type='Text'; length='255'; required=$false },
    @{ fullName='Stage__c'; label='Stage'; type='Picklist'; required=$false; values=@(@{ fullName='Undefined'; label='Undefined'; default=$true }) },
    @{ fullName='StartDate__c'; label='Start Date'; type='Date'; required=$false },
    @{ fullName='Status__c'; label='Status'; type='Picklist'; required=$false; values=@('In Progress','Won','Lost') },
    @{ fullName='TrackingNumber__c'; label='Tracking Number'; type='Text'; length='12'; required=$false }
)

$contractObjectDir = Join-Path $Root 'force-app\main\default\objects\Contract__c'
$opportunityObjectDir = Join-Path $Root 'force-app\main\default\objects\Opportunity__c'
New-Directory $contractObjectDir
New-Directory $opportunityObjectDir
New-Directory (Join-Path $contractObjectDir 'fields')
New-Directory (Join-Path $opportunityObjectDir 'fields')

@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Custom clone of the standard Contract object.</description>
    <enableActivities>true</enableActivities>
    <enableFeeds>false</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <label>Contract Clone</label>
    <nameField>
        <label>Contract Name</label>
        <type>Text</type>
    </nameField>
    <pluralLabel>Contract Clones</pluralLabel>
    <searchLayouts>
        <customTabListAdditionalFields>ContractNumber__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>Account__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>Status__c</customTabListAdditionalFields>
        <searchResultsAdditionalFields>ContractNumber__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>Account__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>Status__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>StartDate__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>EndDate__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>ContractTerm__c</searchResultsAdditionalFields>
    </searchLayouts>
    <sharingModel>Read</sharingModel>
</CustomObject>
'@ | Set-Content -LiteralPath (Join-Path $contractObjectDir 'Contract__c.object-meta.xml') -Encoding UTF8

@'
<?xml version="1.0" encoding="UTF-8"?>
<CustomObject xmlns="http://soap.sforce.com/2006/04/metadata">
    <deploymentStatus>Deployed</deploymentStatus>
    <description>Custom clone of the standard Opportunity object.</description>
    <enableActivities>true</enableActivities>
    <enableFeeds>true</enableFeeds>
    <enableHistory>false</enableHistory>
    <enableReports>true</enableReports>
    <label>Opportunity Clone</label>
    <nameField>
        <label>Opportunity Name</label>
        <type>Text</type>
    </nameField>
    <pluralLabel>Opportunity Clones</pluralLabel>
    <searchLayouts>
        <customTabListAdditionalFields>Account__c</customTabListAdditionalFields>
        <customTabListAdditionalFields>StandardCloseDate__c</customTabListAdditionalFields>
        <searchResultsAdditionalFields>Account__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>StageName__c</searchResultsAdditionalFields>
        <searchResultsAdditionalFields>StandardCloseDate__c</searchResultsAdditionalFields>
    </searchLayouts>
    <sharingModel>Read</sharingModel>
</CustomObject>
'@ | Set-Content -LiteralPath (Join-Path $opportunityObjectDir 'Opportunity__c.object-meta.xml') -Encoding UTF8

foreach ($field in $contractFields) {
    Write-Field -ObjectName 'Contract__c' -Field $field
}
foreach ($field in $opportunityFields) {
    Write-Field -ObjectName 'Opportunity__c' -Field $field
}

$contractLayout = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Layout xmlns="http://soap.sforce.com/2006/04/metadata">',
    (Layout-Section 'Contract Information' @(
        (Layout-Item 'Name' 'Required'),
        (Layout-Item 'Pricebook2__c'),
        (Layout-Item 'OwnerId'),
        (Layout-Item 'ContractNumber__c' 'Readonly'),
        (Layout-Item 'Account__c' 'Required'),
        (Layout-Item 'CustomerSigned__c'),
        (Layout-Item 'CustomerSignedTitle__c'),
        (Layout-Item 'CustomerSignedDate__c')
    ) @(
        (Layout-Item 'Status__c' 'Required'),
        (Layout-Item 'StartDate__c' 'Required'),
        (Layout-Item 'EndDate__c' 'Readonly'),
        (Layout-Item 'ContractTerm__c' 'Required'),
        (Layout-Item 'OwnerExpirationNotice__c'),
        (Layout-Item 'CompanySigned__c'),
        (Layout-Item 'CompanySignedDate__c')
    )),
    (Layout-Section 'Address Information' @(
        (Layout-Item 'BillingStreet__c'),
        (Layout-Item 'BillingCity__c'),
        (Layout-Item 'BillingState__c'),
        (Layout-Item 'BillingPostalCode__c'),
        (Layout-Item 'BillingCountry__c'),
        (Layout-Item 'BillingLatitude__c'),
        (Layout-Item 'BillingLongitude__c'),
        (Layout-Item 'BillingGeocodeAccuracy__c')
    ) @(
        (Layout-Item 'ShippingStreet__c'),
        (Layout-Item 'ShippingCity__c'),
        (Layout-Item 'ShippingState__c'),
        (Layout-Item 'ShippingPostalCode__c'),
        (Layout-Item 'ShippingCountry__c'),
        (Layout-Item 'ShippingLatitude__c'),
        (Layout-Item 'ShippingLongitude__c'),
        (Layout-Item 'ShippingGeocodeAccuracy__c')
    )),
    (Layout-Section 'System Information' @(
        (Layout-Item 'ActivatedBy__c' 'Readonly'),
        (Layout-Item 'CreatedById' 'Readonly')
    ) @(
        (Layout-Item 'ActivatedDate__c' 'Readonly'),
        (Layout-Item 'LastModifiedById' 'Readonly')
    )),
    (Layout-Section 'Description Information' @(
        (Layout-Item 'SpecialTerms__c'),
        (Layout-Item 'Description__c')
    ) @() 'OneColumn'),
@'
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>true</editHeading>
        <layoutColumns/>
        <layoutColumns/>
        <layoutColumns/>
        <style>CustomLinks</style>
    </layoutSections>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>TASK.STATUS</fields>
        <fields>TASK.PRIORITY</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <relatedList>RelatedActivityList</relatedList>
    </relatedLists>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <fields>TASK.LAST_UPDATE</fields>
        <relatedList>RelatedHistoryList</relatedList>
    </relatedLists>
    <relatedLists>
        <relatedList>RelatedNoteList</relatedList>
    </relatedLists>
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
'@
)

$opportunityLayout = @(
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<Layout xmlns="http://soap.sforce.com/2006/04/metadata">',
    (Layout-Section 'Opportunity Information' @(
        (Layout-Item 'OwnerId'),
        (Layout-Item 'Name' 'Required'),
        (Layout-Item 'Type__c'),
        (Layout-Item 'Channel__c'),
        (Layout-Item 'Stage__c'),
        (Layout-Item 'SourceChannel__c'),
        (Layout-Item 'Status__c'),
        (Layout-Item 'Probability__c')
    ) @(
        (Layout-Item 'StandardCloseDate__c' 'Required'),
        (Layout-Item 'StartDate__c'),
        (Layout-Item 'ExpectedCloseDate__c'),
        (Layout-Item 'CloseDate__c'),
        (Layout-Item 'NextActivityDate__c'),
        (Layout-Item 'NextStep__c'),
        (Layout-Item 'StageName__c' 'Required'),
        (Layout-Item 'StandardProbability__c'),
        (Layout-Item 'LeadSource__c'),
        (Layout-Item 'Labels__c')
    ) 'TwoColumnsLeftToRight' $true $true),
    (Layout-Section 'Customer Information' @(
        (Layout-Item 'Account__c')
    ) @(
        (Layout-Item 'PrimaryContact__c'),
        (Layout-Item 'Contact__c'),
        (Layout-Item 'Campaign__c')
    ) 'TwoColumnsLeftToRight' $true $true),
    (Layout-Section 'Amount Information' @(
        (Layout-Item 'Amount__c'),
        (Layout-Item 'ExpectedRevenue__c' 'Readonly'),
        (Layout-Item 'ACV__c'),
        (Layout-Item 'MRR__c'),
        (Layout-Item 'ARR__c')
    ) @(
        (Layout-Item 'TotalOpportunityQuantity__c'),
        (Layout-Item 'ProductTotalAmount__c'),
        (Layout-Item 'ProductQuantity__c'),
        (Layout-Item 'Product__c'),
        (Layout-Item 'Pricebook2__c')
    ) 'TwoColumnsLeftToRight' $true $true),
    (Layout-Section 'Lost Information' @(
        (Layout-Item 'LostDate__c'),
        (Layout-Item 'LostReason__c')
    ) @() 'TwoColumnsLeftToRight' $true $true),
    (Layout-Section 'Forecast Information' @(
        (Layout-Item 'ForecastCategory__c'),
        (Layout-Item 'ForecastCategoryName__c'),
        (Layout-Item 'PushCount__c'),
        (Layout-Item 'LastStageChangeDate__c')
    ) @(
        (Layout-Item 'FiscalQuarter__c'),
        (Layout-Item 'FiscalYear__c'),
        (Layout-Item 'Fiscal__c'),
        (Layout-Item 'SourceChannelId__c'),
        (Layout-Item 'TrackingNumber__c')
    ) 'TwoColumnsLeftToRight'),
    (Layout-Section 'System Information' @(
        (Layout-Item 'IsPrivate__c' 'Readonly'),
        (Layout-Item 'IsClosed__c' 'Readonly'),
        (Layout-Item 'CreatedById' 'Readonly')
    ) @(
        (Layout-Item 'IsWon__c' 'Readonly'),
        (Layout-Item 'HasOpportunityLineItem__c'),
        (Layout-Item 'LastModifiedById' 'Readonly')
    )),
    (Layout-Section 'Description Information' @(
        (Layout-Item 'Description__c')
    ) @() 'OneColumn'),
@'
    <layoutSections>
        <customLabel>false</customLabel>
        <detailHeading>false</detailHeading>
        <editHeading>false</editHeading>
        <label>Custom Links</label>
        <layoutColumns/>
        <layoutColumns/>
        <layoutColumns/>
        <style>CustomLinks</style>
    </layoutSections>
    <relatedLists>
        <relatedList>RelatedContentNoteList</relatedList>
    </relatedLists>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>TASK.STATUS</fields>
        <fields>TASK.PRIORITY</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <relatedList>RelatedActivityList</relatedList>
    </relatedLists>
    <relatedLists>
        <fields>TASK.SUBJECT</fields>
        <fields>TASK.WHO_NAME</fields>
        <fields>ACTIVITY.TASK</fields>
        <fields>TASK.DUE_DATE</fields>
        <fields>CORE.USERS.FULL_NAME</fields>
        <fields>TASK.LAST_UPDATE</fields>
        <relatedList>RelatedHistoryList</relatedList>
    </relatedLists>
    <relatedLists>
        <relatedList>RelatedNoteList</relatedList>
    </relatedLists>
    <showEmailCheckbox>false</showEmailCheckbox>
    <showHighlightsPanel>false</showHighlightsPanel>
    <showInteractionLogPanel>false</showInteractionLogPanel>
    <showRunAssignmentRulesCheckbox>false</showRunAssignmentRulesCheckbox>
    <showSubmitAndAttachButton>false</showSubmitAndAttachButton>
</Layout>
'@
)

$layoutDir = Join-Path $Root 'force-app\main\default\layouts'
New-Directory $layoutDir
($contractLayout -join "`r`n") | Set-Content -LiteralPath (Join-Path $layoutDir 'Contract__c-Contract Clone Layout.layout-meta.xml') -Encoding UTF8
($opportunityLayout -join "`r`n") | Set-Content -LiteralPath (Join-Path $layoutDir 'Opportunity__c-Opportunity Clone Layout.layout-meta.xml') -Encoding UTF8
