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

# Unit tests of the machinepool role with a mocked azurerm provider: nothing
# reaches Azure. Run with `make unit-test` (terraform test and tofu test).
#
# Mocked plans never replace a resource (a mock knows no ForceNew), so "in
# place" here means the scale set keeps its name; DESIGN.md decision 7 holds
# the schema evidence that the updates themselves are in place. A run
# compares with the run right before it: OpenTofu does not resolve the
# outputs of older runs once later runs changed the state.

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
  replicas                = 3
  bootstrap_data          = "IyMgdGVtcGxhdGU6IGppbmphCiNjbG91ZC1jb25maWcKcnVuY21kOiBbZWNobyBoZWxsb10K"
  bootstrap_format        = "cloud-config"
  failure_domains         = []
  cluster_failure_domains = ["1", "2", "3"]
  kubernetes_version      = "v1.34.1"
  node_labels             = {}
  autoscaling             = { enabled = false, min = 0, max = 0 }

  image_id = "/communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/{semver}"
}

run "happy_path" {
  assert {
    condition     = output.provider_id == "azure:///subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/${output.scale_set_name}"
    error_message = "provider_id is the scale set's ARM ID with the azure:// scheme."
  }
  assert {
    condition     = jsonencode(output.provider_id_list) == jsonencode(["azure:///subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/${output.scale_set_name}/virtualMachines/0", "azure:///subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/${output.scale_set_name}/virtualMachines/1", "azure:///subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/${output.scale_set_name}/virtualMachines/2"])
    error_message = "provider_id_list holds every instance as cloud-provider-azure writes it, sorted."
  }
  assert {
    condition     = output.replicas == 3
    error_message = "replicas is the scale set's capacity."
  }
  assert {
    condition     = length(output.instances) == 3 && output.instances[0].provider_id == "azure:///subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/virtualMachineScaleSets/${output.scale_set_name}/virtualMachines/0" && output.instances[0].instance_id == "0" && output.instances[0].failure_domain == "1" && output.instances[0].state == "running"
    error_message = "instances describe every member."
  }
  assert {
    condition     = jsonencode(output.instances[1].addresses) == jsonencode([{ type = "InternalIP", address = "10.0.1.5" }, { type = "Hostname", address = "workers-6a1f0c2e000001" }])
    error_message = "An instance's addresses are its private address and hostname."
  }
  assert {
    condition     = output.health.state == "running" && output.health.healthy && length(output.health.reasons) == 0
    error_message = "Three running members of a capacity of three are healthy."
  }
  assert {
    condition     = output.scale_set_name == "workers-${substr(sha256("workers/${jsonencode({ failure_domains = [], kubernetes_version = "v1.34.1", os_disk_storage_account_type = "Premium_LRS", spot = false, trusted_launch = false })}"), 0, 8)}" && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].computer_name_prefix == output.scale_set_name
    error_message = "The scale set and its hostnames are named after the pool and a hash of its generation."
  }
  assert {
    condition     = output.scale_set_id == azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].id && output.autoscale_setting_id == azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].id
    error_message = "The extra outputs name the scale set and its autoscale setting."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].upgrade_mode == "Manual" && !azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].overprovision && !azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].single_placement_group && !azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].extension_operations_enabled
    error_message = "A manual, non-overprovisioned scale set without extensions."
  }
  assert {
    condition     = toset(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].zones) == toset(["1", "2", "3"]) && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].instances == 3 && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].sku == "Standard_D4s_v5"
    error_message = "The pool spreads over the cluster's zones at the requested capacity."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].source_image_id == "/communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/1.34.1"
    error_message = "{semver} in image_id becomes the version without the v."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].network_interface[0].network_security_group_id == var.captf_cluster_outputs.worker.network_security_group_id && toset(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].network_interface[0].ip_configuration[0].application_security_group_ids) == toset([var.captf_cluster_outputs.worker.application_security_group_id]) && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].network_interface[0].ip_configuration[0].subnet_id == var.captf_cluster_outputs.worker_subnet_id
    error_message = "Instances use the worker subnet, security group and application security group."
  }
  assert {
    condition     = toset(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].identity[0].identity_ids) == toset([var.captf_cluster_outputs.worker.identity_id]) && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].termination_notification[0].enabled
    error_message = "Instances run as the worker identity with termination notifications."
  }
}

