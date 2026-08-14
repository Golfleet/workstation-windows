# =====================================================================
# Script de Preparação de Estação de Trabalho Windows (Golfleet)
# =====================================================================

# 1. Validação de Privilégios
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Por favor, execute o PowerShell como Administrador!"
    Break
}

# =====================================================================
# 2. COLETA DE INFORMAÇÕES (O técnico digita apenas uma vez)
# =====================================================================
Write-Host "--- PREPARAÇÃO DA MÁQUINA ---" -ForegroundColor Cyan
$novoNome = Read-Host "1. Digite o NOME que será adicionado a esta máquina"
$SenhaAdmin = Read-Host "2. Digite a SENHA para a conta de Administrador local" -AsSecureString

Write-Host "`n--- ACESSO AO REPOSITÓRIO GOLFLEET ---" -ForegroundColor Cyan
$RepoUser = Read-Host "3. Digite o USUÁRIO do deb.golfleet.com.br"
$RepoPass = Read-Host "4. Digite a SENHA do deb.golfleet.com.br" -AsSecureString

# Cria a credencial unificada que será usada no Mesh e no Zabbix
$CredenciaisRepo = New-Object System.Management.Automation.PSCredential ($RepoUser, $RepoPass)
$RepoUrl = "https://deb.golfleet.com.br"

Write-Host "`nIniciando a automação... Pode ir tomar um café! ☕" -ForegroundColor Green

# =====================================================================
# 3. Configurações do Sistema Operacional
# =====================================================================
if (-not [string]::IsNullOrWhiteSpace($novoNome)) {
    Rename-Computer -NewName $novoNome -PassThru | Out-Null
    Write-Host "[OK] Hostname alterado para: $novoNome" -ForegroundColor DarkGray
}

Write-Host "Configurando Wallpaper e Energia..." -ForegroundColor Cyan
$urlWallpaper = "https://golfleet.com.br/wallpaper/golfleet1.png"
$caminhoWallpaper = "$env:USERPROFILE\Pictures\golfleet_wallpaper.png"
Invoke-WebRequest -Uri $urlWallpaper -OutFile $caminhoWallpaper
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $caminhoWallpaper
rundll32.exe user32.dll, UpdatePerUserSystemParameters

powercfg /change monitor-timeout-ac 5
powercfg /change monitor-timeout-dc 5
powercfg /change standby-timeout-ac 5
powercfg /change standby-timeout-dc 5

# =====================================================================
# 4. Configurar Conta Administrador
# =====================================================================
$ContaAdmin = Get-LocalUser -Name "Administrador" -ErrorAction SilentlyContinue
if (-not $ContaAdmin) { $ContaAdmin = Get-LocalUser -Name "Administrator" -ErrorAction SilentlyContinue }

if ($ContaAdmin) {
    $ContaAdmin | Set-LocalUser -Password $SenhaAdmin
    $ContaAdmin | Enable-LocalUser
    Write-Host "[OK] Conta de Administrador ativada e configurada" -ForegroundColor DarkGray
}

# =====================================================================
# 5. Instalação de Aplicativos Básicos
# =====================================================================
Write-Host "Instalando aplicativos básicos..." -ForegroundColor Cyan
$apps = @("Google.Chrome", "Flameshot.Flameshot", "Discord.Discord", "Adobe.Acrobat.Reader.64-bit")
foreach ($app in $apps) {
    winget install -e --id $app --accept-package-agreements --accept-source-agreements --silent
}

# Criar atalho PWA para o 3CX
$url3CX = "https://golfleet.my3cx.com.br/#/login"
$WshShell = New-Object -comObject WScript.Shell
$caminhoAtalho = "$env:Public\Desktop\3CX.lnk"
$atalho = $WshShell.CreateShortcut($caminhoAtalho)
$atalho.TargetPath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$atalho.Arguments = "--app=$url3CX"
$atalho.IconLocation = "C:\Program Files\Google\Chrome\Application\chrome.exe, 0"
$atalho.Save()

# Desativar print padrão do Windows (liberar para Flameshot)
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name PrintScreenKeyForSnippingEnabled -Value 0 2>$null

# =====================================================================
# 6. Instalação Segura: Zabbix Agent 2
# =====================================================================
Write-Host "Instalando e configurando o Zabbix Agent 2..." -ForegroundColor Cyan

# 1. Força a criação da pasta para evitar erros de caminho
New-Item -ItemType Directory -Force -Path "C:\Program Files\Zabbix Agent 2" | Out-Null

# 2. Baixa o instalador MSI direto do link oficial validado
$zabbixUrl = "https://cdn.zabbix.com/zabbix/binaries/stable/6.4/6.4.13/zabbix_agent2-6.4.13-windows-amd64-openssl.msi"
$zabbixMsi = "$env:TEMP\zabbix_agent2.msi"
Invoke-WebRequest -Uri $zabbixUrl -OutFile $zabbixMsi

# 3. Instala o Zabbix silenciosamente 
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$zabbixMsi`" /qn" -Wait -NoNewWindow

# 4. Baixa as configurações seguras com os novos caminhos do servidor da Golfleet
$caminhoConf = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf"
Invoke-WebRequest -Uri "$RepoUrl/zabbix/win_zabbix_agent2.conf" -OutFile $caminhoConf -Credential $CredenciaisRepo

$caminhoPsk = "C:\Program Files\Zabbix Agent 2\key.psk"
Invoke-WebRequest -Uri "$RepoUrl/zabbix/key.psk" -OutFile $caminhoPsk -Credential $CredenciaisRepo

# 5. Reinicia o serviço para o Zabbix ler o novo arquivo de configuração e a chave
Restart-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue
Write-Host "[OK] Zabbix configurado e arquivos protegidos importados." -ForegroundColor DarkGray

# =====================================================================
# 7. Instalação Segura: MeshCentral
# =====================================================================
Write-Host "Baixando e instalando o MeshCentral..." -ForegroundColor Cyan
$meshInstaller = "$env:TEMP\meshagent64-Windows-Consent.exe"

# Reutiliza as mesmas credenciais para baixar o Mesh
Invoke-WebRequest -Uri "$RepoUrl/meshagent64-Windows-Consent.exe" -OutFile $meshInstaller -Credential $CredenciaisRepo
Start-Process -FilePath $meshInstaller -ArgumentList "-fullinstall" -Wait -NoNewWindow
Write-Host "[OK] MeshCentral instalado." -ForegroundColor DarkGray

Write-Host "===================================================" -ForegroundColor Cyan
Write-Host "PREPARACAO CONCLUIDA COM SUCESSO! Reinicie a maquina." -ForegroundColor Green
