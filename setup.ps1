# =====================================================================
# Script de Preparação de Estação de Trabalho Windows
# =====================================================================

# Exige execução como Administrador
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Por favor, execute o PowerShell como Administrador!"
    Break
}

Write-Host "Iniciando a configuração da máquina..." -ForegroundColor Cyan

# 1. Trocar Hostname
# =====================================================================
$novoNome = Read-Host "Digite o nome que será adicionado a esta máquina"
if (-not [string]::IsNullOrWhiteSpace($novoNome)) {
    Rename-Computer -NewName $novoNome -PassThru
    Write-Host "Hostname alterado para $novoNome (Requer reinicialização para aplicar totalmente)." -ForegroundColor Green
}

# 2. Alterar o plano de fundo
# =====================================================================
Write-Host "Baixando e aplicando o papel de parede..." -ForegroundColor Cyan
$urlWallpaper = "https://golfleet.com.br/wallpaper/golfleet1.png"
$caminhoWallpaper = "$env:USERPROFILE\Pictures\golfleet_wallpaper.png"

Invoke-WebRequest -Uri $urlWallpaper -OutFile $caminhoWallpaper

# Configura no registro (Aplica a configuração do Wallpaper)
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name Wallpaper -Value $caminhoWallpaper
# Atualiza a interface do usuário para refletir a mudança
rundll32.exe user32.dll, UpdatePerUserSystemParameters

# 3. Bloqueio de tela e Suspensão (5 minutos)
# =====================================================================
Write-Host "Configurando suspensão e bloqueio de tela para 5 minutos..." -ForegroundColor Cyan
# 5 Minutos de inatividade para apagar a tela e suspender (AC = Na tomada, DC = Na Bateria)
powercfg /change monitor-timeout-ac 5
powercfg /change monitor-timeout-dc 5
powercfg /change standby-timeout-ac 5
powercfg /change standby-timeout-dc 5

# Configura as chaves de registro para exigir senha e bloquear a tela (300 segundos = 5 minutos)
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveActive -Value "1"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaverIsSecure -Value "1"
Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name ScreenSaveTimeOut -Value "300"

# 4. Criar/Ativar usuário Administrador com senha segura
# =====================================================================
Write-Host "Configurando conta de Administrador..." -ForegroundColor Cyan

# Solicita a senha ao técnico de forma segura (não aparece na tela)
$SenhaSegura = Read-Host "Digite a senha para a conta de Administrador local" -AsSecureString
$NomeUsuario = "Administrador"

# Busca a conta para ver se ela já existe
$ContaAdmin = Get-LocalUser -Name $NomeUsuario -ErrorAction SilentlyContinue

if (-not $ContaAdmin) {
    Write-Host "Usuário '$NomeUsuario' não encontrado. Criando nova conta..." -ForegroundColor Yellow
    
    # Cria o usuário já com a senha configurada
    $ContaAdmin = New-LocalUser -Name $NomeUsuario -Password $SenhaSegura -FullName "Administrador Local" -Description "Conta com privilégios administrativos"
    
    # Adiciona o novo usuário ao grupo de Administradores (tenta em PT-BR e depois em EN)
    Add-LocalGroupMember -Group "Administradores" -Member $NomeUsuario -ErrorAction SilentlyContinue
    Add-LocalGroupMember -Group "Administrators" -Member $NomeUsuario -ErrorAction SilentlyContinue
    
    Write-Host "Usuário '$NomeUsuario' criado e adicionado ao grupo de Administradores com sucesso." -ForegroundColor Green
} else {
    # Se o usuário já existe (ex: a conta nativa do Windows), apenas atualiza a senha
    $ContaAdmin | Set-LocalUser -Password $SenhaSegura
    Write-Host "Usuário '$($ContaAdmin.Name)' já existe. Senha atualizada com sucesso." -ForegroundColor Green
}

# Garante que a conta seja ativada (tira o bloqueio)
$ContaAdmin | Enable-LocalUser
Write-Host "Conta '$($ContaAdmin.Name)' está ativa e pronta para uso." -ForegroundColor Green

# 5. Instalação de Aplicativos via Winget
# =====================================================================
Write-Host "Instalando aplicativos básicos..." -ForegroundColor Cyan
$apps = @(
    "Google.Chrome",
    "Flameshot.Flameshot",
    "Discord.Discord",
    "Adobe.Acrobat.Reader.64-bit"
)

foreach ($app in $apps) {
    Write-Host "Instalando $app..."
    winget install -e --id $app --accept-package-agreements --accept-source-agreements --silent
}

