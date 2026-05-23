# GOAD-LAB — Game of Active Directory on Proxmox

Fork do [GOAD](https://github.com/Orange-Cyberdefense/GOAD) (Orange Cyberdefense) com todos os fixes necessários para deploy completo no **Proxmox** via Packer + Terraform + Ansible.

> **Atenção:** Este lab é intencionalmente vulnerável. Use apenas em redes isoladas.

---

## Topologia

```
sevenkingdoms.local (Forest Root)
├── dc01  — 10.10.0.10  — kingslanding  — Domain Controller + CA (SEVENKINGDOMS-CA)
└── north.sevenkingdoms.local (Child Domain)
    ├── dc02  — 10.10.0.11  — winterfell    — Domain Controller
    └── srv02 — 10.10.0.22  — castelblack   — Member Server (IIS, MSSQL)

essos.local (External Trust com sevenkingdoms.local)
├── dc03  — 10.10.0.12  — meereen   — Domain Controller
└── srv03 — 10.10.0.23  — braavos   — Member Server + CA (ESSOS-CA, MSSQL)
```

---

## Vulnerabilidades configuradas

| Host | Vulnerabilidades |
|---|---|
| dc01 | SID History, ADCS ESC templates |
| dc02 | AS-REP Roasting, Constrained Delegation, NTLM Relay, GPO Abuse, LLMNR/NBT-NS |
| dc03 | NTLM Downgrade, ADCS ESC7, ESC13, ESC15 |
| srv02 | IIS upload, Open Shares, Kerberoasting (MSSQL linked server) |
| srv03 | ADCS ESC6, ESC11, Open Shares, MSSQL |

---

## Pré-requisitos

- Proxmox VE (testado com 6.17.4-2)
- Templates Windows construídos com Packer (`packer/proxmox/`)
- Terraform com provider `bpg/proxmox >= 0.46.0`
- Ansible com `pywinrm`
- Servidor de provisionamento Linux (Ubuntu/Debian)

---

## Deploy

### 1. Packer — Construir templates

```bash
cd packer/proxmox
packer init packer.json.pkr.hcl
packer build -var-file=windows_server2019_proxmox_cloudinit.pkvars.hcl packer.json.pkr.hcl
```

### 2. Terraform — Provisionar VMs

```bash
cd ad/GOAD/providers/proxmox
terraform init
terraform apply
```

### 3. Ansible — Configurar o lab

```bash
INVENTORY=~/GOAD/ad/GOAD/providers/proxmox/inventory
EXTRA="-e domain_name=GOAD"
PREFIX="LANG=C.utf8 LC_ALL=C.utf8"

# Fix obrigatório: instalar PSPKI 3.7.2 no dc03 antes do main.yml
$PREFIX ansible dc03 -i $INVENTORY -m win_shell -a "
Uninstall-Module PSPKI -AllVersions -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Program Files\WindowsPowerShell\Modules\PSPKI' -Recurse -Force -ErrorAction SilentlyContinue
Install-Module PSPKI -RequiredVersion 3.7.2 -Force -AllowClobber -Scope AllUsers -SkipPublisherCheck
"

# Sequência completa
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/build.yml $EXTRA
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-parent_domain.yml $EXTRA
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-child_domain.yml $EXTRA   # aguardar ~5min após dc01 reiniciar
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-members.yml $EXTRA
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/ad-trusts.yml $EXTRA
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/adcs.yml $EXTRA
$PREFIX ansible-playbook -i $INVENTORY ~/GOAD/ansible/main.yml $EXTRA   # rodar até zero falhas (2-3x)
```

---

## Fixes aplicados neste fork

### 1. ADCS — CA do essos.local em srv03, não em dc03

**Problema:** O upstream lista `dc03` no grupo `[adcs]`. Quando dc03 instala a `ESSOS-CA` primeiro, srv03 não consegue instalar outra CA com o mesmo nome no AD e fica com `CertSvc` parado — fazendo `adcs_esc6` e `adcs_esc11` falharem.

**Fix:** `dc03` removido do grupo `[adcs]` no inventory. A CA `ESSOS-CA` é instalada apenas em `srv03` (braavos), que é o `ca_server` correto conforme `config.json`.

```ini
# ad/GOAD/providers/proxmox/inventory
[adcs]
dc01
srv03   ← correto; dc03 NÃO deve estar aqui
```

### 2. ADCS — adcs_esc6 e adcs_esc11 atribuídos ao host correto

**Problema:** O `config.json` do upstream atribui `adcs_esc6` e `adcs_esc11` ao `srv03`, mas com dc03 tendo a CA, o `certutil -setreg` falhava em srv03 com `ERROR_FILE_NOT_FOUND`.

**Fix:** Mantida a atribuição original do `config.json` (srv03). A CA foi movida para srv03 (fix anterior), então os comandos `certutil` funcionam onde a CA realmente reside.

```json
// ad/GOAD/data/config.json
"srv03": { "vulns": ["openshares", "disable_firewall", "adcs_esc6", "adcs_esc11"] }
```

### 3. PSPKI — versão 3.7.2 obrigatória

**Problema:** `Install-Module PSPKI` instala a versão 4.4.0, compilada contra .NET 6. O Windows Server usa .NET Framework, causando `ReflectionTypeLoadException` ao importar o módulo — `adcs_esc7` falha no dc03.

**Fix:** Instalar explicitamente a versão 3.7.2 antes do primeiro `main.yml`:

```powershell
Uninstall-Module PSPKI -AllVersions -Force
Remove-Item 'C:\Program Files\WindowsPowerShell\Modules\PSPKI' -Recurse -Force
Install-Module PSPKI -RequiredVersion 3.7.2 -Force -AllowClobber -Scope AllUsers -SkipPublisherCheck
```

### 4. Locale no servidor de provisionamento

**Problema:** Servidores Linux minimalistas sem locale `en_US.UTF-8` causam falha do Ansible: `ERROR: Ansible requires the locale encoding to be UTF-8; Detected None`.

**Fix:** Prefixar todos os comandos ansible com `LANG=C.utf8 LC_ALL=C.utf8`.

### 5. main.yml — múltiplas execuções esperadas

O playbook `main.yml` precisa ser rodado 2-3 vezes consecutivas. Cada execução avança o estado conforme as VMs reiniciam e o AD propaga. Isso é comportamento normal — o playbook é idempotente.

---

## Créditos

- [Orange Cyberdefense — GOAD](https://github.com/Orange-Cyberdefense/GOAD)
- Documentação oficial: [https://orange-cyberdefense.github.io/GOAD/](https://orange-cyberdefense.github.io/GOAD/)
