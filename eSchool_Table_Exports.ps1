#eSchool Craate Download Definition for ALL tables specified.
#You can not have an existing upload/download definition called "DBEXP"

Param(
[parameter(Position=0,mandatory=$true,Helpmessage="Eschool username")]
[String]$username="SSOusername", #***Variable*** Change to default eschool usename
[parameter(Mandatory=$false,HelpMessage="File for ADE SSO Password")]
[String]$passwordfile="C:\Scripts\apscnpw.txt" #--- VARIABLE --- change to a file path for SSO password
)

if (-Not($tables)) {
    $tables = @('REG','REG_STU_CONTACT','REG_CONTACT')
}

#encrypted password file.
If (Test-Path $passwordfile) {
    $password = (New-Object pscredential "user",(Get-Content $passwordfile | ConvertTo-SecureString)).GetNetworkCredential().Password
}
Else {
    Write-Host("Password file does not exist! [$passwordfile]. Please enter a password to be saved on this computer for scripts") -ForeGroundColor Yellow
    Read-Host "Enter Password" -AsSecureString |  ConvertFrom-SecureString | Out-File $passwordfile
    $password = Get-Content $passwordfile | ConvertTo-SecureString -AsPlainText -Force
}

$eSchoolDomain = 'https://eschool20.esp.k12.ar.us'
$baseUrl = $eSchoolDomain + "/eSchoolPLUS20/"
$loginUrl = $eSchoolDomain + "/eSchoolPLUS20/Account/LogOn?ReturnUrl=%2feSchoolPLUS20%2f"
$envUrl = $eSchoolDomain + "/eSchoolPLUS20/Account/SetEnvironment/SessionStart"

#Get Verification Token.
$response = Invoke-WebRequest -Uri $loginUrl -SessionVariable rb

#Login
$params = @{
    'UserName' = $username
    'Password' = $password
    '__RequestVerificationToken' = $response.InputFields[0].value
}

$response = Invoke-WebRequest -Uri $loginUrl -WebSession $rb -Method POST -Body $params -ErrorAction Stop
if (($response.ParsedHtml.title -eq "Login") -or ($response.StatusCode -ne 200)) { write-host "Failed to login."; exit 1; }

$fields = $response.InputFields | Group-Object -Property name -AsHashTable
$database = $response.RawContent | Select-String -Pattern 'selected="selected" value="....' -All | Select-Object -Property Matches | ForEach-Object { $PSItem.Matches[0].Value }
$database = $Database.Substring($Database.Length-4,4)
#Set Environment
$params2 = @{
    'ServerName' = $fields.'ServerName'.value
    'EnvironmentConfiguration.Database' = $database
    'UserErrorMessage' = ''
    'EnvironmentConfiguration.SchoolYear' = $fields.'EnvironmentConfiguration.SchoolYear'.value
    'EnvironmentConfiguration.SummerSchool' = 'false'
    'EnvironmentConfiguration.ImpersonatedUser' = ''
}
$response2 = Invoke-WebRequest -Uri $envUrl -WebSession $rb -Method POST -Body $params2
if ($response.StatusCode -ne 200) { write-host "Failed to Set Environment."; exit 1; }


#dd = download definition
$ddhash = @{}

$ddhash["IsCopyNew"] = "False"
$ddhash["NewHeaderNames"] = @("")
$ddhash["InterfaceHeadersToCopy"] = @("")
$ddhash["InterfaceToCopyFrom"] = @("")
$ddhash["CopyHeaders"] = "False"
$ddhash["PageEditMode"] = 0
$ddhash["UploadDownloadDefinition"] = @{}
$ddhash["UploadDownloadDefinition"]["UploadDownload"] = "D"

$ddhash["UploadDownloadDefinition"]["DistrictId"] = 0
$ddhash["UploadDownloadDefinition"]["InterfaceId"] = "DBEXP"
$ddhash["UploadDownloadDefinition"]["Description"] = "Export All eSchool Tables"
$ddhash["UploadDownloadDefinition"]["UploadDownloadRaw"] = "D"
$ddhash["UploadDownloadDefinition"]["ChangeUser"] = $null
$ddhash["UploadDownloadDefinition"]["DeleteEntity"] = $False

$ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] = @()

$headerorder = 0
Import-Csv .\eSchoolDatabase.csv | Where-Object { $tables -contains $PSItem.tblName } | Group-Object -Property tblName | ForEach-Object {
    $tblName = $PSItem.Name

    if ($tblName.IndexOf('_') -ge 1) {
        $tblShortName = $tblName[0]
        $tblName | Select-String '_' -AllMatches | Select-Object -ExpandProperty Matches | ForEach-Object {
            $tblShortName += $tblName[$PSItem.Index + 1]
        }
    } else {
        $tblShortName = $tblName
    }

    if ($tblShortName.length -gt 5) {
        $tblShortName = $tblShortName.SubString(0,5)
    }

    $ifaceheader = $tblShortName
    $description = $tblName
    $filename = "$($tblName).csv"

    $ifaceheader,$description,$filename

    $headerorder++
    $ddhash["UploadDownloadDefinition"]["InterfaceHeaders"] += @{
        "InterfaceId" = "DBEXP"
        "HeaderId" = "$ifaceheader"
        "HeaderOrder" = $headerorder
        "Description" = "$description"
        "FileName" = "$filename"
        "LastRunDate" = $null
        "DelimitChar" = '|'
        "UseChangeFlag" = $False
        "TableAffected" = "$($tblName.ToLower())"
        "AdditionalSql" = $null
        "ColumnHeaders" = $True
        "Delete" = $False
        "CanDelete" = $True
        "ColumnHeadersRaw" = "Y"
        "InterfaceDetails" = @()
    }
   
    $columns = @()
    $columnNum = 1
    $PSItem.Group | ForEach-Object {
        $columns += @{
            "Edit" = $null
            "InterfaceId" = "DBEXP"
            "HeaderId" = "$ifaceheader"
            "FieldId" = "$columnNum"
            "FieldOrder" = "$columnNum"
            "TableName" = "$($tblName.ToLower())"
            "TableAlias" = $null
            "ColumnName" = $PSItem.colName
            "ScreenType" = $null
            "ScreenNumber" = $null
            "FormatString" = $null
            "StartPosition" = $null
            "EndPosition" = $null
            "FieldLength" = [int]$PSItem.colMaxLength + 2 #This fixes the dates that are cut off.
            "ValidationTable" = $null
            "CodeColumn" = $null
            "ValidationList" = $null
            "ErrorMessage" = $null
            "ExternalTable" = $null
            "ExternalColumnIn" = $null
            "ExternalColumnOut" = $null
            "Literal" = $null
            "ColumnOverride" = $null
            "Delete" = $False
            "CanDelete" = $True
            "NewRow" = $True
            "InterfaceTranslations" = @("")
        }
        $columnNum++
    }

    $ddhash["UploadDownloadDefinition"]["InterfaceHeaders"][$headerorder - 1]["InterfaceDetails"] += $columns

}

$jsonpayload = $ddhash | ConvertTo-Json -depth 6

$checkIfExists = Invoke-WebRequest -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=DBEXP" -WebSession $rb
if (($checkIfExists.InputFields | Where-Object { $PSItem.name -eq 'UploadDownloadDefinition.InterfaceId' } | Select-Object -ExpandProperty value) -eq '') {

    #create download definition.
    $response3 = Invoke-RestMethod -Uri "https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/SaveUploadDownload" `
    -WebSession $rb `
    -Method "POST" `
    -ContentType "application/json; charset=UTF-8" `
    -Body $jsonpayload

    if ($response3.PageState -eq 1) {
        Write-Host "Error: " -ForegroundColor RED
        $($response3.ValidationErrorMessages)
    }
} else {
    Write-Host "Info: Job already exists. You need to delete the job at https://eschool20.esp.k12.ar.us/eSchoolPLUS20/Utility/UploadDownload?interfaceId=DBEXP"
}

