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

# Custom data of the scale set's instances (DESIGN.md decision 7). Custom
# data, not user data: Azure exposes user data through the instance
# metadata service to every process on the node.
locals {
  # The base64 of a gzip stream starts with H4sI (CONVENTIONS.md section 13).
  bootstrap_gzipped = startswith(var.bootstrap_data, "H4sI")

  # Labels the kubelet may register itself. It refuses to start with others
  # in the kubernetes.io and k8s.io namespaces, and NodeRestriction would
  # reject them (https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#noderestriction).
  kubelet_label_keys = [
    "beta.kubernetes.io/arch", "beta.kubernetes.io/instance-type", "beta.kubernetes.io/os",
    "failure-domain.beta.kubernetes.io/region", "failure-domain.beta.kubernetes.io/zone",
    "kubernetes.io/arch", "kubernetes.io/hostname", "kubernetes.io/os",
    "node.kubernetes.io/instance-type", "topology.kubernetes.io/region", "topology.kubernetes.io/zone",
  ]
  node_label_namespaces = { for k in keys(var.node_labels) : k => length(split("/", k)) > 1 ? split("/", k)[0] : "" }
  node_labels = {
    for k, v in var.node_labels : k => v
    if contains(local.kubelet_label_keys, k) || !(
      local.node_label_namespaces[k] == "kubernetes.io" || endswith(local.node_label_namespaces[k], ".kubernetes.io") ||
      local.node_label_namespaces[k] == "k8s.io" || endswith(local.node_label_namespaces[k], ".k8s.io")
      ) || (
      local.node_label_namespaces[k] == "kubelet.kubernetes.io" || endswith(local.node_label_namespaces[k], ".kubelet.kubernetes.io") ||
      local.node_label_namespaces[k] == "node.kubernetes.io" || endswith(local.node_label_namespaces[k], ".node.kubernetes.io")
    )
  }

  dropped_node_labels = sort([for k in keys(var.node_labels) : k if !contains(keys(local.node_labels), k)])

  # The shared node-labels fragment (templates/node_labels.tftpl, identical in
  # every pool module), sorted and comma-joined. It runs even without labels:
  # then it removes what an earlier boot wrote.
  node_labels_script = templatefile("${path.module}/templates/node_labels.tftpl", {
    node_labels = join(",", [for k in sort(keys(local.node_labels)) : "${k}=${local.node_labels[k]}"])
  })

  # cloud-provider-azure configuration for the worker identity.
  cloud_provider_config = jsonencode(merge(try(local.cluster.cloud_provider_config, {}), { userAssignedIdentityID = local.identity_client_id }))

  boothook = templatefile("${path.module}/templates/boothook.sh.tftpl", {
    cloud_provider_config = local.cloud_provider_config
    node_labels_script    = local.node_labels_script
  })

  # cloud-config payloads are wrapped in a MIME multipart: the boothook,
  # then the payload as an opaque base64 part that is never decoded here.
  # text/plain makes cloud-init detect the payload's type itself, which
  # keeps CABPK's "## template: jinja" header working; application/x-gzip
  # makes it decompress first (cloudinit/user_data.py). Ignition has no
  # such envelope and passes through unchanged, without node labels.
  user_data_mime = templatefile("${path.module}/templates/user_data.mime.tftpl", {
    boothook             = local.boothook
    boundary             = "==CAPTF-BOUNDARY=="
    payload_base64       = join("\n", regexall(".{1,76}", var.bootstrap_data))
    payload_content_type = local.bootstrap_gzipped ? "application/x-gzip" : "text/plain; charset=\"utf-8\""
  })
  custom_data = var.bootstrap_format == "cloud-config" ? base64encode(local.user_data_mime) : var.bootstrap_data

  # Azure takes at most 65535 bytes of custom data, which is 87380 base64
  # characters (https://learn.microsoft.com/rest/api/compute/virtual-machine-scale-sets/create-or-update#virtualmachinescalesetosprofile).
  custom_data_max_length = 87380
}
