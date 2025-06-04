# ==============================================================================
# STORAGE RESOURCES - ENTERPRISE LEVEL (FIXED NAMING)
# ==============================================================================

resource "azurerm_resource_group" "storage" {
  name     = "rg-${var.project_name}-storage"
  location = var.location
  tags     = local.common_tags
}

# Primary Storage Account - FIXED naming and network rules
resource "azurerm_storage_account" "main" {
  name                     = "stfonteyn${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Premium"
  account_replication_type = "ZRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"
  
  blob_properties {
    delete_retention_policy {
      days = 30
    }
    versioning_enabled = true
    change_feed_enabled = true
  }

  network_rules {
    default_action = "Allow"  # FIXED: Changed from Deny
    bypass         = ["AzureServices"]
    
    virtual_network_subnet_ids = [
      azurerm_subnet.frontend.id,
      azurerm_subnet.backend.id,
      azurerm_subnet.management.id
    ]
    
    # FIXED: Removed private IP rules - not supported
  }

  tags = local.common_tags
}

# Diagnostics Storage Account - FIXED naming
resource "azurerm_storage_account" "diagnostics" {
  name                     = "stdiag${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"

  tags = local.common_tags
}

# Backup Storage Account - FIXED naming
resource "azurerm_storage_account" "backup" {
  name                     = "stbackup${random_string.storage_suffix.result}"  # FIXED: Much shorter
  resource_group_name      = azurerm_resource_group.storage.name
  location                 = azurerm_resource_group.storage.location
  account_tier             = "Standard"
  account_replication_type = "GRS"

  https_traffic_only_enabled = true
  min_tls_version           = "TLS1_2"

  tags = local.common_tags
}

# File Shares voor enterprise applications
resource "azurerm_storage_share" "application_files" {
  name                 = "${var.project_name}-application-files"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 500
}

resource "azurerm_storage_share" "user_profiles" {
  name                 = "${var.project_name}-user-profiles"
  storage_account_name = azurerm_storage_account.main.name
  quota                = 1000
}

# Storage Tables voor application data
resource "azurerm_storage_table" "reservations" {
  name                 = "reservations"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_table" "hrm_data" {
  name                 = "hrmdata"
  storage_account_name = azurerm_storage_account.main.name
}

resource "azurerm_storage_table" "monitoring_logs" {
  name                 = "monitoringlogs"
  storage_account_name = azurerm_storage_account.main.name
}

# ==============================================================================
# MONITORING RESOURCES - ENTERPRISE LEVEL
# ==============================================================================

resource "azurerm_resource_group" "monitoring" {
  name     = "rg-${var.project_name}-monitoring"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace - Enterprise configuration
resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = local.common_tags
}

