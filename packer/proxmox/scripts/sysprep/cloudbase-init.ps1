$ErrorActionPreference = "Stop"

# Garante que o diretorio Temp existe e tem permissao (fix para WinRM elevated)
$tempDir = "C:\Windows\Temp"
if (!(Test-Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force
}

# Permissao explicita para o usuario atual escrever no Temp
$acl = Get-Acl $tempDir
$rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
    $env:USERNAME, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow"
)
$acl.SetAccessRule($rule)
Set-Acl $tempDir $acl

mkdir "c:\setup" -Force

Write-Output "Copy CloudbaseInitSetup_Stable_x64.msi"
Copy-Item "G:\sysprep\CloudbaseInitSetup_Stable_x64.msi" "c:\setup\CloudbaseInitSetup_Stable_x64.msi" -Force

Write-Output "Start process CloudbaseInitSetup_Stable_x64.msi"
$proc = Start-Process -FilePath "msiexec.exe" -ArgumentList '/i "c:\setup\CloudbaseInitSetup_Stable_x64.msi" /qn /l*v C:\setup\cloud-init.log' -Wait -PassThru -NoNewWindow

Write-Output "Exit code: $($proc.ExitCode)"

if ($proc.ExitCode -notin @(0, 3010)) {
    Write-Error "Falha na instalacao. ExitCode: $($proc.ExitCode)"
    Get-Content "C:\setup\cloud-init.log" | Select-Object -Last 40
    exit $proc.ExitCode
}

Write-Output "Cloudbase-Init instalado com sucesso."
