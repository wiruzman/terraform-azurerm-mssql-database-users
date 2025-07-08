Import-Module -Name SQLServer -ErrorAction Stop

# Get automation variables
$UserAssignedIdentityId = Get-AutomationVariable -Name 'UserAssignedIdentityId'
$SqlServer = Get-AutomationVariable -Name 'SqlServer'
$Database = Get-AutomationVariable -Name 'Database'
$IdentityName = Get-AutomationVariable -Name 'IdentityName'
$IdentityId = Get-AutomationVariable -Name 'IdentityId'

# Convert GroupClientId to encoded sid
$SID = "0x" + [System.BitConverter]::ToString(([guid]$IdentityId).ToByteArray()).Replace("-", "")

# Idempotent SQL command
$Query = @"
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$IdentityName')
BEGIN
    CREATE USER [$IdentityName] WITH DEFAULT_SCHEMA=[dbo], SID=$SID, TYPE=E;
    EXEC sp_addrolemember 'db_datareader', [$IdentityName];
END
"@

$ErrorActionPreference = 'Stop'
Disable-AzContextAutosave -Scope Process
Connect-AzAccount -Identity -AccountId $UserAssignedIdentityId
$Token = ConvertFrom-SecureString (Get-AzAccessToken -AsSecureString -ResourceUrl https://database.windows.net).Token -AsPlainText
Invoke-Sqlcmd -ServerInstance $SqlServer `
  -Database $Database `
  -Query $Query `
  -AccessToken $Token

Write-Output "✅ [$IdentityName] ensured in [$Database] with SID: $SID"