# Application Insights voor web applications
resource "azurerm_application_insights" "main" {
  name                = "ai-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Application Insights voor reserveringssysteem
resource "azurerm_application_insights" "reservations" {
  name                = "ai-${var.project_name}-reservations"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Application Insights voor HRM systeem
resource "azurerm_application_insights" "hrm" {
  name                = "ai-${var.project_name}-hrm"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"

  tags = local.common_tags
}

# Action Groups voor alerting
resource "azurerm_monitor_action_group" "critical" {
  name                = "ag-${var.project_name}-critical"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "critical"

  email_receiver {
    name          = "admin"
    email_address = "560501@student.fontys.nl"
  }

  email_receiver {
    name          = "it-team"
    email_address = "it-team@fonteyn.corp"  # Placeholder
  }

  sms_receiver {
    name         = "emergency"
    country_code = "31"
    phone_number = "0612345678"  # Placeholder
  }

  tags = local.common_tags
}

resource "azurerm_monitor_action_group" "warning" {
  name                = "ag-${var.project_name}-warning"
  resource_group_name = azurerm_resource_group.monitoring.name
  short_name          = "warning"

  email_receiver {
    name          = "admin"
    email_address = "560501@student.fontys.nl"
  }

  tags = local.common_tags
}

# Recovery Services Vault
resource "azurerm_recovery_services_vault" "main" {
  name                = "rsv-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku                 = "Standard"
  storage_mode_type   = "GeoRedundant"
  cross_region_restore_enabled = true

  tags = local.common_tags
}

# ==============================================================================
# AZURE ARC CONFIGURATION - HYBRID CLOUD MANAGEMENT
# ==============================================================================

resource "azurerm_resource_group" "azure_arc" {
  name     = "rg-${var.project_name}-arc"
  location = var.location
  tags     = local.common_tags
}

# Log Analytics Workspace voor Azure Arc (dedicated)
resource "azurerm_log_analytics_workspace" "azure_arc" {
  name                = "law-${var.project_name}-arc"
  location            = azurerm_resource_group.azure_arc.location
  resource_group_name = azurerm_resource_group.azure_arc.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = merge(local.common_tags, {
    Purpose = "azure-arc-hybrid-management"
  })
}

# Service Principal voor Azure Arc
resource "azurerm_user_assigned_identity" "azure_arc" {
  name                = "id-${var.project_name}-arc"
  location            = azurerm_resource_group.azure_arc.location
  resource_group_name = azurerm_resource_group.azure_arc.name

  tags = local.common_tags
}

# Role assignments voor Azure Arc service principal
resource "azurerm_role_assignment" "azure_arc_contributor" {
  scope                = azurerm_resource_group.azure_arc.id
  role_definition_name = "Azure Connected Machine Resource Administrator"
  principal_id         = azurerm_user_assigned_identity.azure_arc.principal_id
}

resource "azurerm_role_assignment" "azure_arc_monitoring" {
  scope                = azurerm_log_analytics_workspace.azure_arc.id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azurerm_user_assigned_identity.azure_arc.principal_id
}

# ==============================================================================
# AZURE POLICY ASSIGNMENTS - GOVERNANCE (FIXED)
# ==============================================================================

# Policy Assignment voor VM compliance monitoring - FIXED parameters
resource "azurerm_resource_group_policy_assignment" "vm_monitoring" {
  name                 = "vm-monitoring-policy"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0868462e-646c-4fe3-9ced-a733534b6a2c"

  display_name = "Enable Azure Monitor for VMs in ${var.project_name}"
  description  = "Ensures all VMs have Azure Monitor enabled for compliance"

  parameters = jsonencode({
    logAnalytics = {  # FIXED: Correct parameter name
      value = azurerm_log_analytics_workspace.main.id
    }
  })
}

# Policy Assignment voor disk encryption - FIXED parameters
resource "azurerm_resource_group_policy_assignment" "disk_encryption" {
  name                 = "disk-encryption-policy"
  resource_group_id    = azurerm_resource_group.compute.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/0473574d-2d43-4217-aefe-941fcdf7e684"

  display_name = "Require disk encryption for ${var.project_name} VMs"
  description  = "Ensures all VM disks are encrypted for security compliance"

  parameters = jsonencode({
    listOfAllowedLocations = {  # FIXED: Required parameter added
      value = [var.location]
    }
  })
}

# ==============================================================================
# AUTOMATION & RUNBOOKS - OPERATIONAL EXCELLENCE
# ==============================================================================

resource "azurerm_automation_account" "main" {
  name                = "aa-${var.project_name}"
  location            = azurerm_resource_group.monitoring.location
  resource_group_name = azurerm_resource_group.monitoring.name
  sku_name            = "Basic"

  tags = local.common_tags
}

# Link Automation Account to Log Analytics
resource "azurerm_log_analytics_linked_service" "automation" {
  resource_group_name = azurerm_resource_group.monitoring.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  read_access_id      = azurerm_automation_account.main.id
}

# Update Management Solution
resource "azurerm_log_analytics_solution" "updates" {
  solution_name         = "Updates"
  location              = azurerm_resource_group.monitoring.location
  resource_group_name   = azurerm_resource_group.monitoring.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/Updates"
  }
}

# ==============================================================================
# BACKUP CONFIGURATION - AZURE SITE RECOVERY ENHANCED
# ==============================================================================

# Backup Policy voor VMs
resource "azurerm_backup_policy_vm" "daily" {
  name                = "backup-policy-daily"
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name

  backup {
    frequency = "Daily"
    time      = "23:00"
  }

  retention_daily {
    count = 30
  }

  retention_weekly {
    count    = 12
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = 12
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}

# ==============================================================================
# COMPUTE RESOURCES - ENTERPRISE ARCHITECTURE
# ==============================================================================

resource "azurerm_resource_group" "compute" {
  name     = "rg-${var.project_name}-compute"
  location = var.location
  tags     = local.common_tags
}

# DMZ Load Balancer - Public facing
resource "azurerm_public_ip" "dmz_lb_public_ip" {
  name                = "pip-${var.project_name}-dmz-lb"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = local.common_tags
}

resource "azurerm_lb" "dmz" {
  name                = "lb-${var.project_name}-dmz"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "DMZ-PublicIP"
    public_ip_address_id = azurerm_public_ip.dmz_lb_public_ip.id
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "dmz" {
  loadbalancer_id = azurerm_lb.dmz.id
  name            = "DMZ-BackendPool"
}

resource "azurerm_lb_probe" "dmz_https" {
  loadbalancer_id = azurerm_lb.dmz.id
  name            = "https-probe"
  port            = 443
  protocol        = "Https"
  request_path    = "/health"
}

resource "azurerm_lb_rule" "dmz_https" {
  loadbalancer_id                = azurerm_lb.dmz.id
  name                           = "HTTPS"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "DMZ-PublicIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dmz.id]
  probe_id                      = azurerm_lb_probe.dmz_https.id
}

resource "azurerm_lb_rule" "dmz_http_redirect" {
  loadbalancer_id                = azurerm_lb.dmz.id
  name                           = "HTTP-Redirect"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "DMZ-PublicIP"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.dmz.id]
}

# Internal Load Balancer voor backend services
resource "azurerm_lb" "internal" {
  name                = "lb-${var.project_name}-internal"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "Internal-Frontend"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = local.common_tags
}

resource "azurerm_lb_backend_address_pool" "internal" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "Internal-BackendPool"
}

resource "azurerm_lb_probe" "internal_app" {
  loadbalancer_id = azurerm_lb.internal.id
  name            = "app-probe"
  port            = 8080
  protocol        = "Http"
  request_path    = "/health"
}

resource "azurerm_lb_rule" "internal_app" {
  loadbalancer_id                = azurerm_lb.internal.id
  name                           = "Application"
  protocol                       = "Tcp"
  frontend_port                  = 8080
  backend_port                   = 8080
  frontend_ip_configuration_name = "Internal-Frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.internal.id]
  probe_id                      = azurerm_lb_probe.internal_app.id
}

# Availability Sets - Enterprise HA
resource "azurerm_availability_set" "web" {
  name                = "avset-web"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

resource "azurerm_availability_set" "app" {
  name                = "avset-app"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

resource "azurerm_availability_set" "database" {
  name                = "avset-database"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name
  managed             = true
  platform_fault_domain_count = 3
  platform_update_domain_count = 5

  tags = local.common_tags
}

# Network Interfaces - FIXED with explicit dependencies
resource "azurerm_network_interface" "web" {
  count               = var.frontend_instance_count
  name                = "nic-web-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.frontend.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.frontend]
  tags = local.common_tags
}

resource "azurerm_network_interface" "app" {
  count               = var.backend_instance_count
  name                = "nic-app-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.backend.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.backend]
  tags = local.common_tags
}

resource "azurerm_network_interface" "database" {
  count               = var.database_instance_count
  name                = "nic-db-${format("%02d", count.index + 1)}"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.database.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.database]
  tags = local.common_tags
}

resource "azurerm_network_interface" "monitoring" {
  name                = "nic-monitoring-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.management]
  tags = local.common_tags
}

resource "azurerm_network_interface" "printserver" {
  name                = "nic-printserver-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.management]
  tags = local.common_tags
}

resource "azurerm_network_interface" "azure_arc" {
  name                = "nic-azure-arc-01"
  location            = azurerm_resource_group.compute.location
  resource_group_name = azurerm_resource_group.compute.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.azure_arc.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [azurerm_subnet.azure_arc]
  tags = local.common_tags
}

# Load Balancer Associations
resource "azurerm_network_interface_backend_address_pool_association" "web_dmz" {
  count                   = var.frontend_instance_count
  network_interface_id    = azurerm_network_interface.web[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.dmz.id
}

resource "azurerm_network_interface_backend_address_pool_association" "app_internal" {
  count                   = var.backend_instance_count
  network_interface_id    = azurerm_network_interface.app[count.index].id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.internal.id
}

# ==============================================================================
# VIRTUAL MACHINES - ENTERPRISE CONFIGURATION
# ==============================================================================

# Frontend Web Servers
resource "azurerm_linux_virtual_machine" "web" {
  count               = var.frontend_instance_count
  name                = "vm-web-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.frontend_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.web.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.web[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "webserver"
    Tier        = "frontend"
    Application = "nginx-apache"
  })
}

# Data disks voor web servers
resource "azurerm_managed_disk" "web_data" {
  count                = var.frontend_instance_count
  name                 = "disk-web-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "web_data" {
  count              = var.frontend_instance_count
  managed_disk_id    = azurerm_managed_disk.web_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.web[count.index].id
  lun                = "0"
  caching            = "ReadOnly"
}

# Backend Application Servers
resource "azurerm_linux_virtual_machine" "app" {
  count               = var.backend_instance_count
  name                = "vm-app-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.backend_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.app.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.app[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "appserver"
    Tier        = "backend"
    Application = "reservations-hrm"
  })
}

