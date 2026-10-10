param(
  [Parameter(Mandatory = $true)]
  [string]$SqlAdminPassword,
  [string]$ContainerName = 'sqlserver_qlcb',
  [string]$SqlAdminUser = 'sa'
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$randomBytes = New-Object byte[] 24
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($randomBytes)
$rng.Dispose()
$appPassword = 'Qc9!' + [Convert]::ToBase64String($randomBytes)
$escapedPassword = $appPassword.Replace("'", "''")
$sql = @"
IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name=N'QLCB_AppLogin')
    CREATE LOGIN [QLCB_AppLogin] WITH PASSWORD=N'$escapedPassword', CHECK_POLICY=ON, DEFAULT_DATABASE=[QL_CHUYENBAY];
ELSE
    ALTER LOGIN [QLCB_AppLogin] WITH PASSWORD=N'$escapedPassword', CHECK_POLICY=ON, DEFAULT_DATABASE=[QL_CHUYENBAY];
GO
USE [QL_CHUYENBAY];
IF DATABASE_PRINCIPAL_ID(N'QLCB_UngDung') IS NULL CREATE ROLE [QLCB_UngDung];
IF DATABASE_PRINCIPAL_ID(N'QLCB_AppLogin') IS NULL CREATE USER [QLCB_AppLogin] FOR LOGIN [QLCB_AppLogin];
IF NOT EXISTS (
  SELECT 1 FROM sys.database_role_members rm
  JOIN sys.database_principals r ON r.principal_id=rm.role_principal_id
  JOIN sys.database_principals u ON u.principal_id=rm.member_principal_id
  WHERE r.name=N'QLCB_UngDung' AND u.name=N'QLCB_AppLogin'
) ALTER ROLE [QLCB_UngDung] ADD MEMBER [QLCB_AppLogin];
GRANT SELECT ON SCHEMA::dbo TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.SP1_DATCHO_TAOVE TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.SP2_DELAY_HUY TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.SP3_TINHDOANHTHU TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.SP4_TRACUUDANHSACH TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.SP5_PHANCONGTOBAY TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.CS1_TinhBoiThuongChuyenBayDelay TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.CS2_TongHopCongNhatPhuCap TO [QLCB_UngDung];
GRANT EXECUTE ON OBJECT::dbo.FN1_HangHoiVien TO [QLCB_UngDung];
GRANT SELECT ON OBJECT::dbo.FN2_DanhSachGheTrong TO [QLCB_UngDung];
GRANT SELECT ON OBJECT::dbo.FN3_ThongKeMayBayTheoThang TO [QLCB_UngDung];
REVOKE EXECUTE ON SCHEMA::dbo FROM [QLCB_UngDung];
REVOKE UPDATE ON OBJECT::dbo.VEBAY FROM [QLCB_UngDung];
REVOKE UPDATE ON OBJECT::dbo.CHUYENBAY FROM [QLCB_UngDung];
GRANT UPDATE ON OBJECT::dbo.VEBAY (TrangThaiVe) TO [QLCB_UngDung];
GRANT UPDATE ON OBJECT::dbo.CHUYENBAY (GiaVeThuongGia) TO [QLCB_UngDung];
GRANT UPDATE ON OBJECT::dbo.MAYBAY (TrangThai) TO [QLCB_UngDung];
GRANT INSERT ON OBJECT::dbo.PHANCONG TO [QLCB_UngDung];
GRANT DELETE ON OBJECT::dbo.MAYBAY TO [QLCB_UngDung];
GO
"@

Push-Location $workspace
try {
  & docker exec $ContainerName /opt/mssql-tools18/bin/sqlcmd -S localhost -U $SqlAdminUser -P $SqlAdminPassword -C -b -Q $sql
  if ($LASTEXITCODE -ne 0) { throw 'SQL Server could not provision the app login. Check the admin password and QL_CHUYENBAY database.' }
  $envContents = @(
    'DB_SERVER=localhost',
    'DB_PORT=1433',
    'DB_NAME=QL_CHUYENBAY',
    'DB_USER=QLCB_AppLogin',
    "DB_PASSWORD=$appPassword",
    'DB_ENCRYPT=false',
    'PORT=3001'
  ) -join "`r`n"
  [System.IO.File]::WriteAllText((Join-Path $workspace '.env'), $envContents + "`r`n", [System.Text.UTF8Encoding]::new($false))
  Write-Host 'Created QLCB_AppLogin, QLCB_UngDung, and the local .env file.'
}
finally {
  Pop-Location
  [Array]::Clear($randomBytes, 0, $randomBytes.Length)
  $appPassword = $null
  $escapedPassword = $null
  $sql = $null
}
