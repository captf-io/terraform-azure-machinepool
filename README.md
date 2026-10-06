<h1 align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="72" height="72" alt="CAPTF"></a>
  <br>
  terraform-azure-machinepool
</h1>

<p align="center">The CAPTF machine pool module for Microsoft Azure</p>

<p align="center">
  <a href="https://github.com/captf-io/terraform-azure-machinepool/actions/workflows/ci.yml"><img
    src="https://img.shields.io/github/actions/workflow/status/captf-io/terraform-azure-machinepool/ci.yml?branch=main&amp;label=build&amp;labelColor=161B3A&amp;style=flat-square"
    alt="build"></a>
  <a href="https://captf.io/docs/module-author/contract/index.html"><img
    src="https://img.shields.io/static/v1?label=contract&amp;message=v1alpha1&amp;color=A974FF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="contract v1alpha1"></a>
  <a href="https://captf.io/docs/"><img
    src="https://img.shields.io/static/v1?label=docs&amp;message=captf.io&amp;color=5B8CFF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="docs captf.io"></a>
  <a href="https://github.com/captf-io/terraform-azure-machinepool/blob/main/LICENSE.md"><img
    src="https://img.shields.io/static/v1?label=license&amp;message=Apache-2.0&amp;color=FFD84D&amp;labelColor=161B3A&amp;style=flat-square"
    alt="license Apache-2.0"></a>
</p>

