local manifestYamlDoc(obj) = std.manifestYamlDoc(obj, indent_array_in_object=true, quote_keys=false);

local normalizeVersion(version) = std.strReplace(version, '.', '-');

local shortCheckSum(config) =
  local checksumArr = std.stringChars(std.md5(std.toString(config)));
  std.join('', checksumArr[0:4]);

// Returns a normalized name for a single-AZ node group
local singleAZNodeGroupName(name, az, version, config) =
  std.format(
    '%s-%s-%s-%s', [
      name,
      az,
      normalizeVersion(version),
      shortCheckSum(config),
    ],
  );

// Returns a normalized name for a multi-AZ node group
local multiAZNodeGroupName(name, version, config) =
  std.format(
    '%s-%s-%s', [
      name,
      normalizeVersion(version),
      shortCheckSum(config),
    ],
  );

local singleAZNodeGroups(name, config) = [

  config.managedNodeGroups[name] {
    name: singleAZNodeGroupName(name, az, config.version, config.managedNodeGroups[name]),
    availabilityZones: [az],
    subnets: [super.subnets[az].id],
    tags+: {
      ['k8s.io/cluster-autoscaler/%s' % config.name]: 'owned',
      'k8s.io/cluster-autoscaler/enabled': 'TRUE',
    },
  }

  // iterate over availability zones or subnets if availabilityZones is hidden
  for az in (
    if std.objectHas(config.managedNodeGroups[name], 'availabilityZones')
    then config.managedNodeGroups[name].availabilityZones
    else std.objectFields(config.managedNodeGroups[name].subnets)
  )
];

local multiAZNodeGroup(name, config) = [
  config.managedNodeGroups[name] {
    name: multiAZNodeGroupName(name, config.version, config.managedNodeGroups[name]),
    [if std.objectHas(config.managedNodeGroups[name], 'subnets') then 'subnets' else null]:
      if std.type(config.managedNodeGroups[name].subnets) == 'object' then
        // Transform a availabilityZone -> subnetId mapping into a list of subnets if field `subnets` is unhidden
        [super.subnets[az].id for az in std.objectFields(super.subnets)]
      else
        config.managedNodeGroups[name].subnets,

  },
];

local multiAZUnmanagedNodeGroup(name, config) = [
  config.nodeGroups[name] {
    name: multiAZNodeGroupName(name, config.version, config.nodeGroups[name]),

    [if std.objectHas(config.nodeGroups[name], 'subnets') then 'subnets' else null]:
      if std.type(config.nodeGroups[name].subnets) == 'object' then
        // Transform a availabilityZone -> subnetId mapping into a list of subnets if field `subnets` is unhidden
        [super.subnets[az].id for az in std.objectFields(super.subnets)]
      else
        config.nodeGroups[name].subnets,

  },
];

local eksctlConfig(config) =
  local defaultConfig = import 'defaultConfig.libsonnet';

  local clusterConfig = import 'clusterConfig.libsonnet';

  local c = defaultConfig + config;

  local managedNodeGroups = std.flattenArrays([
    if name == 'management' then
      singleAZNodeGroups('management', c)
    else if name == 'data' then
      singleAZNodeGroups('data', c)
    else if name == 'frontend' then
      singleAZNodeGroups('frontend', c)
    else if name == 'stable' then
      singleAZNodeGroups('stable', c)
    else
      multiAZNodeGroup(name, c)

    for name in std.objectFields(c.managedNodeGroups)
  ]);

  local nodeGroups = std.flattenArrays([
    multiAZUnmanagedNodeGroup(name, c)
    for name in std.objectFields(c.nodeGroups)
  ]);

  clusterConfig.new +
  // cluster metadata
  clusterConfig.metadata.withName(c.name) +
  clusterConfig.metadata.withRegion(c.region) +
  clusterConfig.metadata.withVersion(c.version) +
  // cluster-wide iam settings
  clusterConfig.iam.withOIDC(c.iam.withOIDC) +
  clusterConfig.iam.withServiceAccounts(c.iam.serviceAccounts) +
  // VPC settings
  (
    if std.isEmpty(c.vpc.cidr) then
      clusterConfig.vpc.withId(c.vpc.id) +
      clusterConfig.vpc.withSubnets(c.vpc.subnets) +
      (
        if std.objectHas(c.vpc, 'sharedNodeSecurityGroup') then
          clusterConfig.vpc.withSharedNodeSecurityGroup(c.vpc.sharedNodeSecurityGroup)
        else
          {}
      )
    else
      clusterConfig.vpc.withCIDR(c.vpc.cidr)
  ) +

  // EKS Addons
  clusterConfig.addons.withAddons(c.addons) +
  // CloudWatch
  clusterConfig.cloudWatch.withClusterLogging(c.cloudWatch.clusterLogging) +
  // Nodegroups
  clusterConfig.managedNodeGroups.withManagedNodeGroups(managedNodeGroups) +
  clusterConfig.nodeGroups.withNodeGroups(nodeGroups);

local yamlManifest(cluster) =
  // Setting structure of the rendered YAML manifest
  std.lines([
    manifestYamlDoc({ apiVersion: cluster.apiVersion }),
    manifestYamlDoc({ kind: cluster.kind }),
    manifestYamlDoc({ metadata: cluster.metadata }),
    manifestYamlDoc({ iam: cluster.iam }),
    manifestYamlDoc({ vpc: cluster.vpc }),
    manifestYamlDoc({ addons: cluster.addons }),
    manifestYamlDoc({ cloudWatch: cluster.cloudWatch }),
    manifestYamlDoc({ managedNodeGroups: cluster.managedNodeGroups }),
    manifestYamlDoc({ nodeGroups: cluster.nodeGroups }),
  ]);

{
  config:: eksctlConfig,
  yamlManifest:: yamlManifest,
}
