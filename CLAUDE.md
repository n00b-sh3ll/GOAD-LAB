# GOAD on Proxmox — Deploy Guide

> **Quando usar:** GOAD, Game of Active Directory, lab AD no Proxmox, Packer/Terraform/Ansible com Windows,
> cloudbase-init, bpg/proxmox, sysprep errors, WinRM Ansible, domain join falha, SPN duplicado,
> trust AD, Netlogon parado, ADCS, exit code 259, VM.Monitor, SID duplicado, SSPI failed.

Stack completa: **Packer** (templates) → **Terraform** (VMs) → **Cloudbase-Init** (IP) → **Ansible** (AD/domínio)

---

## Packer — Templates Windows

### Provider correto
```hcl
packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}
```

### Correções obrigatórias no source
```hcl
# ERRADO (deprecated)
additional_iso_files { device = "sata3" ... }
iso_file = "${var.iso_file}"

# CORRETO
additional_iso_files { type = "sata"  index = 3 ... }
boot_iso { iso_file = "${var.iso_file}" type = "sata" index = 0 unmount = true }
```

### Provisioners — erros comuns

| Erro | Causa | Fix |
|---|---|---|
| Exit 259 | MSI chamado direto sem rastrear PID | Usar `msiexec.exe /i arquivo.msi` explicitamente |
| Exit 259 no sysprep | Sysprep com `-Wait` mata WinRM antes de retornar | Remover `-Wait` + `valid_exit_codes = [0, 259]` |
| `expect_disconnect` | Não existe no provisioner powershell | Usar `pause_after` + `valid_exit_codes` |
| Exit 4294770688 | WinRM conectou antes do sistema estar pronto | `pause_before = "3m0s"` no primeiro provisioner |

```hcl
# Provisioner correto para sysprep
provisioner "powershell" {
  scripts          = ["${path.root}/scripts/sysprep/cloudbase-init-p2.ps1"]
  valid_exit_codes = [0, 259]
  pause_after      = "3m0s"
}
```

### Scripts sysprep

**cloudbase-init.ps1** — instalar MSI via msiexec diretamente:
```powershell
$proc = Start-Process -FilePath "msiexec.exe" `
    -ArgumentList '/i "c:\setup\CloudbaseInitSetup.msi" /qn /l*v C:\setup\cloud-init.log' `
    -Wait -PassThru -NoNewWindow
if ($proc.ExitCode -notin @(0, 3010)) { exit $proc.ExitCode }
```

**cloudbase-init-p2.ps1** — sysprep SEM `-Wait`:
```powershell
# Copiar configs, desabilitar serviço, depois:
Start-Process -FilePath "C:\Windows\system32\sysprep\sysprep.exe" `
    -ArgumentList '/generalize /oobe /mode:vm /unattend:"C:\...\cloudbase-init-unattend.xml"' `
    -NoNewWindow
Start-Sleep -Seconds 15
exit 0
```

---

## Terraform — Provider bpg/proxmox

### ⚠️ NÃO usar telmate/proxmox
O telmate verifica `VM.Monitor` que não existe em todas as versões do Proxmox.

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.46.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://IP:8006/"   # SEM /api2/json
  username = "infra_as_code@pve"
  password = var.pm_password
  insecure = true
}
```

### Resource correto (bpg)
```hcl
resource "proxmox_virtual_environment_vm" "windows_vms" {
  for_each = var.vm_config

  clone          { vm_id = lookup(var.vm_template_id, each.value.clone, -1); full = var.pm_full_clone }
  cpu            { cores = each.value.cores; sockets = 1 }
  memory         { dedicated = each.value.memory }
  network_device { bridge = var.network_bridge; model = var.network_model; vlan_id = var.network_vlan }

  initialization {
    datastore_id = var.storage
    dns      { servers = [each.value.dns, "1.1.1.1"] }
    ip_config { ipv4 { address = each.value.ip; gateway = each.value.gateway } }
  }

  lifecycle { ignore_changes = [vga] }
}
```

### Regras importantes
- `network_model = "e1000"` — **NÃO usar virtio** (quebra Ansible domain join)
- VMs definidas em `variable "vm_config"` tipada com `map(object)`
- Endpoint **sem** `/api2/json` no final

### Permissões Proxmox
```bash
pveum acl modify / -user 'infra_as_code@pve' -role Administrator
```

---

## Ansible — Inventory Completo

```ini
[default]
; sevenkingdoms.local
dc01 ansible_host=10.10.0.10 dns_domain=dc01 dict_key=dc01
; north.sevenkingdoms.local
dc02 ansible_host=10.10.0.11 dns_domain=dc01 dict_key=dc02
srv02 ansible_host=10.10.0.22 dns_domain=dc02 dict_key=srv02
; essos.local
dc03 ansible_host=10.10.0.12 dns_domain=dc03 dict_key=dc03
srv03 ansible_host=10.10.0.23 dns_domain=dc03 dict_key=srv03