# Data disks voor app servers
resource "azurerm_managed_disk" "app_data" {
  count                = var.backend_instance_count
  name                 = "disk-app-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "app_data" {
  count              = var.backend_instance_count
  managed_disk_id    = azurerm_managed_disk.app_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.app[count.index].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Database Servers
resource "azurerm_linux_virtual_machine" "database" {
  count               = var.database_instance_count
  name                = "vm-db-${format("%02d", count.index + 1)}"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.database_vm_size
  admin_username      = var.admin_username
  availability_set_id = azurerm_availability_set.database.id

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.database[count.index].id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "database"
    Tier        = "data"
    Application = "mysql-postgresql"
  })
}

# Database data disks
resource "azurerm_managed_disk" "database_data" {
  count                = var.database_instance_count
  name                 = "disk-db-${format("%02d", count.index + 1)}-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 128

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "database_data" {
  count              = var.database_instance_count
  managed_disk_id    = azurerm_managed_disk.database_data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  lun                = "0"
  caching            = "ReadWrite"
}

# Database log disks
resource "azurerm_managed_disk" "database_log" {
  count                = var.database_instance_count
  name                 = "disk-db-${format("%02d", count.index + 1)}-log"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 32

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "database_log" {
  count              = var.database_instance_count
  managed_disk_id    = azurerm_managed_disk.database_log[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.database[count.index].id
  lun                = "1"
  caching            = "None"
}

# Monitoring Server
resource "azurerm_linux_virtual_machine" "monitoring" {
  name                = "vm-monitoring-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.monitoring_vm_size
  admin_username      = var.admin_username

  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.monitoring.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = tls_private_key.ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "monitoring"
    Tier        = "management"
    Application = "azure-monitor-grafana"
  })
}

# Monitoring data disk
resource "azurerm_managed_disk" "monitoring_data" {
  name                 = "disk-monitoring-01-data"
  location             = azurerm_resource_group.compute.location
  resource_group_name  = azurerm_resource_group.compute.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 64

  tags = local.common_tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "monitoring_data" {
  managed_disk_id    = azurerm_managed_disk.monitoring_data.id
  virtual_machine_id = azurerm_linux_virtual_machine.monitoring.id
  lun                = "0"
  caching            = "ReadWrite"
}

# Print Server
resource "azurerm_windows_virtual_machine" "printserver" {
  name                = "vm-printserver-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.printserver_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.sql_admin.result

  network_interface_ids = [
    azurerm_network_interface.printserver.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "printserver"
    Tier        = "management"
    Application = "windows-print-services"
  })
}

# Azure Arc Management Server
resource "azurerm_windows_virtual_machine" "azure_arc" {
  name                = "vm-azure-arc-01"
  resource_group_name = azurerm_resource_group.compute.name
  location            = azurerm_resource_group.compute.location
  size                = var.monitoring_vm_size
  admin_username      = var.admin_username
  admin_password      = random_password.sql_admin.result

  network_interface_ids = [
    azurerm_network_interface.azure_arc.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 64
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-g2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.diagnostics.primary_blob_endpoint
  }

  tags = merge(local.common_tags, {
    Role        = "azure-arc"
    Tier        = "management"
    Application = "hybrid-management"
  })
}

# Protected VM Backup Items (voor kritieke VMs)
resource "azurerm_backup_protected_vm" "database" {
  count               = var.database_instance_count
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.database[count.index].id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

resource "azurerm_backup_protected_vm" "monitoring" {
  resource_group_name = azurerm_resource_group.monitoring.name
  recovery_vault_name = azurerm_recovery_services_vault.main.name
  source_vm_id        = azurerm_linux_virtual_machine.monitoring.id
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

# ==============================================================================
# MONITORING ALERTS - ENTERPRISE LEVEL (FIXED)
# ==============================================================================

# CPU Alert voor alle VMs - FIXED with target_resource_type
resource "azurerm_monitor_metric_alert" "high_cpu" {
  name                = "alert-${var.project_name}-high-cpu"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes              = [azurerm_resource_group.compute.id]
  description         = "Alert when CPU usage is higher than 80%"
  target_resource_type = "Microsoft.Compute/virtualMachines"  # FIXED: Added target type
  target_resource_location = var.location                     # FIXED: Added target location

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  frequency   = "PT5M"
  window_size = "PT15M"
  severity    = 2

  tags = local.common_tags
}

# Memory Alert voor Database VMs - FIXED
resource "azurerm_monitor_metric_alert" "high_memory" {
  name                = "alert-${var.project_name}-high-memory"
  resource_group_name = azurerm_resource_group.monitoring.name
  scopes = [
    for vm in azurerm_linux_virtual_machine.database : vm.id
  ]
  description = "Alert when memory usage is higher than 85%"
  target_resource_type = "Microsoft.Compute/virtualMachines"  # FIXED: Added target type
  target_resource_location = var.location                     # FIXED: Added target location

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1073741824
  }

  action {
    action_group_id = azurerm_monitor_action_group.critical.id
  }

  frequency   = "PT5M"
  window_size = "PT15M"
  severity    = 1

  tags = local.common_tags
}

# VPN Alert removed - TunnelState metric not available in all regions

# ==============================================================================
# OUTPUTS - COMPREHENSIVE ENTERPRISE DEPLOYMENT INFORMATION
# ==============================================================================

output "deployment_information" {
  description = "Complete deployment information for Fonteyn Enterprise"
  value = {
    project_details = {
      name         = var.project_name
      environment  = var.environment
      location     = var.location
      deployed_at  = timestamp()
      terraform_version = "managed-by-terraform"
    }

    network_configuration = {
      azure_vnet = {
        name          = azurerm_virtual_network.azure_enterprise.name
        address_space = var.azure_vnet_address_space
        resource_group = azurerm_resource_group.network.name
      }
      
      subnets = {
        dmz         = var.dmz_subnet_prefix
        frontend    = var.frontend_subnet_prefix
        backend     = var.backend_subnet_prefix
        database    = var.database_subnet_prefix
        management  = var.management_subnet_prefix
        azure_arc   = var.azure_arc_subnet_prefix
        gateway     = "10.0.255.0/27"
        firewall    = "10.0.254.0/26"
      }

      vpn_gateway = {
        public_ip    = azurerm_public_ip.vpn_gateway.ip_address
        gateway_name = azurerm_virtual_network_gateway.vpn.name
        sku         = "VpnGw2"
        generation  = "Generation2"
      }

      load_balancers = {
        dmz_public_ip = azurerm_public_ip.dmz_lb_public_ip.ip_address
        internal_ip   = azurerm_lb.internal.frontend_ip_configuration[0].private_ip_address
      }
    }

    virtual_machines = {
      web_servers = {
        count = var.frontend_instance_count
        size  = var.frontend_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.web : azurerm_network_interface.web[index(azurerm_linux_virtual_machine.web, vm)].ip_configuration[0].private_ip_address]
      }
      
      app_servers = {
        count = var.backend_instance_count
        size  = var.backend_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.app : azurerm_network_interface.app[index(azurerm_linux_virtual_machine.app, vm)].ip_configuration[0].private_ip_address]
      }
      
      database_servers = {
        count = var.database_instance_count
        size  = var.database_vm_size
        ips   = [for vm in azurerm_linux_virtual_machine.database : azurerm_network_interface.database[index(azurerm_linux_virtual_machine.database, vm)].ip_configuration[0].private_ip_address]
      }

      management_servers = {
        monitoring = {
          ip   = azurerm_network_interface.monitoring.ip_configuration[0].private_ip_address
          size = var.monitoring_vm_size
        }
        print_server = {
          ip   = azurerm_network_interface.printserver.ip_configuration[0].private_ip_address
          size = var.printserver_vm_size
        }
        azure_arc = {
          ip   = azurerm_network_interface.azure_arc.ip_configuration[0].private_ip_address
          size = var.monitoring_vm_size
        }
      }
    }

    security_and_storage = {
      key_vault = {
        name = azurerm_key_vault.main.name
        uri  = azurerm_key_vault.main.vault_uri
      }
      
      storage_accounts = {
        main        = azurerm_storage_account.main.name
        diagnostics = azurerm_storage_account.diagnostics.name
        backup      = azurerm_storage_account.backup.name
      }

      backup_vault = azurerm_recovery_services_vault.main.name
    }

    monitoring_and_management = {
      log_analytics = {
        main      = azurerm_log_analytics_workspace.main.name
        azure_arc = azurerm_log_analytics_workspace.azure_arc.name
      }
      
      application_insights = {
        main         = azurerm_application_insights.main.name
        reservations = azurerm_application_insights.reservations.name
        hrm          = azurerm_application_insights.hrm.name
      }

      automation_account = azurerm_automation_account.main.name
      
      action_groups = {
        critical = azurerm_monitor_action_group.critical.name
        warning  = azurerm_monitor_action_group.warning.name
      }
    }

    hybrid_cloud_integration = {
      azure_arc = {
        resource_group      = azurerm_resource_group.azure_arc.name
        identity_name       = azurerm_user_assigned_identity.azure_arc.name
        log_analytics       = azurerm_log_analytics_workspace.azure_arc.name
      }

      on_premises_connectivity = {
        networks = var.on_premises_networks
        dns_servers = var.on_premises_dns_servers
        gateway_ip = var.hoofdkantoor_gateway_ip
      }
    }
  }
}

