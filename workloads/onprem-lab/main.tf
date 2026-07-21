locals {
  prefix = "azr-${var.env}-${var.org}-${var.subcode_connectivity}"

  hub_resource_group_name = "${local.prefix}-rg-net-hub"
  hub_vnet_name           = "${local.prefix}-vnet-hub-core"
  hub_firewall_name       = "${local.prefix}-fw-hub"

  tags = {
    layer   = "workload"
    stage   = "onprem-lab"
    purpose = "fabric-hybrid-simulation"
    managed = "terraform"
  }

  sql_vm_name  = "${local.prefix}-vm-onprem-sql"
  opdg_vm_name = "${local.prefix}-vm-onprem-opdg"
}

data "azurerm_resource_group" "onprem" {
  name = var.onprem_resource_group_name
}

data "azurerm_subnet" "workload" {
  name                 = var.onprem_subnet_name
  resource_group_name  = data.azurerm_resource_group.onprem.name
  virtual_network_name = var.onprem_vnet_name
}

data "azurerm_virtual_network" "onprem" {
  name                = var.onprem_vnet_name
  resource_group_name = data.azurerm_resource_group.onprem.name
}

data "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  resource_group_name = local.hub_resource_group_name
}

data "azurerm_firewall" "hub" {
  name                = local.hub_firewall_name
  resource_group_name = local.hub_resource_group_name
}