> [!NOTE]
> **Pre-release.** CAPTF is `v1alpha1`: its API and its
> [module contract](https://captf.io/docs/module-author/contract/index.html)
> may still change between releases.

The `machinepool` role of the CAPTF Azure modules: the Terraform/OpenTofu root
module behind `TerraformMachinePool`. It creates a pool of worker nodes on one
Azure virtual machine scale set and implements the
[`v1alpha1` machinepool role](https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html).
The image `ghcr.io/captf-io/module-images/azure-machinepool` is built and published by
[module-images](https://github.com/captf-io/module-images) from this repository's releases.

The reasons behind every choice are in
[DESIGN.md](https://github.com/captf-io/terraform-azure-machinepool/blob/main/DESIGN.md),
decision 7.

## Using it

CAPTF runs this module from the module image
`ghcr.io/captf-io/module-images/azure-machinepool`: set the image on a
`TerraformMachinePool`'s `spec.source.image`, and the controller renders every
input. The module is also published to the Terraform Registry as
`captf-io/machinepool/azure` and can be called directly:

```hcl
module "machinepool" {
  source  = "captf-io/machinepool/azure"
  version = "~> 0.1"

  # The contract inputs the controller would render (captf_contract,
  # captf_cluster, captf_object, captf_tags, ...; see Inputs), and any
  # user variables.
}
```

Called directly, the module is a CAPTF root module first:

- it configures its own `provider "azurerm"` block, so the calling
  module cannot use `count`, `for_each` or `depends_on` on it, and the
  provider takes its credentials from the environment (see Identity
  Secret);
- its providers are pinned to exact versions (`versions.tf`), which the
  calling configuration has to accept;
- you set the `captf_*` inputs yourself.

## What it creates

Everything lands in the cluster's resource group, named in the cluster's
`exports`.

| Resource | Count | Purpose |
| --- | --- | --- |
| `azurerm_linux_virtual_machine_scale_set.pool_scale_set` | 1 | A uniform scale set of worker nodes, `upgrade_mode = "Manual"`, without overprovisioning, in the worker subnet, security group and application security group, running as the worker identity |
| `azurerm_monitor_autoscale_setting.pool_autoscale_setting` | 1 | Holds the scale set's capacity: pinned to `replicas`, or between the autoscaling bounds on CPU |
| `terraform_data.pool_default_zones` | 1 | The cluster's zones as of the first apply, for a pool without its own `failure_domains`: a cluster zone change never replaces the scale set (state only, untagged) |

It reads `azurerm_resources` (whether the scale set exists, listed
subscription-wide and filtered to the cluster's resource group, so a deleted
group cannot fail a refresh or destroy) and, when it
does, `azurerm_virtual_machine_scale_set` (its instances, their power states
and addresses) on every refresh. Without exports it creates nothing and
fails a precondition.

## Prerequisites

The same as the [machine role](https://github.com/captf-io/terraform-azure-machine/blob/main/README.md#prerequisites): a
cluster from the `cluster` role (or `external_cluster_exports`), an image
with kubeadm, the kubelet, a container runtime and cloud-init,
cloud-provider-azure in the workload cluster, the `Microsoft.Insights`
resource provider for the autoscale setting, and vCPU quota for twice the
pool while a version change replaces it.

## Inputs

Contract inputs used: `captf_cluster_outputs` (the cluster's exports),
`captf_tags`, `machinepool_name`, `replicas`, `bootstrap_data`,
`bootstrap_format`, `failure_domains`, `cluster_failure_domains`,
`kubernetes_version`, `node_labels` and `autoscaling`. `captf_contract` is
validated; `captf_cluster` and `captf_object` are declared and not used.

User variables, set through `spec.variables` of the TerraformMachinePool:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `accelerated_networking` | `bool` | `true` | Accelerated networking on the instances' NICs |
| `autoscaling_scale_in_cpu_percent` | `number` | `25` | With autoscaling, scale in by one below this average CPU over 10 minutes; below the scale-out threshold |
| `autoscaling_scale_out_cpu_percent` | `number` | `75` | With autoscaling, scale out by one above this average CPU over 10 minutes |
| `additional_tags` | `map(string)` | `{}` | Extra Azure tags on the scale set and autoscale setting. Keys starting with `captf.io_` or `captf.io/` are rejected; at most 44 |
| `boot_diagnostics` | `bool` | `true` | Serial console logs in Azure-managed storage |
| `encryption_at_host` | `bool` | `false` | Encrypt temporary disks and caches on the host; needs the `EncryptionAtHost` feature |
| `external_cluster_exports` | `any` | `null` | Exports (schema `captf.io/azure-cluster/v1`) for an externally managed TerraformCluster |
| `image_id` | `string` | `null` (required) | Managed image, Compute Gallery image (version), or community or shared gallery image (version) ID. `{version}` and `{semver}` become the pool's version, `v1.31.4` and `1.31.4`, without any `+suffix` |
| `ip_forwarding` | `bool` | `false` | IP forwarding on the NICs, for CNIs that route pod addresses natively |
| `os_disk_size_gib` | `number` | `128` | OS disk size, 30-4095 GiB |
| `os_disk_storage_account_type` | `string` | `"Premium_LRS"` | `Standard_LRS`, `StandardSSD_LRS`, `StandardSSD_ZRS`, `Premium_LRS` or `Premium_ZRS` |
| `spot` | `bool` | `false` | Spot instances, deleted on eviction, at most the on-demand price |
| `trusted_launch` | `bool` | `false` | Secure boot and vTPM; needs a generation 2 image built for it |
| `vm_size` | `string` | `"Standard_D4s_v5"` | Azure VM size of the instances |

## Outputs

| Name | Value |
| --- | --- |
| `provider_id` | `azure:///subscriptions/<subscription>/resourceGroups/<group, lowercase>/providers/Microsoft.Compute/virtualMachineScaleSets/<scale set>` |
| `provider_id_list` | Every instance the scale set lists, whatever its power state, sorted: `<provider_id>/virtualMachines/<instance ID>` |
| `replicas` | The scale set's capacity as last refreshed; `null` once the scale set is gone (Exceptions) |
| `instances` | Per instance: `provider_id`, `instance_id`, `addresses` (`InternalIP`, `Hostname`), `failure_domain` (its zone) and `state` |
| `health` | See Health |
| `autoscale_setting_id` | ARM ID of the autoscale setting (not a contract output) |
| `dropped_node_labels` | `node_labels` keys left out because the kubelet may not set them on itself (not a contract output) |
| `scale_set_id` | ARM ID of the current scale set (not a contract output) |
| `scale_set_name` | Name of the current scale set (not a contract output) |

**provider_id.** cloud-provider-azure writes `azure://` plus the scale set
instance's ARM ID with the resource group lowercased
(`ConvertResourceGroupNameToLower` in
[`azure_wrap.go`](https://github.com/kubernetes-sigs/cloud-provider-azure/blob/release-1.34/pkg/provider/azure_wrap.go)).
It finds the instance by its hostname, so Nodes must be named after it:
`nodeRegistration.name: '{{ ds.meta_data["local_hostname"] }}'`.

**Names.** The scale set is named
`<machinepool_name, made valid, at most 41 characters>-<8 hex>`, and its
instances' hostnames start with that name. The hash covers the pool's name
and everything that cannot change in place (see Lifecycle).

## Exports

The machinepool role reads the cluster's exports (schema
`captf.io/azure-cluster/v1`, [terraform-azure-cluster README](https://github.com/captf-io/terraform-azure-cluster/blob/main/README.md#exports))
and exports nothing.

## Identity Secret

The same Secret as the cluster role
([terraform-azure-cluster README](https://github.com/captf-io/terraform-azure-cluster/blob/main/README.md#identity-secret)). The pool lands
in the cluster's subscription from exports.

## Lifecycle

| Change | Effect |
| --- | --- |
| `bootstrap_data` (a token rotation, about every 7.5 minutes), `node_labels`, `image_id`, `vm_size`, `os_disk_size_gib`, `accelerated_networking`, `ip_forwarding`, `boot_diagnostics`, `encryption_at_host`, exports, tags | The scale set's model is updated in place; new instances use it, running ones are left alone |
| `replicas` (autoscaling disabled) | The autoscale setting pins the new capacity; Azure Autoscale applies it within about a minute |
| `autoscaling`, `autoscaling_scale_*_cpu_percent` | The autoscale setting gets the new bounds and rules |
| `kubernetes_version`, compared verbatim (a `+rke2rN` bump included) | A new scale set at the current capacity, then the old one is deleted |
| `failure_domains`, `spot`, `trusted_launch`, `os_disk_storage_account_type` | A new scale set as for a version change: Azure cannot change these on a scale set (Exceptions) |
| `cluster_failure_domains` (a cluster zone change) | Nothing: a pool without its own `failure_domains` keeps the cluster's zones as of its first apply (`terraform_data.pool_default_zones`) |

The provider block sets `roll_instances_when_required = false` and
`reimage_on_manual_upgrade = false`: with azurerm's defaults, every custom
data change, and so every token rotation, would reimage every instance.
The cost is that nothing rolls by itself, so a version change replaces the
scale set ("blue/green"): `create_before_destroy` creates the new one
before deleting the old one, so the pool briefly needs twice its quota.
There is no drain: pools have no Machines. Scheduled Events announce every
deletion 5 minutes ahead (`termination_notification`), for a termination
handler that drains.

## Bootstrap

As for the machine role
([terraform-azure-machine README](https://github.com/captf-io/terraform-azure-machine/blob/main/README.md#bootstrap)), cloud-config
bootstrap data is wrapped in a MIME multipart with a boothook, and Ignition
passes through unchanged (gzipped Ignition fails a precondition). The
boothook writes `/etc/kubernetes/azure.json` (when absent) for the worker
identity and runs the node-labels fragment shared by every CAPTF pool module
(`templates/node_labels.tftpl`, CONVENTIONS.md section 13):

- in `/etc/default/kubelet` and `/etc/sysconfig/kubelet`, where their
  directories exist, it replaces a block marked `# captf-node-labels` with
  `KUBELET_EXTRA_ARGS="<the image's value> --node-labels=<sorted labels>"`,
  which kubeadm's kubelet drop-in reads; the image's own line is never
  edited, so every boot yields the same file;
- it writes `node-label+:` to
  `/etc/rancher/rke2/config.yaml.d/50-captf-node-labels.yaml` for RKE2;
- without labels it removes both.

Labels in the `kubernetes.io` and `k8s.io` namespaces that the kubelet may
not set on itself (NodeRestriction; for example
`node-role.kubernetes.io/worker`) are dropped and listed in the
`dropped_node_labels` output. Ignition bootstrap data with labels left to
render fails a precondition: the module cannot extend it without parsing
it.

## Tags

The scale set and the autoscale setting get `local.tags`:
`additional_tags`, then the `captf_tags` with `/` replaced by `_`. The
captf tags win. Not taggable from this module: the instances, their NICs
and OS disks, which Azure creates for the scale set. They live in the
cluster's resource group, which is tagged.

## Health

`data.azurerm_virtual_machine_scale_set` fails on a missing scale set, so
the module first lists it with `data.azurerm_resources` and reads its
instances only when the listing finds it. Each instance's power state maps
like a machine's: `running` to `running`; `starting` or none yet to
`pending`; `stopping`, `stopped`, `deallocating`, `deallocated` to
`stopped`; anything else to `unknown`. Rows apply in order
(CONVENTIONS.md section 10). Azure lists an instance until it is
deleted, so none maps to `terminated`: a deleted instance leaves
`provider_id_list` and CAPI deletes its Node.

| Reading | `state` | `healthy` | `reasons` |
| --- | --- | --- | --- |
| Scale set gone (the refresh dropped it) | `terminated` | `false` | `ScaleSetNotFound` |
| Capacity 0 | `running` | `true` | `[]` |
| Not listed yet (first apply, new generation) or listed without instances | `pending` | `false` | `NoMembers`; `provider_id_list` is `[]` until the next refresh |
| Some instance stopped or in an unknown state | the worst of `degraded`, `stopped`, `unknown` | `false` | `<reason>:<hostname>` per affected instance (`PowerState/<state>`, or `UnknownState`) |
| Otherwise | `running` | only at capacity with every instance running | starting instances as `PowerState/starting:<hostname>`, plus `ScalingInProgress` when the count differs from the capacity |

## Limitations

- Workers only: the control plane uses the machine role.
- Changes reach new instances only (Lifecycle); a version change is the
  way to roll the pool.
- Capacity changes go through Azure Autoscale and take about a minute to
  reach the scale set; `replicas` reflects them at the next refresh.
- A scale set holds at most 1000 instances, but every refresh reads each
  instance's NICs with one ARM call each (the azurerm scale set data
  source); refreshes of pools beyond a few hundred instances may meet ARM
  read throttling. Keep pools to about 200 instances, or raise
  `spec.membershipRefreshIntervalSeconds`.
- The scale set read fails if an instance disappears between listing it
  and reading its NICs; the next refresh succeeds.
- Azure public cloud only.

## Exceptions

- **`pool/autoscaling-ignore-changes`** (tfcapi-lint warning, allowed in
  this repository's `Makefile` by `TFCAPI_LINT_ALLOW`). The scale set ignores changes to `instances`, its desired
  count in azurerm 2.x and later, which the check's pattern does not know
  (it knows `sku.capacity`); and Azure Autoscale holds the capacity in both
  modes, so the scale set reaches `var.autoscaling` only through locals and
  the autoscale setting.
- Changing `failure_domains`, `spot`, `trusted_launch` or
  `os_disk_storage_account_type` replaces the scale set like a version
  change: azurerm 5.7.0 cannot update these in place (ForceNew, or zones
  that may only grow), and the replacement needs a new name
  (CONVENTIONS.md section 13 asks for other replacements to be listed here).
- The roll is a new scale set generation (name hash plus
  `create_before_destroy`), not `terraform_data.kubernetes_version_roll`:
  a same-named replacement would collide with the old scale set.
- The `membership_excludes_terminated` test asserts that stopped and
  deallocated instances stay members: Azure has no terminated instance state
  to exclude. The `ScaleSetNotFound` reading has no test: a mock provider
  never drops a resource on refresh.
- `replicas` is `null` once the scale set is gone (deleted out of band):
  the capacity is then unknown, which the contract's null ("not yet known")
  says, and an empty `provider_id_list` with an unknown capacity keeps
  CAPI's guard against deleting every Node engaged.

## Examples

[`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-azure-machinepool/blob/main/examples/cluster-kubeadm.yaml) creates a
MachinePool with this role. An autoscaled pool:

```yaml
apiVersion: cluster.x-k8s.io/v1beta2
kind: MachinePool
metadata:
  name: demo-pool-0
  annotations:
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size: "2"
    cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size: "10"
spec:
  clusterName: demo
  template:
    spec:
      clusterName: demo
      version: v1.34.1
      bootstrap:
        configRef:
          apiGroup: bootstrap.cluster.x-k8s.io
          kind: KubeadmConfig
          name: demo-pool-0
      infrastructureRef:
        apiGroup: infrastructure.cluster.x-k8s.io
        kind: TerraformMachinePool
        name: demo-pool-0
---
apiVersion: infrastructure.cluster.x-k8s.io/v1alpha1
kind: TerraformMachinePool
metadata:
  name: demo-pool-0
  labels:
    cluster.x-k8s.io/cluster-name: demo
spec:
  source:
    image: ghcr.io/captf-io/module-images/azure-machinepool:v0.1.0-opentofu
  variables:
    image_id: /communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/{semver}
```

## Developing

The host needs make, podman (or docker with `ENGINE=docker`), jq and Go;
every other tool runs in a digest-pinned container. `make verify` is the
gate. Targets (`make help` lists them):

- `fmt`: format the module with terraform fmt and tofu fmt, in place.
- `fmt-check`: fail on any file terraform fmt or tofu fmt would change.
- `validate`: init and validate on both runtimes and on their floors
  (Terraform 1.5.7, OpenTofu 1.6.3).
- `unit-test`: terraform test and tofu test with mocked providers.
- `tflint`: tflint with the terraform ruleset and the cloud ruleset, per
  `.tflint.hcl`.
- `tfcapi-lint`: `tfcapi-lint module --strict`, built from `PROVIDER_DIR`
  (the cluster-api-provider-terraform checkout; defaults to
  `../cluster-api-provider-terraform`, a sibling clone; the check is skipped
  when it is absent).
- `scan`: trivy config over the repository; ignores live in
  `.trivyignore.yaml`.
- `check-conventions`: `hack/check-layout.sh` and `hack/check-tags.sh`.
- `shellcheck`: shellcheck over `hack/` and every shell template, rendered
  with placeholders.
- `check-headers` / `fix-headers`: fail on, or add, a missing Apache-2.0
  license header.
- `verify`: everything above, in parallel groups.
- `clean`: remove `build/`.

This repository holds the code only; it builds no images. The module images
are built from its releases by [module-images](https://github.com/captf-io/module-images).

<br>
<p align="center">
  <img
    src="https://captf.io/assets/readme/divider.svg"
    width="100%" height="4" alt="">
</p>
<p align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="40" height="40" alt="CAPTF"></a>
  <br>
  <a href="https://captf.io/docs/"
    ><b>Documentation</b></a> ·
  <a href="https://captf.io/docs/getting-started/quick-start.html"
    ><b>Quick start</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/CONTRIBUTING.md"
    ><b>Contributing</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/SECURITY.md"
    ><b>Security</b></a>
  <br>
  <sub>Built for
    <a href="https://cluster-api.sigs.k8s.io/">Cluster API</a>.
    <a href="https://github.com/captf-io/terraform-azure-machinepool/blob/main/LICENSE.md"
    >Apache 2.0</a>.</sub>
</p>