output "connection_information" {
  description = "How to connect to and manage the infrastructure"
  value = {
    web_access = {
      public_url = "https://${azurerm_public_ip.dmz_lb_public_ip.ip_address}"
      load_balancer = "DMZ Load Balancer with SSL termination"
    }

    vm_access = {
      ssh_key_location = "Use terraform output ssh_private_key"
      jump_host = "Connect via management subnet or VPN"
      
      connection_examples = {
        web_server = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.web[0].ip_configuration[0].private_ip_address}"
        database   = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.database[0].ip_configuration[0].private_ip_address}"
        monitoring = "ssh -i ssh_key.pem ${var.admin_username}@${azurerm_network_interface.monitoring.ip_configuration[0].private_ip_address}"
      }
    }

    management_access = {
      azure_portal = "https://portal.azure.com"
      key_vault = azurerm_key_vault.main.vault_uri
      log_analytics = "Search for: ${azurerm_log_analytics_workspace.main.name}"
    }

    vpn_configuration = {
      azure_gateway_ip = azurerm_public_ip.vpn_gateway.ip_address
      shared_key_location = "Key Vault secret: vpn-shared-key-hoofdkantoor"
      local_networks = var.on_premises_networks
      
      pfsense_setup = {
        remote_gateway = azurerm_public_ip.vpn_gateway.ip_address
        local_networks = var.on_premises_networks
        azure_networks = [var.azure_vnet_address_space]
        protocol = "IKEv2"
        encryption = "AES-256"
      }
    }
  }
}