run "reapply_is_stable" {
  variables {
    previous_scale_set_name       = run.happy_path.scale_set_name
    previous_provider_id          = run.happy_path.provider_id
    previous_autoscale_setting_id = run.happy_path.autoscale_setting_id
  }

  assert {
    condition     = output.scale_set_name == var.previous_scale_set_name && output.provider_id == var.previous_provider_id && output.autoscale_setting_id == var.previous_autoscale_setting_id
    error_message = "A second identical apply must keep the scale set."
  }
}

run "tags_on_taggable_resources" {
  variables {
    additional_tags = { costCenter = "1234" }
  }

  assert {
    condition = alltrue([
      for t in [azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].tags, azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].tags] :
      t["captf.io_cluster"] == "demo" && t["captf.io_kind"] == "TerraformMachinePool" && t["captf.io_name"] == "workers" && t["costCenter"] == "1234"
    ])
    error_message = "The scale set and its autoscale setting carry the mapped captf tags and the additional tags."
  }
}

run "autoscaling_disabled" {
  variables {
    replicas                = 5
    previous_scale_set_name = run.tags_on_taggable_resources.scale_set_name
  }

  assert {
    condition     = azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].minimum == 5 && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].maximum == 5 && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].default == 5 && length(azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].rule) == 0
    error_message = "Without autoscaling, Azure Autoscale pins the capacity to replicas and has no rules."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].instances == 3 && output.scale_set_name == var.previous_scale_set_name
    error_message = "The scale set ignores capacity changes (Autoscale applies them) and is kept."
  }
}

run "autoscaling_enabled" {
  variables {
    replicas    = 4
    autoscaling = { enabled = true, min = 2, max = 6 }
  }

  assert {
    condition     = azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].minimum == 2 && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].maximum == 6 && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].capacity[0].default == 2
    error_message = "With autoscaling, the capacity range is min..max and the default is min, never replicas."
  }
  assert {
    condition     = length(azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].rule) == 2 && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].rule[0].metric_trigger[0].metric_name == "Percentage CPU" && azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].rule[0].metric_trigger[0].metric_resource_id == azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].id
    error_message = "With autoscaling, CPU rules on the scale set scale it."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].instances == 3
    error_message = "An apply never resets the capacity Autoscale chose."
  }
}

run "bootstrap_rotation_in_place" {
  variables {
    bootstrap_data          = "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIHJvdGF0ZWRdCg=="
    previous_scale_set_name = run.autoscaling_enabled.scale_set_name
  }

  assert {
    condition     = output.scale_set_name == var.previous_scale_set_name
    error_message = "A bootstrap rotation keeps the scale set (its model is updated in place)."
  }
  assert {
    condition     = strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "I2Nsb3VkLWNvbmZpZwpydW5jbWQ6IFtlY2hvIHJvdGF0ZWRdCg==")
    error_message = "The scale set model carries the rotated bootstrap data."
  }
}

run "kubernetes_version_rolls" {
  variables {
    kubernetes_version      = "v1.34.2"
    previous_scale_set_name = run.bootstrap_rotation_in_place.scale_set_name
  }

  assert {
    condition     = output.scale_set_name != var.previous_scale_set_name && startswith(output.scale_set_name, "workers-")
    error_message = "A version change creates a new scale set generation."
  }
  assert {
    condition     = endswith(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].source_image_id, "/versions/1.34.2")
    error_message = "The new generation uses the new version's image."
  }
}

# A +rke2rN bump changes the Kubernetes version verbatim and rolls the pool,
# while the image, which knows only the semver, stays (CONVENTIONS.md
# section 13).
run "kubernetes_version_suffix_rolls" {
  variables {
    kubernetes_version      = "v1.34.2+rke2r1"
    previous_scale_set_name = run.kubernetes_version_rolls.scale_set_name
  }

  assert {
    condition     = output.scale_set_name != var.previous_scale_set_name
    error_message = "A suffix-only version change creates a new scale set generation."
  }
  assert {
    condition     = endswith(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].source_image_id, "/versions/1.34.2")
    error_message = "The image placeholders drop the +rke2rN suffix."
  }
}

