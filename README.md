# Setup Workstation - Windows 🚀

Script de automação para preparação de estações de trabalho Windows na Golfleet. 
Este script altera o hostname, configura bloqueio de tela, instala aplicativos básicos (Chrome, Flameshot, Discord, Acrobat), e configura agentes de monitoramento (MeshCentral e Zabbix).

## 🛠️ Instalação

**Atenção:** Todos os comandos abaixo devem ser executados no **PowerShell como Administrador**. 
*(Clique no botão Iniciar > digite PowerShell > clique com o botão direito > Executar como Administrador).*

### 1. Instale o Git (caso a máquina seja nova e não tenha)
```powershell
winget install --id Git.Git -e --silent
```
*(Nota: Se o Git acabou de ser instalado, feche a janela do PowerShell e abra uma nova como Administrador para o sistema reconhecer o comando).*

### 2. Clone este repositório
```powershell
git clone [https://github.com/Golfleet/workstation-windows.git](https://github.com/Golfleet/workstation-windows.git)
```

### 3. Libere a permissão de execução e rode o script
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
.\workstation-windows\setup.ps1
```
### 4. Siga as instruções na tela
Durante a execução do script, o terminal fará pausas para que você preencha algumas informações obrigatórias:

-Novo Hostname da máquina.

-Senha da conta local de Administrador (a digitação ficará oculta por segurança).

-Usuário e Senha do repositório para download do MeshCentral.

### 5. Reinicialização
No final do processo, o script perguntará se você deseja reiniciar a máquina. Digite S para confirmar, garantindo que a troca do Hostname seja aplicada corretamente.