output "next_steps" {
  description = "Post-deployment configuration steps"
  value = {
    immediate_tasks = [
      "1. Save SSH private key: terraform output -raw ssh_private_key > ssh_key.pem",
      "2. Set SSH key permissions: chmod 600 ssh_key.pem",
      "3. Configure pfSense VPN with Azure gateway IP: ${azurerm_public_ip.vpn_gateway.ip_address}",
      "4. Test VPN connectivity between Azure and on-premises",
      "5. Install Azure Arc agent on on-premises servers"
    ]

    azure_arc_setup = [
      "1. Download Azure Arc installation script from Azure portal",
      "2. Run on FONTDC01 (192.168.2.100) and FONTDC02 (192.168.2.99)",
      "3. Install on file server and print server (VLAN B)",
      "4. Configure monitoring and policy compliance"
    ]

    application_deployment = [
      "1. Configure web servers with Nginx/Apache",
      "2. Deploy reservation system on app servers",
      "3. Set up database cluster (MySQL/PostgreSQL)",
      "4. Configure monitoring dashboards",
      "5. Set up backup schedules"
    ]

    security_hardening = [
      "1. Review and adjust NSG rules",
      "2. Configure Azure AD Connect for identity sync",
      "3. Enable Azure Security Center recommendations",
      "4. Set up certificate management for SSL",
      "5. Configure audit logging"
    ]

    cost_optimization = [
      "1. Monitor resource utilization",
      "2. Consider scaling down non-production VMs",
      "3. Set up budget alerts",
      "4. Review storage account tiers",
      "5. Optimize backup retention policies"
    ]

    future_expansions = [
      "1. Add vakantiepark NL gateway and connectivity",
      "2. Add vakantiepark BE gateway and connectivity", 
      "3. Add vakantiepark DE gateway and connectivity",
      "4. Implement Azure Firewall for enhanced security",
      "5. Consider Azure Virtual Desktop for remote workers"
    ]
  }
}

