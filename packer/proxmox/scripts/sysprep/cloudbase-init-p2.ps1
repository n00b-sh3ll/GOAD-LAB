$ErrorActionPreference = "Stop"

# Validar que instalacao realmente completou (sem loop infinito)
if (!(Select-String -Path 'C:\setup\cloud-init.log' -Pattern 'Installation completed successfully' -Quiet)) {
    Write-Error "Cloudbase-Init nao foi instalado corretamente. Verifique C:\setup\cloud-init.log"
    Get-Content 'C:\setup\cloud-init.log' | Select-Object -Last 40
    exit 1
}

Write-Output "Show cloudinit service"
Get-Service -Name cloudbase-init

Write-Output "Move config files to location"
Copy-Item "G:\sysprep\cloudbase-init.conf" "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf" -Force
Copy-Item "G:\sysprep\cloudbase-init-unattend.conf" "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.conf" -Force
Copy-Item "G:\sysprep\cloudbase-init-unattend.xml" "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.xml" -Force

Write-Output "Disable cloudbaseinit at start"
Set-Service -Name cloudbase-init -StartupType Disabled

Write-Output "Iniciando sysprep - conexao WinRM sera encerrada"

# Sysprep NAO deve usar -Wait — ele derruba a VM
# O Packer precisa do expect_disconnect = true no provisioner
$sysprepArgs = '/generalize /oobe /mode:vm /unattend:"C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init-unattend.xml"'

Start-Process -FilePath "C:\Windows\system32\sysprep\sysprep.exe" -ArgumentList $sysprepArgs -NoNewWindow

# Aguarda alguns segundos para o sysprep iniciar antes do WinRM cair
Start-Sleep -Seconds 10
exit 0
