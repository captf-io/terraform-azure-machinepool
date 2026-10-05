# Design: terraform-azure-machinepool

Why this module looks the way it does. Each decision names the evidence it
rests on; anything not yet checked against a real subscription is listed
under "Unverified" and must be confirmed on the first reviewed apply.

Pins: `hashicorp/azurerm` 5.7.0. Runtimes: Terraform >= 1.5, OpenTofu >= 1.6.
Conventions: [CONVENTIONS.md](CONVENTIONS.md). Contract:
<https://captf.io/docs/module-author/contract/v1alpha1/>.

This is the `machinepool` role. The decision and Unverified numbers are the same
in every terraform-azure-* repository, and the code cites them: a decision
that only concerns another role is a one-line stub that links to the repository
that owns it, and Unverified items of other roles are left out. The other roles:
[terraform-azure-cluster](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md) and
[terraform-azure-machine](https://github.com/captf-io/terraform-azure-machine/blob/main/DESIGN.md).

## Scope

- Bring-your-own network: the VNet, subnets and egress (NAT Gateway or
  firewall) exist before the cluster.
- Node identities (user-assigned managed identities) are created by the
  cluster role by default; variables take existing ones.
- Variable names follow the family table of CONVENTIONS.md section 8, which also names the pool's
  `autoscaling_scale_out_cpu_percent` and
  `autoscaling_scale_in_cpu_percent`.
- `admin_ssh_public_key` is required: Azure Linux VMs need an SSH key or a
  password even when nobody logs in, and the module does not invent one.
  The cluster role takes it and exports it.

## Decisions

### 1. One resource group per cluster

Concerns the cluster role: see [terraform-azure-cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#1-one-resource-group-per-cluster).

### 2. API load balancer and hairpin

Concerns the cluster role: see [terraform-azure-cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#2-api-load-balancer-and-hairpin).

### 3. Network security groups

Concerns the cluster role: see [terraform-azure-cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#3-network-security-groups).

### 4. Node identities

Concerns the cluster role: see [terraform-azure-cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#4-node-identities).

### 5. provider_id

`azure:///subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<name>`.
cloud-provider-azure v1.37.0 returns the ARM ID through
`ConvertResourceGroupNameToLower` (`pkg/provider/azure_wrap.go`), so the
module builds the ID from a lowercased subscription and resource group and
requires a lowercase resource group name. Re-checked on `release-1.34`:
`availabilitySet.GetInstanceIDByNodeName` (`azure_standard.go`) returns
`ConvertResourceGroupNameToLower(*machine.ID)` for the VM it finds by Node
name, so the Node must be named after the VM: the examples set
`nodeRegistration.name: '{{ ds.meta_data["local_hostname"] }}'`, and the
VM name and `computer_name` are both `machine_name` made valid (lowercase
`[a-z0-9-]`, at most 64; otherwise cut to 55 plus `-` and 8 hex of its
sha256). Scale set instances:
`.../virtualMachineScaleSets/<vmss>/virtualMachines/<instance-id>`
(`azure_vmss.go` `vmssVMProviderIDRE`).

### 6. Machine

Concerns the machine role: see [terraform-azure-machine DESIGN.md](https://github.com/captf-io/terraform-azure-machine/blob/main/DESIGN.md#6-machine).

### 7. Machine pool

- Uniform `azurerm_linux_virtual_machine_scale_set`, `upgrade_mode =
  "Manual"`, `overprovision = false` (extra VMs would run kubeadm join and
  appear as Nodes), `single_placement_group = false`, termination
  notifications on.
- In azurerm 5.7.0 a `custom_data` change marks instances for update
  (`linux_virtual_machine_scale_set_resource.go` update: `if
  d.HasChange("custom_data") { updateInstances = true }`), and
  `performUpdate` (`virtual_machine_scale_set_update.go`) then calls
  `upgradeInstancesForManualUpgradePolicy` when
  `features.virtual_machine_scale_set.roll_instances_when_required` is true;
  the defaults are `roll_instances_when_required = true` and
  `reimage_on_manual_upgrade = true` (`internal/features/defaults.go`).
  Bootstrap data rotates every 7.5 minutes. The pool's provider block
  therefore sets both to false (field names confirmed in the 5.7.0 provider
  schema and `internal/provider/features.go`): a rotation updates only the
  model; new instances use it. `custom_data` is not ForceNew on the scale
  set.
- That also disables rolling on a version change, so a Kubernetes version
  change is a blue/green replacement: the scale set name carries a hash of
  the version compared verbatim (a `+rke2rN` bump rolls too; the first
  draft stripped the suffix, so an RKE2 patch never reached the pool), and
  `create_before_destroy` brings the new set up
  at the current capacity before the old one is deleted. The pool's group
  `provider_id` changes, which the controller allows. No drain (pools have
  none in v1); quota briefly doubles.
- The roll uses the name generation, not CONVENTIONS.md section 13's
  `terraform_data.kubernetes_version_roll`: a `replace_triggered_by` under
  an unchanged name would make `create_before_destroy` create a second
  scale set of the same name.
- Pool health follows CONVENTIONS.md section 10: a missing scale set is
  `terminated` (`ScaleSetNotFound`); `pending` with `NoMembers` only while
  the scale set is not listed or has no members; starting members leave
  it `running` and not healthy, named in the reasons, with
  `ScalingInProgress` on a count mismatch.
- The hash covers more than the version: every input whose change azurerm
  5.7.0 cannot apply in place (ForceNew: `priority`, `eviction_policy`,
  `secure_boot_enabled`, `vtpm_enabled`, `os_disk.storage_account_type`;
  and `zones`, which `ForceNewIfChange` replaces when one is removed; only
  explicit `failure_domains` count, since zones inherited from the cluster
  are pinned at the first apply by `terraform_data.pool_default_zones`, so
  a cluster zone change never replaces a pool). A
  ForceNew change under an unchanged name would make
  `create_before_destroy` create a second scale set of the same name, which
  the provider refuses ("already exists - to be managed via Terraform this
  resource needs to be imported"). So `spot`, `trusted_launch`,
  `os_disk_storage_account_type` and `failure_domains` roll the pool like a
  version change; the README lists them under Exceptions.
- Spot instances use `eviction_policy = "Delete"`: an evicted instance
  leaves the membership, and Autoscale restores the capacity.
- `azurerm_monitor_autoscale_setting` holds the capacity in both modes
  (disabled: min = max = default = replicas, no rules; enabled: min/max
  from `var.autoscaling`, default = min, plus CPU rules at
  `autoscaling_scale_out_cpu_percent` and `autoscaling_scale_in_cpu_percent`,
  75 and 25 by default) and the scale set
  has `ignore_changes = [instances]`; the provider reads the current
  capacity when `instances` is ignored ("in-case ignore_changes is being
  used"). With autoscaling enabled the default is `min`, not `replicas`:
  the controller renders `replicas` from the observed capacity, so a
  default that followed it would turn every scale into drift. tfcapi-lint's regex does not know
  `instances` (it knows `sku.capacity` from azurerm 2.x) and warns
  (`pool/autoscaling-ignore-changes`, allowed with this reason).
- Membership: `data.azurerm_virtual_machine_scale_set` `instances` (paged,
  no truncation), guarded by `data.azurerm_resources` like the machine's
  VM read. Azure has no terminated instance state; a deleted instance
  leaves the list.

### 8. Health

Pool health follows CONVENTIONS.md section 10 (decision 7): a missing scale set is
`terminated` (`ScaleSetNotFound`); `pending` with `NoMembers` only while
the scale set is not listed or has no members; starting members leave
it `running` and not healthy, named in the reasons, with
`ScalingInProgress` on a count mismatch. A resource deleted out of band leaves the
state on refresh; every output reads such attributes through `try()` or
`one()`. VM power states are the machine role's ([machine DESIGN.md](https://github.com/captf-io/terraform-azure-machine/blob/main/DESIGN.md#8-health)).

### 9. Tags

Azure tag names cannot contain `< > % & \ ? /`: `captf.io/cluster` →
`captf.io_cluster`. `additional_tags` may hold 44 tags (Azure's 50 minus
the six captf tags). Values up to 256 characters (longer: 247 plus `-` plus
8 hex of sha256). Not taggable: role assignments, security rules, load
balancer pools, probes and rules, NIC associations, and the OS disks and
NICs a scale set creates; the cluster resource group is the attribution
boundary for those.

### 10. Credentials

Identity Secret: `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`,
`ARM_CLIENT_SECRET`, `ARM_USE_CLI=false` (no `az` CLI in the image), or
a client certificate: `ARM_CLIENT_CERTIFICATE` (base64) or
`ARM_CLIENT_CERTIFICATE_PATH` (a file under `/var/run/captf/credentials/`),
with `ARM_CLIENT_CERTIFICATE_PASSWORD`. The provider block sets
`resource_provider_registrations = "none"` (registration of Compute,
Network, ManagedIdentity, Authorization and Insights is a prerequisite) and
`subscription_id` from exports for machine and pool. The job's identity
needs Contributor on the subscription (to create resource groups; it also
covers joining the subnets, which must be in that subscription) and Role
Based Access Control Administrator with a condition limiting assignable
roles. Network Contributor on the network's group is only needed if
Contributor is narrowed.

### 11. Region and zones

The location is the brought virtual network's: NICs cannot use a subnet in
another region, so a `location` variable could only be wrong. The zones are
the cluster's, published in its exports; [cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#11-region-and-zones)
describes how brought dependencies are found without blocking a destroy.
The pool's listing of its scale set works the same way.

### 12. Tooling

Concerns how the module images are tested, not this repository: see [azure-modules DESIGN.md](https://github.com/captf-io/azure-modules/blob/main/DESIGN.md#12-tooling).

## Exports consumed

The machinepool reads the cluster's `captf.io/azure-cluster/v1` exports, listed
under "Exports" in the [cluster DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md#exports-captfioazure-clusterv1)
and documented in the
[cluster README](https://github.com/captf-io/terraform-azure-cluster#exports).
For an externally managed TerraformCluster, `external_cluster_exports`
takes an object of that shape.

## Unverified

**3.** Azure Autoscale holding min = max = default with no rules, including
0 for a pool scaled to zero, and how long it takes to apply a change.

**4.** The ARM `custom_data` limit as 65535 decoded bytes (87380 base64
characters).

**6.** Resolved: the CAPZ reference images do not support trusted launch (CAPZ
docs), so it is off by default.

**7.** cloud-init running the Jinja template of a `text/plain` part inside a
multipart (CABPK's `## template: jinja` header) on the CAPZ images'
cloud-init version.

**9.** cloud-provider-azure with `vmType: "vmss"` handling the standalone VMs of
the machine role next to the scale sets (CAPZ uses `vmss` for the same
mix).

**10.** The CAPZ community gallery publishing an image for every Kubernetes
version a cluster rolls to.

**13.** ARM read throttling of the scale set data source (one NIC call per
instance per refresh) for pools beyond about 200 instances.

The numbers are those of the other terraform-azure-* repositories; the gaps are
items of the other roles.

## Rejected alternatives

- VMSS `upgrade_mode = Rolling` / default VMSS features (reimages on every
  rotation).
- Requiring users to write `/etc/kubernetes/azure.json` through
  KubeadmConfig `files` (names they cannot know; [machine DESIGN.md](https://github.com/captf-io/terraform-azure-machine/blob/main/DESIGN.md#6-machine), decision 6).
- `user_data` (exposed through IMDS).
- A generated or "sealed" SSH key (state secret, or trust in an unprovable
  claim).
