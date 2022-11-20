
#############
# RESOURCES #
#############

resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-RG"
  location = var.location
}

# MSI for Kubernetes Cluster (Control Plane)
# This ID is used by the AKS control plane to create or act on other resources in Azure.
# It is referenced in the "identity" block in the azurerm_kubernetes_cluster resource.

resource "azurerm_user_assigned_identity" "mi-aks-cp" {
  name                = "mi-${var.prefix}-cp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

# AKS Cluster

module "aks" {
  source = "./modules/aks"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  prefix              = "${var.prefix}-cluster"
  mi_aks_cp_id        = azurerm_user_assigned_identity.mi-aks-cp.id  
}


# This role assigned grants the current user running the deployment admin rights
# to the cluster. In production, you should use just the AAD groups (above).
resource "azurerm_role_assignment" "aks_rbac_admin" {
  scope                = module.aks.aks_id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = data.azurerm_client_config.current.object_id

}
