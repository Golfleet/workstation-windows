# Setup Workstation - Windows 🚀

Script de automação para preparação de estações de trabalho Windows na Golfleet. 
Este script altera o hostname, configura bloqueio de tela, instala aplicativos básicos (Chrome, Flameshot, Discord, Acrobat), e configura agentes de monitoramento (MeshCentral e Zabbix).

## 🛠️ Instalação

**Atenção:** Todos os comandos abaixo devem ser executados no **PowerShell como Administrador**. 
*(Clique no botão Iniciar > digite PowerShell > clique com o botão direito > Executar como Administrador).*

### 1. Instale o Git (caso a máquina seja nova e não tenha)
```powershell
winget install --id Git.Git -e --silent

(Nota: Se o Git acabou de ser instalado, feche a janela do PowerShell e abra uma nova como Administrador para o sistema reconhecer o comando).
