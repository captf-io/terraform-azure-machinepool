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

# The cluster's zones as of the pool's first apply, for a pool without its
# own failure domains. Pinned: a later cluster zone change must not replace
# the scale set, whose zones can only grow in place (CONVENTIONS.md
# section 13; README "Lifecycle").
resource "terraform_data" "pool_default_zones" {
  input = sort(var.cluster_failure_domains)

  lifecycle {
    ignore_changes = [input]
  }
}