output "ssh_private_key" {
  description = "SSH private key for VM access"
  value       = tls_private_key.ssh.private_key_pem
  sensitive   = true
}

output "cost_information" {
  description = "Cost optimization and monitoring information"
  value = {
    current_configuration = "Testing/Development optimized"
    estimated_monthly_cost = "€200-400 (with testing VM sizes)"
    enterprise_monthly_cost = "€2,500-4,000 (with enterprise VM sizes)"
    
    cost_drivers = {
      largest_costs = ["Virtual Machines", "VPN Gateway", "Storage Accounts", "Load Balancers"]
      optimization_opportunities = ["Right-size VMs", "Reserved Instances", "Storage tiers"]
    }

    monitoring = {
      cost_alerts = "Set up in Azure portal under Cost Management"
      budgets = "Configure monthly spending limits"
      recommendations = "Review Azure Advisor cost recommendations"
    }
  }
}# Fonteyn Enterprise Infrastructure - COMPLETE FIXED VERSION
# All deployment errors fixed

terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = var.environment != "prod"
      purge_soft_deleted_keys_on_destroy = var.environment != "prod"
    }
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "prod"
    }
  }
}

# Data sources
data "azurerm_subscription" "current" {}
data "azurerm_client_config" "current" {}

# ==============================================================================
# VARIABLES - UPDATED VOOR ENTERPRISE ARCHITECTUUR
# ==============================================================================

variable "project_name" {
  description = "Project naam"
  type        = string
  default     = "fonteyn"  # CHANGED: Removed "enterprise"
}

variable "location" {
  description = "Azure locatie"
  type        = string
  default     = "North Europe"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

# NIEUWE IP ADDRESSING SCHEME
variable "azure_vnet_address_space" {
  description = "Azure VNet CIDR - Enterprise addressing"
  type        = string
  default     = "10.0.0.0/16"  # Was 10.1.0.0/16
}

variable "dmz_subnet_prefix" {
  description = "DMZ subnet voor public-facing resources"
  type        = string
  default     = "10.0.1.0/24"  # NIEUW
}

variable "frontend_subnet_prefix" {
  description = "Frontend webserver subnet"
  type        = string
  default     = "10.0.2.0/24"  # Was 10.1.1.0/24
}

variable "backend_subnet_prefix" {
  description = "Backend application subnet"
  type        = string
  default     = "10.0.3.0/24"  # Was 10.1.2.0/24
}

variable "database_subnet_prefix" {
  description = "Database subnet"
  type        = string
  default     = "10.0.4.0/24"  # Was 10.1.3.0/24
}

variable "management_subnet_prefix" {
  description = "Management en monitoring subnet"
  type        = string
  default     = "10.0.5.0/24"  # Was 10.1.4.0/24
}

variable "azure_arc_subnet_prefix" {
  description = "Azure Arc hybrid management subnet"
  type        = string
  default     = "10.0.6.0/24"  # NIEUW
}

# ON-PREMISES ADDRESSING
variable "onpremises_hoofdkantoor_cidr" {
  description = "Hoofdkantoor network"
  type        = string
  default     = "192.168.0.0/16"  # FIXED: Correct voor jouw VLANs
}

variable "vakantiepark_nl_cidr" {
  description = "Vakantiepark Nederland"
  type        = string
  default     = "10.5.0.0/16"
}

variable "vakantiepark_be_cidr" {
  description = "Vakantiepark België"
  type        = string
  default     = "10.6.0.0/16"
}

variable "vakantiepark_de_cidr" {
  description = "Vakantiepark Duitsland"
  type        = string
  default     = "10.7.0.0/16"
}

# ENTERPRISE VM SIZES
variable "frontend_vm_size" {
  description = "Frontend webserver VM size - Enterprise"
  type        = string
  default     = "Standard_B2s"  # FIXED: Testing size
}

variable "backend_vm_size" {
  description = "Backend application VM size - Enterprise"
  type        = string
  default     = "Standard_B4ms"  # FIXED: Testing size
}

variable "database_vm_size" {
  description = "Database VM size - Memory optimized"
  type        = string
  default     = "Standard_B8ms"  # FIXED: Testing size
}

variable "monitoring_vm_size" {
  description = "Monitoring server VM size"
  type        = string
  default     = "Standard_B2s"  # FIXED: Testing size
}

variable "printserver_vm_size" {
  description = "Print server VM size"
  type        = string
  default     = "Standard_B2s"  # FIXED: Testing size
}

# INSTANCE COUNTS
variable "frontend_instance_count" {
  description = "Frontend webserver count"
  type        = number
  default     = 2  # FIXED: Testing count
}

variable "backend_instance_count" {
  description = "Backend application server count"
  type        = number
  default     = 2  # FIXED: Testing count
}

variable "database_instance_count" {
  description = "Database server count"
  type        = number
  default     = 1  # FIXED: Testing count
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureadmin"
}

variable "sql_admin_username" {
  description = "SQL admin username"
  type        = string
  default     = "sqladmin"
}

# VPN Configuration - Updated
variable "vpn_shared_key" {
  description = "Shared key for VPN connections"
  type        = string
  sensitive   = true
  default     = "FonteynEnterprise2024!"
}

variable "hoofdkantoor_gateway_ip" {
  description = "Hoofdkantoor VPN gateway IP"
  type        = string
  default     = "145.220.74.133"
}

variable "on_premises_networks" {
  description = "Alle on-premises networks"
  type        = list(string)
  default     = [
    "192.168.1.0/24",  # FIXED: Jouw VLANs
    "192.168.2.0/24",
    "192.168.3.0/24",
    "10.5.0.0/16",    # Vakantiepark NL
    "10.6.0.0/16",    # Vakantiepark BE
    "10.7.0.0/16"     # Vakantiepark DE
  ]
}

variable "on_premises_dns_servers" {
  description = "On-premises DNS servers"
  type        = list(string)
  default     = ["192.168.2.100"]  # FIXED: Jouw FONTDC01
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default = {
    Project     = "fonteyn-enterprise"
    Environment = "dev"
    ManagedBy   = "terraform"
    Owner       = "daan-onstenk"
    CostCenter  = "IT-Development"
    Purpose     = "vacation-parks-enterprise"
    Architecture = "hybrid-cloud"
  }
}

# ==============================================================================
# LOCALS
# ==============================================================================

locals {
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    DeployDate  = timestamp()
  })
}