# The simulated on-prem VNet is peered directly to the hub. Forwarded traffic
# allows the hub firewall to transit on-prem <-> workload-spoke flows.
resource "azurerm_virtual_network_peering" "onprem_to_hub" {
  name                         = "onprem-to-hub"
  resource_group_name          = data.azurerm_resource_group.onprem.name
  virtual_network_name         = data.azurerm_virtual_network.onprem.name
  remote_virtual_network_id    = data.azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "hub_to_onprem" {
  name                         = "hub-to-onprem"
  resource_group_name          = local.hub_resource_group_name
  virtual_network_name         = data.azurerm_virtual_network.hub.name
  remote_virtual_network_id    = data.azurerm_virtual_network.onprem.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_route_table" "workload" {
  name                          = "onprem-workload-rt"
  location                      = var.location
  resource_group_name           = data.azurerm_resource_group.onprem.name
  bgp_route_propagation_enabled = true
  tags                          = local.tags
}

resource "azurerm_route" "default_to_hub_firewall" {
  name                   = "default-to-hubfw"
  resource_group_name    = data.azurerm_resource_group.onprem.name
  route_table_name       = azurerm_route_table.workload.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_route" "fabric_spoke_via_firewall" {
  name                   = "spoke-via-fw"
  resource_group_name    = data.azurerm_resource_group.onprem.name
  route_table_name       = azurerm_route_table.workload.name
  address_prefix         = var.fabric_spoke_cidr
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = data.azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

resource "azurerm_subnet_route_table_association" "workload" {
  subnet_id      = data.azurerm_subnet.workload.id
  route_table_id = azurerm_route_table.workload.id
}

resource "random_password" "windows_admin" {
  length           = 24
  special          = true
  override_special = "!@#%*-_=+"
}

resource "random_password" "sql_gateway_login" {
  length           = 24
  special          = true
  override_special = "!@#%*-_=+"
}

locals {
  sql_admin_bootstrap_script = <<-POWERSHELL
    param([string]$SqlGatewayPassword, [string]$ValidationRevision)

    $ErrorActionPreference = "Stop"
    $sqlcmd = (Get-ChildItem "C:\Program Files\Microsoft SQL Server" -Filter sqlcmd.exe -Recurse | Select-Object -First 1).FullName
    if (-not $sqlcmd) { throw "sqlcmd.exe not found" }

    $databaseCreateQuery = "IF DB_ID(N'FabricHybridLab') IS NULL EXEC(N'CREATE DATABASE FabricHybridLab')"
    & $sqlcmd -S localhost -E -b -Q $databaseCreateQuery
    if ($LASTEXITCODE -ne 0) { throw "Database creation failed" }

    $loginQuery = "IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name=N'fabric_gateway') CREATE LOGIN fabric_gateway WITH PASSWORD='$SqlGatewayPassword', CHECK_POLICY=ON"
    & $sqlcmd -S localhost -E -b -Q $loginQuery
    if ($LASTEXITCODE -ne 0) { throw "Login creation failed" }

    $databaseQuery = "IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name=N'fabric_gateway') CREATE USER fabric_gateway FOR LOGIN fabric_gateway; IF IS_ROLEMEMBER(N'db_datareader',N'fabric_gateway') = 0 ALTER ROLE db_datareader ADD MEMBER fabric_gateway; IF OBJECT_ID(N'dbo.SalesOrders') IS NULL BEGIN CREATE TABLE dbo.SalesOrders (OrderId int NOT NULL PRIMARY KEY, CustomerName nvarchar(100) NOT NULL, OrderDate date NOT NULL, Amount decimal(12,2) NOT NULL); INSERT dbo.SalesOrders VALUES (1,N'Contoso Retail','2026-07-01',1250.00),(2,N'Fabrikam Stores','2026-07-02',875.50),(3,N'Adventure Works','2026-07-03',2199.99); END; IF (SELECT COUNT(*) FROM dbo.SalesOrders) <> 3 THROW 51000, 'Unexpected sample row count', 1"
    & $sqlcmd -S localhost -d FabricHybridLab -E -b -Q $databaseQuery
    if ($LASTEXITCODE -ne 0) { throw "Database object bootstrap failed" }

    $env:SQLCMDPASSWORD = $SqlGatewayPassword
    & $sqlcmd -S localhost -d FabricHybridLab -U fabric_gateway -b -Q "IF (SELECT COUNT(*) FROM dbo.SalesOrders) <> 3 THROW 51001, 'SQL login validation failed', 1"
    $sqlLoginExitCode = $LASTEXITCODE
    Remove-Item Env:\SQLCMDPASSWORD
    if ($sqlLoginExitCode -ne 0) { throw "SQL login authentication failed" }

    Write-Output "SQL_AUTH_VALIDATED_ROWS=3 REVISION=$ValidationRevision"
    Set-Content -Path C:\FabricHybridLab.ready -Value "SQL_READY"
  POWERSHELL

  opdg_stage_script = <<-POWERSHELL
    $ErrorActionPreference = "Stop"
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    $pwsh = "C:\Program Files\PowerShell\7\pwsh.exe"
    if (-not (Test-Path $pwsh)) {
      $msi = "C:\Windows\Temp\PowerShell-7.4.6-win-x64.msi"
      Invoke-WebRequest -Uri "https://github.com/PowerShell/PowerShell/releases/download/v7.4.6/PowerShell-7.4.6-win-x64.msi" -OutFile $msi
      Start-Process msiexec.exe -ArgumentList "/i",$msi,"/qn","/norestart" -Wait
    }
    if (-not (Test-Path $pwsh)) { throw "PowerShell 7.4 installation failed" }

    & $pwsh -NoProfile -Command "Set-PSRepository PSGallery -InstallationPolicy Trusted; Install-Module DataGateway -Force -AllowClobber; Import-Module DataGateway"
    if ($LASTEXITCODE -ne 0) { throw "DataGateway module staging failed" }

    $installerDirectory = "C:\Installers"
    $installerPath = "$installerDirectory\GatewayInstall.exe"
    New-Item -Path $installerDirectory -ItemType Directory -Force | Out-Null
    Invoke-WebRequest -Uri "https://go.microsoft.com/fwlink/?LinkId=2116849&clcid=0x409" -OutFile $installerPath
    if (-not (Test-Path $installerPath)) { throw "Gateway installer download failed" }
    Unblock-File -Path $installerPath
    Set-Content -Path C:\FabricGatewayInstaller.ready -Value "INSTALLER_STAGED_REGISTRATION_REQUIRED"
  POWERSHELL
}

resource "azurerm_network_security_group" "sql" {
  name                = "${local.sql_vm_name}-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  tags                = local.tags

  security_rule {
    name                       = "AllowSqlFromOpdg"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.opdg_private_ip
    destination_address_prefix = var.sql_private_ip
  }
}

resource "azurerm_network_security_group" "opdg" {
  name                = "${local.opdg_vm_name}-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  tags                = local.tags
}

resource "azurerm_network_interface" "sql" {
  name                = "${local.sql_vm_name}-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.sql_private_ip
  }
}

resource "azurerm_network_interface" "opdg" {
  name                = "${local.opdg_vm_name}-nic"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  tags                = local.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.workload.id
    private_ip_address_allocation = "Static"
    private_ip_address            = var.opdg_private_ip
  }
}