run "node_labels_rendered" {
  variables {
    node_labels = {
      "team"                           = "payments"
      "node.kubernetes.io/pool"        = "workers"
      "topology.kubernetes.io/zone"    = "westeurope-1"
      "node-role.kubernetes.io/worker" = ""
      "example.k8s.io/tier"            = "gold"
    }
  }

  assert {
    condition     = strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "captf_node_labels='node.kubernetes.io/pool=workers,team=payments,topology.kubernetes.io/zone=westeurope-1'")
    error_message = "The kubelet gets the labels it may register, sorted."
  }
  assert {
    condition     = !strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "node-role.kubernetes.io/worker") && !strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "example.k8s.io/tier") && jsonencode(output.dropped_node_labels) == jsonencode(["example.k8s.io/tier", "node-role.kubernetes.io/worker"])
    error_message = "Labels NodeRestriction forbids are dropped and listed in dropped_node_labels."
  }
  assert {
    condition     = strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "# captf-node-labels begin") && strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "captf_rke2_file=/etc/rancher/rke2/config.yaml.d/50-captf-node-labels.yaml")
    error_message = "The boothook carries the shared node-labels fragment, which also writes the RKE2 drop-in."
  }
}

run "node_labels_unsupported_format" {
  command = plan

  variables {
    bootstrap_format = "ignition"
    bootstrap_data   = "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    node_labels      = { team = "payments" }
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.pool_scale_set]
}

# Only forbidden labels: nothing would be rendered, so Ignition is fine.
run "bootstrap_ignition" {
  variables {
    bootstrap_format = "ignition"
    bootstrap_data   = "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    node_labels      = { "node-role.kubernetes.io/worker" = "" }
  }

  assert {
    condition     = nonsensitive(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data) == "eyJpZ25pdGlvbiI6eyJ2ZXJzaW9uIjoiMy40LjAifX0="
    error_message = "Ignition with only labels the kubelet may not set is passed through unchanged."
  }
}

run "bootstrap_cloud_config" {
  assert {
    condition     = startswith(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "Content-Type: multipart/mixed; boundary=\"==CAPTF-BOUNDARY==\"\n")
    error_message = "cloud-config custom data is a MIME multipart."
  }
  assert {
    condition     = strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "Content-Type: text/plain; charset=\"utf-8\"\nMIME-Version: 1.0\nContent-Transfer-Encoding: base64\nContent-Disposition: attachment; filename=\"bootstrap\"\n\nIyMgdGVtcGxhdGU6IGppbmphCiNjbG91ZC1jb25maWcKcnVuY21kOiBbZWNobyBoZWxsb10K\n")
    error_message = "The bootstrap data is an opaque base64 text/plain part."
  }
  assert {
    condition     = strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "\"userAssignedIdentityID\":\"7a4b9c7d-2e8f-4a3b-9c4d-7e8f9a0b1c2d\"") && strcontains(nonsensitive(base64decode(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].custom_data)), "captf_node_labels=''")
    error_message = "The boothook writes the worker identity's cloud provider config; without node_labels the fragment only clears earlier labels."
  }
}

# The pool took the cluster's zones (1, 2, 3) at its first apply and keeps
# them: a cluster zone change must not replace the scale set.
run "failure_domains_default_to_cluster" {
  variables {
    failure_domains         = []
    cluster_failure_domains = ["3", "1"]
    previous_scale_set_name = run.bootstrap_cloud_config.scale_set_name
  }

  assert {
    condition     = toset(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].zones) == toset(["1", "2", "3"]) && jsonencode(terraform_data.pool_default_zones.output) == jsonencode(["1", "2", "3"])
    error_message = "With no failure domains requested, the pool keeps the cluster's zones as of its first apply."
  }
  assert {
    condition     = output.scale_set_name == var.previous_scale_set_name
    error_message = "A cluster zone change keeps the scale set."
  }
}

run "bootstrap_too_large" {
  command = plan

  variables {
    bootstrap_data = base64encode(format("%070000d", 0))
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.pool_scale_set]
}

run "failure_domains_requested" {
  variables {
    failure_domains = ["2"]
  }

  assert {
    condition     = toset(azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].zones) == toset(["2"])
    error_message = "Requested failure domains are the scale set's zones."
  }
}

run "rejects_unknown_failure_domains" {
  command = plan

  variables {
    failure_domains = ["4"]
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.pool_scale_set]
}

run "membership_excludes_terminated" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
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
          power_state          = "deallocated"
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
          power_state          = "stopped"
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

  # Azure lists an instance until it is deleted and has no terminated state:
  # stopped and deallocated (Spot-evicted) instances are members, and a
  # deleted one is simply absent from the listing.
  assert {
    condition     = length(output.provider_id_list) == 3
    error_message = "Every listed instance is a member, whatever its power state."
  }
  assert {
    condition     = output.health.state == "stopped" && !output.health.healthy && jsonencode(output.health.reasons) == jsonencode(["PowerState/deallocated:workers-6a1f0c2e000001", "PowerState/stopped:workers-6a1f0c2e000002"])
    error_message = "The worst member state is the pool's, with the affected instances as reasons."
  }
  assert {
    condition     = [for i in output.instances : i.state] == ["running", "stopped", "stopped"]
    error_message = "Per-instance states use the health enum."
  }
}