# 6. Desativar print padrão do Windows para liberar para o Flameshot
# =====================================================================
Write-Host "Desativando Captura de Esboço no botão PrintScreen..." -ForegroundColor Cyan
Set-ItemProperty -Path "HKCU:\Control Panel\Keyboard" -Name PrintScreenKeyForSnippingEnabled -Value 0 2>$null

# 7. Instalação do MeshCentral
# =====================================================================
Write-Host "Configurando o download do agente do MeshCentral..." -ForegroundColor Cyan

$meshUrl = "https://deb.golfleet.com.br/meshagent64-Windows-Consent.exe"
$meshInstaller = "$env:TEMP\meshagent64.exe"

# Solicita o usuário interativamente
$meshUser = Read-Host "Digite o usuário do repositório"

# Solicita a senha interativamente (a digitação ficará oculta na tela)
$secPass = Read-Host "Digite a senha do repositório" -AsSecureString

# Extrai a senha na memória temporária para montar o cabeçalho de autenticação
$meshPass = (New-Object System.Management.Automation.PSCredential ($meshUser, $secPass)).GetNetworkCredential().Password

# Força o formato de Autenticação Básica (Basic Auth) nativo da web
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $meshUser, $meshPass)))
$headers = @{ Authorization = ("Basic {0}" -f $base64AuthInfo) }

try {
    Write-Host "Iniciando o download..." -ForegroundColor Cyan
    # Faz o download passando o cabeçalho de autorização explícito
    Invoke-WebRequest -Uri $meshUrl -OutFile $meshInstaller -Headers $headers -ErrorAction Stop
    Write-Host "Download do MeshCentral concluído com sucesso!" -ForegroundColor Green
    
    Write-Host "Instalando o MeshCentral..." -ForegroundColor Cyan
    Start-Process -FilePath $meshInstaller -ArgumentList "-fullinstall" -Wait -NoNewWindow
}
catch {
    Write-Warning "Falha no download do MeshCentral. Verifique se o usuário e a senha informados estão corretos."
    Write-Warning "Detalhe do erro: $($_.Exception.Message)"
}

# 8. Instalação do Zabbix 
# =====================================================================
Write-Host "Configurando acesso ao servidor seguro de arquivos..." -ForegroundColor Cyan

# Solicita credenciais do repositório de arquivos de forma segura
$RepoUser = Read-Host "Digite o usuário do servidor de arquivos"
$RepoPass = Read-Host "Digite a senha do servidor de arquivos" -AsSecureString
$Cred = New-Object System.Management.Automation.PSCredential ($RepoUser, $RepoPass)

$repoUrl = "https://seu-servidor-de-arquivos.com.br"
$zabbixInstaller = "$env:TEMP\zabbix_agent2.msi"

# 1. Baixa e Instala o Zabbix "em branco"
Invoke-WebRequest -Uri "$repoUrl/zabbix_agent2.msi" -OutFile $zabbixInstaller -Credential $Cred
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$zabbixInstaller`" /qn" -Wait -NoNewWindow

# 2. Baixa o zabbix_agent2.conf do servidor seguro para a pasta do Zabbix no Windows
$caminhoConf = "C:\Program Files\Zabbix Agent 2\zabbix_agent2.conf"
Invoke-WebRequest -Uri "$repoUrl/zabbix/zabbix_agent2.conf" -OutFile $caminhoConf -Credential $Cred

# 3. Baixa o key.psk (se você utilizar criptografia)
$caminhoPsk = "C:\Program Files\Zabbix Agent 2\key.psk"
Invoke-WebRequest -Uri "$repoUrl/zabbix/key.psk" -OutFile $caminhoPsk -Credential $Cred

# 4. Reinicia o serviço para o Zabbix ler o novo arquivo .conf
Restart-Service -Name "Zabbix Agent 2" -ErrorAction SilentlyContinue

Write-Host "Zabbix configurado e arquivos protegidos importados." -ForegroundColor Green

# 9. Pergunta sobre a reinicialização
# =====================================================================
Write-Host ""
$resposta = Read-Host "Deseja reiniciar o computador agora para aplicar todas as configurações, como o novo hostname? (S/N)"

if ($resposta -eq 'S' -or $resposta -eq 's') {
    Write-Host "Reiniciando o sistema em 5 segundos..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    Restart-Computer -Force
} else {
    Write-Host "Reinicialização cancelada pelo usuário. Lembre-se de reiniciar o computador mais tarde." -ForegroundColor Cyan
}
