# Creates cluster with default linux node pool

resource "azurerm_kubernetes_cluster" "akscluster" {
  lifecycle {
   ignore_changes = [
     default_node_pool[0].node_count
   ]
  }

  name                    = var.prefix
  dns_prefix              = var.prefix
  location                = var.location
  resource_group_name     = var.resource_group_name
  kubernetes_version      = "1.24.6"
  azure_policy_enabled    = true
  oidc_issuer_enabled     = true

  default_node_pool {
    name            = "defaultpool"
    vm_size         = "Standard_B2s"
    os_disk_size_gb = 30
    node_count = 1
    type            = "VirtualMachineScaleSets"
    orchestrator_version  = "1.24.6" 
    zones      = [1,2,3]
    only_critical_addons_enabled = true
    upgrade_settings {
      max_surge       = 2
  }
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "calico"
    outbound_type = "loadBalancer"
  }

  role_based_access_control_enabled = true

  azure_active_directory_role_based_access_control {
      managed            = true
      azure_rbac_enabled = true
    }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.mi_aks_cp_id]
  }
}

output "aks_id" {
  value = azurerm_kubernetes_cluster.akscluster.id
}

output "node_pool_rg" {
  value = azurerm_kubernetes_cluster.akscluster.node_resource_group
}

# Managed Identities created for Addons

output "kubelet_id" {
  value = azurerm_kubernetes_cluster.akscluster.kubelet_identity[0].object_id
}

resource "azurerm_kubernetes_cluster_node_pool" "nodepool_cpu_spot" {
    zones    = [1, 2, 3]
    enable_auto_scaling   = true
    kubernetes_cluster_id = azurerm_kubernetes_cluster.akscluster.id
    max_count             = 3
    min_count             = 1
    mode                  = "User"
    name                  = "spotnodes"
    os_type               = "Linux" # Default is Linux, we can change to Windows
    vm_size               = "Standard_A2m_v2"
    priority              = "Spot"
    spot_max_price        = -1
    eviction_policy       = "Delete"
    orchestrator_version  = "1.24.6"    
    tags = {
      "nodepool-type" = "user"
      "environment"   = "staging"
      "nodepoolos"    = "linux"
      "sku"           = "cpu"    
    }
  }