resource "azurerm_network_interface_security_group_association" "sql" {
  network_interface_id      = azurerm_network_interface.sql.id
  network_security_group_id = azurerm_network_security_group.sql.id
}

resource "azurerm_network_interface_security_group_association" "opdg" {
  network_interface_id      = azurerm_network_interface.opdg.id
  network_security_group_id = azurerm_network_security_group.opdg.id
}

resource "azurerm_windows_virtual_machine" "sql" {
  name                = local.sql_vm_name
  computer_name       = "onpremsql"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  size                = var.sql_vm_size
  admin_username      = var.windows_admin_username
  admin_password      = random_password.windows_admin.result
  network_interface_ids = [
    azurerm_network_interface.sql.id,
  ]
  provision_vm_agent        = true
  automatic_updates_enabled = true
  patch_mode                = "AutomaticByOS"
  tags                      = local.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftSQLServer"
    offer     = "sql2022-ws2022"
    sku       = "sqldev-gen2"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_windows_virtual_machine" "opdg" {
  name                = local.opdg_vm_name
  computer_name       = "onpremopdg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.onprem.name
  size                = var.opdg_vm_size
  admin_username      = var.windows_admin_username
  admin_password      = random_password.windows_admin.result
  network_interface_ids = [
    azurerm_network_interface.opdg.id,
  ]
  provision_vm_agent        = true
  automatic_updates_enabled = true
  patch_mode                = "AutomaticByOS"
  tags                      = local.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition-smalldisk"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_virtual_machine_extension" "sql_bootstrap" {
  name                       = "sql-lab-bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.sql.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true
  settings                   = jsonencode({})

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command \"$ErrorActionPreference='Stop'; Remove-Item C:\\FabricHybridLab.ready -Force -ErrorAction SilentlyContinue; Set-Service seclogon -StartupType Manual; Start-Service seclogon; $instancePath='HKLM:\\SOFTWARE\\Microsoft\\Microsoft SQL Server\\MSSQL16.MSSQLSERVER\\MSSQLServer'; Set-ItemProperty -Path $instancePath -Name LoginMode -Value 2; Set-ItemProperty -Path ($instancePath+'\\SuperSocketNetLib\\Tcp\\IPAll') -Name TcpDynamicPorts -Value ''; Set-ItemProperty -Path ($instancePath+'\\SuperSocketNetLib\\Tcp\\IPAll') -Name TcpPort -Value '1433'; Restart-Service MSSQLSERVER -Force; if(-not (Get-NetFirewallRule -DisplayName 'SQL from OPDG' -ErrorAction SilentlyContinue)){New-NetFirewallRule -DisplayName 'SQL from OPDG' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1433 -RemoteAddress '${var.opdg_private_ip}' | Out-Null}\""
  })

  tags = local.tags
}

resource "terraform_data" "sql_bootstrap_revision" {
  input = sha256(local.sql_admin_bootstrap_script)
}

resource "azurerm_virtual_machine_run_command" "sql_database_bootstrap" {
  name               = "sql-database-bootstrap"
  location           = var.location
  virtual_machine_id = azurerm_windows_virtual_machine.sql.id
  run_as_user        = var.windows_admin_username
  run_as_password    = random_password.windows_admin.result

  source {
    script = local.sql_admin_bootstrap_script
  }

  protected_parameter {
    name  = "SqlGatewayPassword"
    value = random_password.sql_gateway_login.result
  }

  parameter {
    name  = "ValidationRevision"
    value = "2"
  }

  tags = local.tags

  depends_on = [azurerm_virtual_machine_extension.sql_bootstrap]

  lifecycle {
    replace_triggered_by = [terraform_data.sql_bootstrap_revision]
  }
}

resource "azurerm_virtual_machine_extension" "opdg_bootstrap" {
  name                       = "opdg-lab-bootstrap"
  virtual_machine_id         = azurerm_windows_virtual_machine.opdg.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand ${textencodebase64(local.opdg_stage_script, "UTF-16LE")}"
  })

  tags = local.tags
}