[all:vars]
domain_name=GOAD
admin_user=administrator
keyboard_layouts=["00000409"]
add_route=no
route_gateway=10.10.0.1
route_network=10.0.0.0/8
enable_http_proxy=no
http_proxy=no
ad_http_proxy=http://x.x.x.x:xxxx
ad_https_proxy=http://x.x.x.x:xxxx
force_dns_server=yes
dns_server=10.10.0.1
dns_server_forwarder=8.8.8.8
ansible_user=vagrant
ansible_password=vagrant
ansible_connection=winrm
ansible_winrm_server_cert_validation=ignore
ansible_winrm_operation_timeout_sec=400
ansible_winrm_read_timeout_sec=500
ansible_winrm_transport=ntlm
ansible_winrm_port=5985

[domain]
dc01
dc02
dc03
srv02
srv03

[linux_domain]

[dc]
dc01
dc02
dc03

[server]
srv02
srv03

[workstation]

[parent_dc]
dc01
dc03

[child_dc]
dc02

[trust]
dc01
dc03

[adcs]
dc01
dc03
srv03

[adcs_customtemplates]
dc03

[iis]
srv02

[mssql]
srv02
srv03

[mssql_ssms]
srv02

[webdav]
srv02
srv03

[laps_dc]
dc03

[laps_server]
srv03

[laps_workstation]

[update]
srv02

[no_update]
dc01
dc02
dc03
srv03

[defender_on]
dc01
dc02
dc03
srv03

[defender_off]
srv02

[extensions]
```

### Comando principal
```bash
ansible-playbook -i ~/GOAD/ad/GOAD/providers/proxmox/inventory \
  ~/GOAD/ansible/main.yml -e "domain_name=GOAD"
```

---

## Ordem correta de execução Ansible

```bash
INVENTORY=~/GOAD/ad/GOAD/providers/proxmox/inventory
EXTRA="-e domain_name=GOAD"

# 1. Build (common, keyboard, WinRM)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/build.yml $EXTRA

# 2. Parent DCs (dc01, dc03)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-parent_domain.yml $EXTRA

# 3. Child DC (dc02) — após dc01 reiniciar (~5min)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-child_domain.yml $EXTRA

# 4. Member servers (srv02, srv03)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-members.yml $EXTRA

# 5. Trusts entre domínios
ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-trusts.yml $EXTRA

# 6. ADCS (Certificate Services)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/adcs.yml $EXTRA

