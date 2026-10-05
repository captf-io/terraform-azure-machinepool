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

# Placement and capacity. Failure domains are availability zones; with none
# requested the pool spreads over the cluster's, as of its first apply
# (machinepool.md "failure_domains (input)"; pool_default_zones.tf).
locals {
  cluster_zone_names = sort(keys(try(local.cluster.failure_domains, {})))
  explicit_zones     = length(var.failure_domains) > 0
  zones              = local.explicit_zones ? sort(var.failure_domains) : terraform_data.pool_default_zones.output

  # The controller already clamps replicas into [min, max] while autoscaling
  # is enabled (machinepool.md "replicas (input)"); clamping again keeps a
  # hand-made apply in range too.
  desired_replicas = var.autoscaling.enabled ? max(var.autoscaling.min, min(var.autoscaling.max, var.replicas)) : var.replicas
}