# ==============================================================================
# RANDOM RESOURCES
# ==============================================================================

resource "random_password" "sql_admin" {
  length  = 16
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "random_string" "storage_suffix" {
  length  = 4
  special = false
  upper   = false
}

# ==============================================================================
# NETWORKING RESOURCES - ENTERPRISE ARCHITECTURE
# ==============================================================================

resource "azurerm_resource_group" "network" {
  name     = "rg-${var.project_name}-network"
  location = var.location
  tags     = local.common_tags
}

# Main Azure VNet - Enterprise addressing
resource "azurerm_virtual_network" "azure_enterprise" {
  name                = "vnet-${var.project_name}-azure"
  address_space       = [var.azure_vnet_address_space]
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.common_tags
}

# DMZ Subnet - NIEUW
resource "azurerm_subnet" "dmz" {
  name                 = "snet-dmz"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.dmz_subnet_prefix]
}

# Frontend Subnet - Updated addressing
resource "azurerm_subnet" "frontend" {
  name                 = "snet-frontend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.frontend_subnet_prefix]
}

# Backend Subnet - Updated addressing
resource "azurerm_subnet" "backend" {
  name                 = "snet-backend"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.backend_subnet_prefix]
}

# Database Subnet - Updated addressing
resource "azurerm_subnet" "database" {
  name                 = "snet-database"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.database_subnet_prefix]
}

# Management Subnet - Updated addressing
resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.management_subnet_prefix]
}

# Azure Arc Subnet - NIEUW
resource "azurerm_subnet" "azure_arc" {
  name                 = "snet-azure-arc"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = [var.azure_arc_subnet_prefix]
}

# VPN Gateway Subnet
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = ["10.0.255.0/27"]  # Updated voor nieuwe addressing
}

# Azure Firewall Subnet (required naam)
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"  # Mandatory name
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.azure_enterprise.name
  address_prefixes     = ["10.0.254.0/26"]  # /26 minimum voor Firewall subnet

  depends_on = [azurerm_virtual_network.azure_enterprise]
}

# Network Security Groups - Enhanced
resource "azurerm_network_security_group" "dmz" {
  name                = "nsg-dmz"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "frontend" {
  name                = "nsg-frontend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromDMZ"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = var.dmz_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSHFromManagement"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_subnet_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "backend" {
  name                = "nsg-backend"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromFrontend"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "8443"]
    source_address_prefix      = var.frontend_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSHFromManagement"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_subnet_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "database" {
  name                = "nsg-database"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowFromBackend"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3306", "5432", "1433"]  # MySQL, PostgreSQL, SQL Server
    source_address_prefix      = var.backend_subnet_prefix
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSHFromManagement"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.management_subnet_prefix
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "management" {
  name                = "nsg-management"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowRDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.onpremises_hoofdkantoor_cidr  # 192.168.0.0/16
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowSSH"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.onpremises_hoofdkantoor_cidr  # 192.168.0.0/16
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_network_security_group" "azure_arc" {
  name                = "nsg-azure-arc"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  security_rule {
    name                       = "AllowAzureArcManagement"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "5985", "5986"]  # HTTPS, WinRM
    source_address_prefix      = "AzureCloud"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Subnet NSG Associations - FIXED with explicit dependencies
resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz.id
  
  depends_on = [
    azurerm_subnet.dmz,
    azurerm_network_security_group.dmz
  ]
}

resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
  
  depends_on = [
    azurerm_subnet.frontend,
    azurerm_network_security_group.frontend
  ]
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
  
  depends_on = [
    azurerm_subnet.backend,
    azurerm_network_security_group.backend
  ]
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
  
  depends_on = [
    azurerm_subnet.database,
    azurerm_network_security_group.database
  ]
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
  
  depends_on = [
    azurerm_subnet.management,
    azurerm_network_security_group.management
  ]
}

resource "azurerm_subnet_network_security_group_association" "azure_arc" {
  subnet_id                 = azurerm_subnet.azure_arc.id
  network_security_group_id = azurerm_network_security_group.azure_arc.id
  
  depends_on = [
    azurerm_subnet.azure_arc,
    azurerm_network_security_group.azure_arc
  ]
}