run "health_starting_members" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
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
          power_state          = "starting"
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
          power_state          = ""
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

  assert {
    condition     = output.health.state == "running" && !output.health.healthy && jsonencode(output.health.reasons) == jsonencode(["PowerState/starting:workers-6a1f0c2e000001", "PowerState/unknown:workers-6a1f0c2e000002"])
    error_message = "Starting members leave a pool with members running but not healthy; pending is for a pool without members."
  }
}

run "health_unknown_member" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
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
          power_state          = "hibernated"
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
          power_state          = "stopped"
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

  assert {
    condition     = output.health.state == "stopped"
    error_message = "stopped is worse than unknown."
  }
  assert {
    condition     = [for i in output.instances : i.state] == ["running", "unknown", "stopped"]
    error_message = "A power state the module does not know is unknown."
  }
}

run "health_member_count_mismatch" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
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
      ]
    }
  }

  assert {
    condition     = output.health.state == "running" && !output.health.healthy && jsonencode(output.health.reasons) == jsonencode(["ScalingInProgress"])
    error_message = "Running members short of the capacity are running but not healthy."
  }
}

run "health_not_listed" {
  override_data {
    target = data.azurerm_resources.pool_scale_set_listing
    values = { resources = [] }
  }

  assert {
    condition     = output.health.state == "pending" && jsonencode(output.health.reasons) == jsonencode(["NoMembers"]) && length(output.provider_id_list) == 0
    error_message = "A scale set the listing does not show yet (the first apply, a new generation) is pending, without reading its members."
  }
  assert {
    condition     = length(data.azurerm_virtual_machine_scale_set.pool_scale_set_status) == 0
    error_message = "The member read is skipped when the listing does not show the scale set."
  }
}

run "health_listed_in_other_group" {
  override_data {
    target = data.azurerm_resources.pool_scale_set_listing
    values = {
      resources = [{
        id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/other/providers/Microsoft.Compute/virtualMachineScaleSets/workers"
        location            = "westeurope"
        name                = "workers"
        resource_group_name = "other"
        tags                = {}
        type                = "Microsoft.Compute/virtualMachineScaleSets"
      }]
    }
  }

  # The listing is subscription-wide (a deleted resource group must not
  # fail it); a scale set of the same name elsewhere is not this pool's.
  assert {
    condition     = output.health.state == "pending" && length(data.azurerm_virtual_machine_scale_set.pool_scale_set_status) == 0
    error_message = "Only a scale set in the cluster's resource group counts."
  }
}

run "health_no_instances_yet" {
  override_data {
    target = data.azurerm_virtual_machine_scale_set.pool_scale_set_status
    values = {
      instances = []
    }
  }

  assert {
    condition     = output.health.state == "pending" && jsonencode(output.health.reasons) == jsonencode(["NoMembers"])
    error_message = "A scale set without its first members is pending."
  }
}

run "spot_instances" {
  variables {
    spot = true
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].priority == "Spot" && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].eviction_policy == "Delete" && azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].max_bid_price == -1
    error_message = "Spot instances are deleted on eviction, capped at the on-demand price."
  }
}

run "externally_managed_without_override" {
  command = plan

  variables {
    captf_cluster_outputs = {}
  }

  expect_failures = [data.azurerm_resources.pool_scale_set_listing]
}

run "externally_managed_with_override" {
  variables {
    captf_cluster_outputs = {}
    external_cluster_exports = {
      schema              = "captf.io/azure-cluster/v1"
      tenant_id           = "72f988bf-86f1-41af-91ab-2d7cd011db47"
      subscription_id     = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
      region              = "northeurope"
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
  }

  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].location == "northeurope"
    error_message = "external_cluster_exports stands in for the exports of an externally managed cluster."
  }
}

run "wrong_exports_schema" {
  command = plan

  variables {
    captf_cluster_outputs = { schema = "captf.io/gcp-cluster/v1" }
  }

  expect_failures = [var.captf_cluster_outputs]
}

run "rejects_unversioned_image" {
  command = plan

  variables {
    kubernetes_version = null
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.pool_scale_set]
}

