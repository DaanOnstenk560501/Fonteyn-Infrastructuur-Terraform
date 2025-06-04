# Fonteyn Enterprise Infrastructure - STAP 1: Core Updates
# Aanpassingen: IP addressing, VM sizes, DMZ architectuur

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
  default     = "fonteyn-enterprise"
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
  default     = "10.100.0.0/16"
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
  default     = "Standard_D8s_v5"  # Was Standard_D2s_v5
}

variable "backend_vm_size" {
  description = "Backend application VM size - Enterprise"
  type        = string
  default     = "Standard_D16s_v5"  # Was Standard_D2s_v5
}

variable "database_vm_size" {
  description = "Database VM size - Memory optimized"
  type        = string
  default     = "Standard_E16ds_v5"  # Was Standard_D4s_v5
}

variable "monitoring_vm_size" {
  description = "Monitoring server VM size"
  type        = string
  default     = "Standard_D8s_v5"  # NIEUW
}

variable "printserver_vm_size" {
  description = "Print server VM size"
  type        = string
  default     = "Standard_D4s_v5"  # NIEUW
}

# INSTANCE COUNTS
variable "frontend_instance_count" {
  description = "Frontend webserver count"
  type        = number
  default     = 3  # Was 2, verhoogd voor enterprise
}

variable "backend_instance_count" {
  description = "Backend application server count"
  type        = number
  default     = 3  # Was 2, verhoogd voor enterprise
}

variable "database_instance_count" {
  description = "Database server count"
  type        = number
  default     = 2  # Was 1, verhoogd voor HA
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
    "10.100.0.0/16",  # Hoofdkantoor
    "10.5.0.0/16",    # Vakantiepark NL
    "10.6.0.0/16",    # Vakantiepark BE
    "10.7.0.0/16"     # Vakantiepark DE
  ]
}

variable "on_premises_dns_servers" {
  description = "On-premises DNS servers"
  type        = list(string)
  default     = ["10.100.0.10", "10.100.0.11"]  # DCs in hoofdkantoor
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

# Subnet NSG Associations
resource "azurerm_subnet_network_security_group_association" "dmz" {
  subnet_id                 = azurerm_subnet.dmz.id
  network_security_group_id = azurerm_network_security_group.dmz.id
}

resource "azurerm_subnet_network_security_group_association" "frontend" {
  subnet_id                 = azurerm_subnet.frontend.id
  network_security_group_id = azurerm_network_security_group.frontend.id
}

resource "azurerm_subnet_network_security_group_association" "backend" {
  subnet_id                 = azurerm_subnet.backend.id
  network_security_group_id = azurerm_network_security_group.backend.id
}

resource "azurerm_subnet_network_security_group_association" "database" {
  subnet_id                 = azurerm_subnet.database.id
  network_security_group_id = azurerm_network_security_group.database.id
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_subnet_network_security_group_association" "azure_arc" {
  subnet_id                 = azurerm_subnet.azure_arc.id
  network_security_group_id = azurerm_network_security_group.azure_arc.id
}

# Continue met VPN Gateway, Security, Storage, Monitoring, en Compute in volgende delen...