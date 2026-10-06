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

# Azure Autoscale holds the scale set's capacity, because the scale set
# ignores changes to it (DESIGN.md decision 7). Disabled: minimum = maximum
# = default = replicas, no rules, so a replicas change reaches the scale set
# through Autoscale. Enabled with autoscaler native: autoscaling.min and max,
# with CPU rules (https://learn.microsoft.com/azure/azure-monitor/autoscale/autoscale-overview).
# Enabled with autoscaler external: no setting, so a scaler outside the
# module sets the capacity and nothing here competes with it.
resource "azurerm_monitor_autoscale_setting" "pool_autoscale_setting" {
  count = local.exports_available && !(var.autoscaling.enabled && var.autoscaler == "external") ? 1 : 0

  enabled             = true
  location            = local.location
  name                = local.autoscale_setting_name
  resource_group_name = local.resource_group_name
  tags                = local.tags
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].id

  profile {
    name = "default"

    # Enabled, the default is the minimum, never replicas: the controller
    # renders replicas from the observed capacity, and a default that
    # followed it would show every scale as drift.
    capacity {
      default = var.autoscaling.enabled ? var.autoscaling.min : local.desired_replicas
      maximum = var.autoscaling.enabled ? var.autoscaling.max : local.desired_replicas
      minimum = var.autoscaling.enabled ? var.autoscaling.min : local.desired_replicas
    }

    dynamic "rule" {
      for_each = { for k, r in local.autoscale_rules : k => r if var.autoscaling.enabled }

      content {
        metric_trigger {
          metric_name        = "Percentage CPU"
          metric_namespace   = "microsoft.compute/virtualmachinescalesets"
          metric_resource_id = azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].id
          operator           = rule.value.operator
          statistic          = "Average"
          threshold          = rule.value.threshold
          time_aggregation   = "Average"
          time_grain         = "PT1M"
          time_window        = "PT10M"
        }

        scale_action {
          cooldown  = rule.value.cooldown
          direction = rule.value.direction
          type      = "ChangeCount"
          value     = 1
        }
      }
    }
  }

  lifecycle {
    # Checks that span variables (CONVENTIONS.md section 4). The thresholds
    # are unused, and so unchecked, while autoscaler is external.
    precondition {
      condition     = var.autoscaling_scale_in_cpu_percent < var.autoscaling_scale_out_cpu_percent
      error_message = "autoscaling_scale_in_cpu_percent must be below autoscaling_scale_out_cpu_percent, or the pool would scale in and out at once."
    }
  }
}
