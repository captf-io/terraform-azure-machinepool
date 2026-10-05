# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Unit tests of a machinepool at zero capacity, in a file of its own: a test
# file has its own state, and the scale set must be created at zero, since
# its capacity is never changed by an apply (ignore_changes).

mock_provider "azurerm" {
  # IDs other resources take as arguments are pinned in ARM format: the
  # provider validates them even when mocked.
  mock_resource "azurerm_linux_virtual_machine_scale_set" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/workers"
    }
  }

  # The listing finds the scale set and the member read reports three
  # running instances, unless a run overrides them.
  mock_data "azurerm_resources" {
    defaults = {
      resources = [{
        id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/workers"
        location            = "westeurope"
        name                = "workers"
        resource_group_name = "captf-team-a-demo-2a8d5f7c"
        tags                = {}
        type                = "Microsoft.Compute/virtualMachineScaleSets"
      }]
    }
  }

  mock_data "azurerm_virtual_machine_scale_set" {
    defaults = {
      instances = [
        {
          computer_name        = "workers-6a1f0c2e000000"
          instance_id          = "0"
          latest_model_applied = true
          name                 = "workers-6a1f0c2e_0"
          power_state          = "running"
          private_ip_address   = "10.0.1.4"
          private_ip_addresses = ["10.0.1.4"]
          public_ip_address    = ""
          public_ip_addresses  = []
          virtual_machine_id   = "9b0c1d2e-3f4a-4b5c-8d6e-7f8a9b0c1d2e"
          zone                 = "1"
        },
        {
          computer_name        = "workers-6a1f0c2e000001"
          instance_id          = "1"
          latest_model_applied = true
          name                 = "workers-6a1f0c2e_1"
          power_state          = "running"
          private_ip_address   = "10.0.1.5"
          private_ip_addresses = ["10.0.1.5"]
          public_ip_address    = ""
          public_ip_addresses  = []
          virtual_machine_id   = "9b1c1d2e-3f4a-4b5c-8d6e-7f8a9b0c1d2e"
          zone                 = "2"
        },
        {
          computer_name        = "workers-6a1f0c2e000002"
          instance_id          = "2"
          latest_model_applied = true
          name                 = "workers-6a1f0c2e_2"
          power_state          = "running"
          private_ip_address   = "10.0.1.6"
          private_ip_addresses = ["10.0.1.6"]
          public_ip_address    = ""
          public_ip_addresses  = []
          virtual_machine_id   = "9b2c1d2e-3f4a-4b5c-8d6e-7f8a9b0c1d2e"
          zone                 = "3"
        },
      ]
    }
  }
}

variables {
  captf_contract = "v1alpha1"
  captf_cluster  = { name = "demo", namespace = "team-a" }
  captf_object   = { kind = "TerraformMachinePool", name = "workers", namespace = "team-a" }
  captf_cluster_outputs = {
    schema              = "captf.io/azure-cluster/v1"
    tenant_id           = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    subscription_id     = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
    region              = "westeurope"
    resource_group_name = "captf-team-a-demo-2a8d5f7c"
    resource_group_id   = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c"
    failure_domains     = { "1" = {}, "2" = {}, "3" = {} }
    virtual_network = {
      id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub"
      name                = "hub"
      resource_group_name = "network"
    }
    subnet_id            = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes"
    subnet_name          = "nodes"
    worker_subnet_id     = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/workers"
    worker_subnet_name   = "workers"
    admin_username       = "captf"
    admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0wmN/Cr3JXqmLW7u+g9pTh+wyqDHpSQEIQczXkVx9q captf@example"
    control_plane = {
      identity_id                   = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.ManagedIdentity/userAssignedIdentities/captf-team-a-demo-2a8d5f7c-control-plane"
      identity_client_id            = "5e2f7a5b-0c6d-4e1f-9a2b-5c6d7e8f9a0b"
      network_security_group_id     = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/networkSecurityGroups/captf-team-a-demo-2a8d5f7c-control-plane-nsg"
      network_security_group_name   = "captf-team-a-demo-2a8d5f7c-control-plane-nsg"
      application_security_group_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/applicationSecurityGroups/captf-team-a-demo-2a8d5f7c-control-plane-asg"
      availability_set_id           = null
    }
    worker = {
      identity_id                   = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.ManagedIdentity/userAssignedIdentities/captf-team-a-demo-2a8d5f7c-worker"
      identity_client_id            = "7a4b9c7d-2e8f-4a3b-9c4d-7e8f9a0b1c2d"
      network_security_group_id     = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/networkSecurityGroups/captf-team-a-demo-2a8d5f7c-worker-nsg"
      network_security_group_name   = "captf-team-a-demo-2a8d5f7c-worker-nsg"
      application_security_group_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/applicationSecurityGroups/captf-team-a-demo-2a8d5f7c-worker-asg"
    }
    api = {
      host               = "10.0.0.100"
      port               = 6443
      backend_port       = 6443
      frontend_ip        = "10.0.0.100"
      backend_pool_id    = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api/backendAddressPools/control-plane"
      hairpin_workaround = true
      supervisor_port    = null
    }
    cloud_provider_config = {
      cloud                        = "AzurePublicCloud"
      tenantId                     = "72f988bf-86f1-41af-91ab-2d7cd011db47"
      subscriptionId               = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
      resourceGroup                = "captf-team-a-demo-2a8d5f7c"
      location                     = "westeurope"
      vmType                       = "vmss"
      vnetName                     = "hub"
      vnetResourceGroup            = "network"
      subnetName                   = "workers"
      securityGroupName            = "captf-team-a-demo-2a8d5f7c-worker-nsg"
      securityGroupResourceGroup   = "captf-team-a-demo-2a8d5f7c"
      loadBalancerSku              = "Standard"
      maximumLoadBalancerRuleCount = 250
      useManagedIdentityExtension  = true
      useInstanceMetadata          = true
    }
  }
  captf_tags              = { "captf.io/cluster" = "demo", "captf.io/namespace" = "team-a", "captf.io/kind" = "TerraformMachinePool", "captf.io/name" = "workers", "captf.io/managed-by" = "captf", "captf.io/template" = "" }
  machinepool_name        = "workers"
  replicas                = 0
  bootstrap_data          = "IyMgdGVtcGxhdGU6IGppbmphCiNjbG91ZC1jb25maWcKcnVuY21kOiBbZWNobyBoZWxsb10K"
  bootstrap_format        = "cloud-config"
  failure_domains         = []
  cluster_failure_domains = ["1", "2", "3"]
  kubernetes_version      = "v1.34.1"
  node_labels             = {}
  autoscaling             = { enabled = false, min = 0, max = 0 }

  image_id = "/communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/{semver}"
}

run "zero_replicas_healthy" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
      instances = []
    }
  }

  assert {
    condition     = output.health.state == "running" && output.health.healthy && output.replicas == 0 && length(output.provider_id_list) == 0 && length(output.instances) == 0
    error_message = "A pool at zero capacity is running and healthy, with no members."
  }
  assert {
    condition     = azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].maximum == 0
    error_message = "Autoscale holds the capacity at zero."
  }
}
