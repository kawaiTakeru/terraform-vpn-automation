provider "azurerm" {
  subscription_id = "6a018b75-55b5-4b68-960d-7328148568aa" # Spoke側
  features {}
}

provider "azurerm" {
  alias           = "hub"
  subscription_id = "7d1f78e5-bc6c-4018-847f-336ff47b9436" # Hub側
  features {}
}

data "azurerm_virtual_network" "spoke" {
  provider            = azurerm
  name                = "vnet-from-pipeline"
  resource_group_name = "rg-from-pipeline"
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = "vnet-test-hubnw-prd-jpe-001"
  resource_group_name = "rg-test-hubnw-prd-jpe-001"
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  provider                  = azurerm
  name                      = "spoke-to-hub"
  resource_group_name       = data.azurerm_virtual_network.spoke.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.spoke.name
  remote_virtual_network_id = data.azurerm_virtual_network.hub.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = false
  use_remote_gateways     = true
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  provider                  = azurerm.hub
  name                      = "hub-to-spoke"
  resource_group_name       = data.azurerm_virtual_network.hub.resource_group_name
  virtual_network_name      = data.azurerm_virtual_network.hub.name
  remote_virtual_network_id = data.azurerm_virtual_network.spoke.id

  allow_forwarded_traffic = true
  allow_gateway_transit   = true
  use_remote_gateways     = false
}

