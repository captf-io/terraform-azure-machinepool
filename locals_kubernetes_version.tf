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

# The pool's Kubernetes version and the image it selects. image_id may hold
# {version} (v1.31.4) and {semver} (1.31.4), both without the distro suffix
# RKE2 adds (machinepool.md "kubernetes_version (input)"; CONVENTIONS.md
# section 8). The roll compares the version verbatim (locals_names.tf).
locals {
  kubernetes_semver = var.kubernetes_version == null ? null : trimprefix(split("+", var.kubernetes_version)[0], "v")

  image_uses_kubernetes_version = can(regex("\\{(version|semver)\\}", coalesce(var.image_id, "-")))
  image_id = var.image_id == null ? null : replace(
    replace(var.image_id, "{version}", local.kubernetes_semver == null ? "{version}" : "v${local.kubernetes_semver}"),
    "{semver}", coalesce(local.kubernetes_semver, "{semver}"),
  )
}