# Configure VNet DNS voor hybrid resolution
resource "azurerm_virtual_network_dns_servers" "main" {
  virtual_network_id = azurerm_virtual_network.azure_enterprise.id
  dns_servers        = var.on_premises_dns_servers  # FONTDC01: 192.168.2.100
}

# ==============================================================================
# VPN GATEWAY RESOURCES - ENHANCED VOOR MULTI-SITE
# ==============================================================================

# VPN Gateway Public IP
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "pip-${var.project_name}-vpn-gw"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                = "Standard"

  tags = local.common_tags
}

# Virtual Network Gateway (Enhanced voor Enterprise)
resource "azurerm_virtual_network_gateway" "vpn" {
  name                = "vng-${var.project_name}-vpn"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  type     = "Vpn"
  vpn_type = "RouteBased"
  sku      = "VpnGw2"  # Upgraded van VpnGw1 voor betere performance
  generation = "Generation2"  # Voor betere throughput

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  tags = local.common_tags
}

# Local Network Gateway - Hoofdkantoor (Huidige Setup)
resource "azurerm_local_network_gateway" "hoofdkantoor" {
  name                = "lng-${var.project_name}-hoofdkantoor"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  gateway_address     = var.hoofdkantoor_gateway_ip  # 145.220.74.133
  
  # Alle huidige VLANs
  address_space = [
    "192.168.1.0/24",  # VLAN A
    "192.168.2.0/24",  # VLAN B
    "192.168.3.0/24"   # VLAN C
  ]

  tags = local.common_tags
}

# VPN Connection - Hoofdkantoor
resource "azurerm_virtual_network_gateway_connection" "hoofdkantoor" {
  name                = "conn-${var.project_name}-hoofdkantoor"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.vpn.id
  local_network_gateway_id   = azurerm_local_network_gateway.hoofdkantoor.id

  shared_key = var.vpn_shared_key

  tags = local.common_tags
}

# Placeholder Local Network Gateways voor toekomstige vakantieparken
resource "azurerm_local_network_gateway" "vakantiepark_nl" {
  name                = "lng-${var.project_name}-vakantiepark-nl"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  gateway_address     = "1.2.3.4"  # Placeholder - later in te vullen
  address_space       = [var.vakantiepark_nl_cidr]

  tags = merge(local.common_tags, {
    Status = "placeholder-future-deployment"
  })
}

resource "azurerm_local_network_gateway" "vakantiepark_be" {
  name                = "lng-${var.project_name}-vakantiepark-be"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  gateway_address     = "1.2.3.5"  # Placeholder - later in te vullen
  address_space       = [var.vakantiepark_be_cidr]

  tags = merge(local.common_tags, {
    Status = "placeholder-future-deployment"
  })
}

resource "azurerm_local_network_gateway" "vakantiepark_de" {
  name                = "lng-${var.project_name}-vakantiepark-de"
  resource_group_name = azurerm_resource_group.network.name
  location            = azurerm_resource_group.network.location
  gateway_address     = "1.2.3.6"  # Placeholder - later in te vullen
  address_space       = [var.vakantiepark_de_cidr]

  tags = merge(local.common_tags, {
    Status = "placeholder-future-deployment"
  })
}

# ==============================================================================
# SECURITY RESOURCES - ENHANCED ENTERPRISE
# ==============================================================================

resource "azurerm_resource_group" "security" {
  name     = "rg-${var.project_name}-security"
  location = var.location
  tags     = local.common_tags
}

# Key Vault - FIXED naming and network ACLs
resource "azurerm_key_vault" "main" {
  name                = "kv-fonteyn-${random_string.kv_suffix.result}"  # FIXED: Shorter name
  location            = azurerm_resource_group.security.location
  resource_group_name = azurerm_resource_group.security.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "premium"

  enabled_for_disk_encryption     = true
  enabled_for_deployment          = true
  enabled_for_template_deployment = true
  purge_protection_enabled        = var.environment == "prod"
  soft_delete_retention_days      = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    
    virtual_network_subnet_ids = [
      azurerm_subnet.management.id,
      azurerm_subnet.azure_arc.id
    ]
    
    # FIXED: Removed private IP rules - not supported
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "current_user" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Set", "Get", "List", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]

  key_permissions = [
    "Create", "Get", "List", "Update", "Delete", "Backup", "Restore", "Recover", "Purge"
  ]

  certificate_permissions = [
    "Create", "Get", "List", "Update", "Delete", "Import", "Backup", "Restore", "Recover", "Purge"
  ]
}

# Enterprise Secrets
resource "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  value        = random_password.sql_admin.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
  tags       = local.common_tags
}

resource "azurerm_key_vault_secret" "vpn_shared_key" {
  name         = "vpn-shared-key-hoofdkantoor"
  value        = var.vpn_shared_key
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
  tags       = local.common_tags
}

# Domain service account passwords (placeholders)
resource "random_password" "domain_service_account" {
  length  = 24
  special = true
  upper   = true
  lower   = true
  numeric = true
}

resource "azurerm_key_vault_secret" "domain_service_account" {
  name         = "domain-service-account-password"
  value        = random_password.domain_service_account.result
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
  tags       = local.common_tags
}

resource "azurerm_key_vault_secret" "aad_connect_service_account" {
  name         = "aad-connect-service-account"
  value        = "FONTEYN-svc-aadconnect"
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.current_user]
  tags       = local.common_tags
}