run "rejects_gzipped_ignition" {
  command = plan

  variables {
    bootstrap_format = "ignition"
    bootstrap_data   = "H4sIAAAAAAAC/6tWykzPyyzJzM9TsqpWKkstKgYzlYz1TPQMlGprAWys13sgAAAA"
  }

  expect_failures = [azurerm_linux_virtual_machine_scale_set.pool_scale_set]
}

run "autoscaling_custom_thresholds" {
  variables {
    autoscaling                       = { enabled = true, min = 2, max = 6 }
    autoscaling_scale_out_cpu_percent = 60
    autoscaling_scale_in_cpu_percent  = 20
  }

  assert {
    condition     = sort([for r in azurerm_monitor_autoscale_setting.pool_autoscale_setting[0].profile[0].rule : tostring(r.metric_trigger[0].threshold)]) == tolist(["20", "60"])
    error_message = "The CPU thresholds come from the autoscaling_scale_*_cpu_percent variables."
  }
}

run "autoscaling_external" {
  variables {
    replicas    = 4
    autoscaling = { enabled = true, min = 2, max = 6 }
    autoscaler  = "external"
  }

  assert {
    condition     = length(azurerm_monitor_autoscale_setting.pool_autoscale_setting) == 0 && output.autoscale_setting_id == null
    error_message = "With autoscaling enabled and autoscaler external, there is no autoscale setting: an outside scaler holds the capacity."
  }
  assert {
    condition     = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].instances == 3
    error_message = "An apply never resets the capacity the outside scaler chose."
  }
}

run "rejects_inverted_autoscaling_thresholds" {
  command = plan

  variables {
    autoscaling                       = { enabled = true, min = 2, max = 6 }
    autoscaling_scale_out_cpu_percent = 30
    autoscaling_scale_in_cpu_percent  = 40
  }

  expect_failures = [azurerm_monitor_autoscale_setting.pool_autoscale_setting]
}

run "invalid_autoscaler" {
  command = plan

  variables {
    autoscaler = "cluster-autoscaler"
  }

  expect_failures = [var.autoscaler]
}

run "invalid_autoscaling_scale_in_cpu_percent" {
  command = plan

  variables {
    autoscaling_scale_in_cpu_percent = 0
  }

  expect_failures = [var.autoscaling_scale_in_cpu_percent]
}

run "invalid_autoscaling_scale_out_cpu_percent" {
  command = plan

  variables {
    autoscaling_scale_out_cpu_percent = 101
  }

  expect_failures = [var.autoscaling_scale_out_cpu_percent]
}

run "invalid_captf_contract" {
  command = plan

  variables {
    captf_contract = "v1alpha2"
  }

  expect_failures = [var.captf_contract]
}

run "invalid_replicas" {
  command = plan

  variables {
    replicas = 1001
  }

  expect_failures = [var.replicas]
}

run "invalid_bootstrap_format" {
  command = plan

  variables {
    bootstrap_format = "shell"
  }

  expect_failures = [var.bootstrap_format]
}

run "invalid_node_labels" {
  command = plan

  variables {
    node_labels = { "bad key!" = "x" }
  }

  expect_failures = [var.node_labels]
}

run "invalid_autoscaling" {
  command = plan

  variables {
    autoscaling = { enabled = true, min = 5, max = 2 }
  }

  expect_failures = [var.autoscaling]
}

run "invalid_additional_tags_reserved_key" {
  command = plan

  variables {
    additional_tags = { "captf.io_name" = "x" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_characters" {
  command = plan

  variables {
    additional_tags = { "a%b" = "c" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_count" {
  command = plan

  variables {
    additional_tags = { for i in range(45) : "tag${i}" => "v" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_external_cluster_exports" {
  command = plan

  variables {
    external_cluster_exports = { schema = "captf.io/azure-cluster/v2" }
  }

  expect_failures = [var.external_cluster_exports]
}

run "invalid_image_id" {
  command = plan

  variables {
    image_id = "/CommunityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/Images/capi-ubun2-2404"
  }

  expect_failures = [var.image_id]
}

run "invalid_os_disk_size_gib" {
  command = plan

  variables {
    os_disk_size_gib = 4096
  }

  expect_failures = [var.os_disk_size_gib]
}

run "invalid_os_disk_storage_account_type" {
  command = plan

  variables {
    os_disk_storage_account_type = "Premium_v2_LRS"
  }

  expect_failures = [var.os_disk_storage_account_type]
}

run "invalid_vm_size" {
  command = plan

  variables {
    vm_size = "Standard D4s v5"
  }

  expect_failures = [var.vm_size]
}
