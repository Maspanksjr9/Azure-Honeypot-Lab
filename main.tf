resource "azurerm_resource_group" "honeypotlab" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_virtual_network" "honeypotvm-vnet" {
  name                = "honeypotvm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.honeypotlab.location
  resource_group_name = azurerm_resource_group.honeypotlab.name
  lifecycle {
    prevent_destroy = false
  }
}

resource "azurerm_subnet" "example" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.honeypotlab.name
  virtual_network_name = azurerm_virtual_network.honeypotvm-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "honeypot-public-ip" {
  name                = "honeypot-public-ip"
  location            = azurerm_resource_group.honeypotlab.location
  resource_group_name = azurerm_resource_group.honeypotlab.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "honeypot-nic" {
  name                = "honeypot-nic"
  location            = azurerm_resource_group.honeypotlab.location
  resource_group_name = azurerm_resource_group.honeypotlab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.honeypot-public-ip.id
  }
}

resource "azurerm_windows_virtual_machine" "honeypotvm" {
  name                = "honeypotvm"
  resource_group_name = azurerm_resource_group.honeypotlab.name
  location            = azurerm_resource_group.honeypotlab.location
  size                = "Standard_DS1_v2"
  admin_username      = "*******"
  admin_password      = "*******"
  network_interface_ids = [
    azurerm_network_interface.honeypot-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  source_image_reference {
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2022-datacenter-azure-edition"
  version   = "latest"
  }
}

resource "azurerm_network_security_group" "honeypotvm-nsg" {
  name                = "honeypot-nsg"
  location            = azurerm_resource_group.honeypotlab.location
  resource_group_name = azurerm_resource_group.honeypotlab.name

  security_rule {
    name                       = "DANGER_ANY_IN"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "honeypot-nsglink" {
  network_interface_id      = azurerm_network_interface.honeypot-nic.id
  network_security_group_id = azurerm_network_security_group.honeypotvm-nsg.id
}

resource "azurerm_log_analytics_workspace" "law-honeypot1" {
  name                = "law-honeypot1"
  location            = azurerm_resource_group.honeypotlab.location
  resource_group_name = azurerm_resource_group.honeypotlab.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