# 7. Main completo (idempotente)
ansible-playbook -i $INVENTORY ~/GOAD/ansible/main.yml $EXTRA
```

---

## Troubleshooting — Erros Comuns

### IP não atribuído após deploy
```powershell
Get-Service -Name cloudbase-init
Start-Service cloudbase-init
Set-Service cloudbase-init -StartupType Automatic
```

### SID duplicado (domain join falha)
Causa: template gerado sem `/generalize` no sysprep.
```powershell
# No console Proxmox da VM afetada
C:\Windows\System32\sysprep\sysprep.exe /generalize /oobe /mode:vm /reboot
```

### SPN duplicado forest-wide
```bash
# Limpar objeto fantasma no AD
ansible dc03 -i $INVENTORY -m win_shell -a "
\$comp = Get-ADComputer -Filter {Name -eq 'braavos'} -ErrorAction SilentlyContinue
if (\$comp) { Remove-ADObject -Identity \$comp -Recursive -Confirm:\$false }
"
# Limpar SPNs duplicados
ansible dc01 -i $INVENTORY -m win_shell -a "setspn -F -Q HOST/braavos 2>&1"
```

### Netlogon parado no DC
```bash
ansible dc02 -i $INVENTORY -m win_shell -a "
Set-Service Netlogon -StartupType Automatic
Start-Service Netlogon
nltest /dsregdns
ipconfig /registerdns
"
```

### SSPI failed (grupos cross-domain)
Trust existe mas sem canal seguro — forçar verificação:
```bash
ansible dc01 -i $INVENTORY -m win_shell -a "nltest /sc_verify:essos.local 2>&1"
ansible dc03 -i $INVENTORY -m win_shell -a "nltest /sc_verify:sevenkingdoms.local 2>&1"
```

### ADCS não instalado (adcs_esc* falham)
```bash
# Verificar se CertSvc existe
ansible dc03 -i $INVENTORY -m win_shell \
  -a "Get-Service CertSvc -ErrorAction SilentlyContinue | Select Name,Status"

# Adicionar dc03 no grupo [adcs] do inventory, depois:
ansible-playbook -i $INVENTORY ~/GOAD/ansible/adcs.yml $EXTRA --limit dc03
```

### VM com hostname genérico após sysprep
```bash
ansible srv03 -i $INVENTORY -m win_shell \
  -a "Rename-Computer -NewName 'braavos' -Force -Restart"
```

### VM em estado inconsistente de domínio
```bash
# Forçar saída do domínio via registry
ansible srv03 -i $INVENTORY -m win_shell -a "
reg add 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' /v Domain /t REG_SZ /d '' /f
reg add 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' /v 'NV Domain' /t REG_SZ /d '' /f
Restart-Computer -Force
"
```

### Verificar trust entre domínios
```bash
# Ver trusts (nltest é mais confiável que Get-ADTrust para TrustDirection)
ansible dc01 -i $INVENTORY -m win_shell -a "nltest /domain_trusts /all_trusts 2>&1"
# Esperar: (Direct Outbound) (Direct Inbound) = bidirecional
```

---

## Tabela de Erros Rápida

### Packer
| Erro | Solução |
|---|---|
| Exit 259 | `msiexec.exe /i` direto + `-Wait -PassThru` |
| Exit 259 sysprep | Remover `-Wait` do sysprep + `valid_exit_codes=[0,259]` |
| `device` deprecated | `type` + `index` no `additional_iso_files` |
| `iso_file` deprecated | Bloco `boot_iso {}` |
| `expect_disconnect` error | Usar `pause_after` + `valid_exit_codes` |

### Terraform
| Erro | Solução |
|---|---|
| `VM.Monitor` missing | Migrar para `bpg/proxmox >= 0.46.0` |
| `invalid privilege VM.Monitor` | Confirma — usar bpg resolve |
| Endpoint com `/api2/json` | Remover do endpoint |

### Ansible
| Erro | Solução |
|---|---|
| SSH porta 22 | Adicionar `ansible_connection=winrm` |
| `enable_http_proxy` undefined | `enable_http_proxy=no` + `http_proxy=no` |
| `add_route` undefined | `add_route=no` |
| `keyboard_layouts` undefined | `keyboard_layouts=["00000409"]` |
| `admin_user` undefined | `admin_user=administrator` |
| `layouts` requires list | Usar `["00000409"]` não `0409:00000409` |

### Domain Join
| Erro | Solução |
|---|---|
| SID duplicado | Sysprep manual com `/generalize` |
| SPN duplicado | `Remove-ADObject` + `setspn -F -Q` |
| Domain não encontrado | Verificar Netlogon + `nltest /dsgetdc:` |
| SSPI failed | `nltest /sc_verify:dominio.local` |

### ADCS
| Erro | Solução |
|---|---|
| `Set-ADCSTemplateACL` null | Adicionar host no `[adcs]` + rodar `adcs.yml` |
| CertSvc não encontrado | Feature não instalada — rodar `adcs.yml` |
