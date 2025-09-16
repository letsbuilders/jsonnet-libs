{
  new:: {
    apiVersion: 'eksctl.io/v1alpha5',
    kind: 'ClusterConfig',
  },

  metadata: {
    withName(name):: { metadata+: { name: name } },
    withRegion(region):: { metadata+: { region: region } },
    withVersion(version):: { metadata+: { version: version } },
  },

  cloudWatch: {
    withClusterLogging(clusterLogging):: { cloudWatch+: { clusterLogging: clusterLogging } },
  },

  iam: {
    withOIDC(withOIDC):: { iam+: { withOIDC: withOIDC } },
    withServiceAccounts(serviceAccounts):: { iam+: { serviceAccounts: serviceAccounts } },
  },

  vpc: {
    withId(id):: { vpc+: { id: id } },
    withCIDR(cidr):: { vpc+: { cidr: cidr } },
    withSubnets(subnets):: { vpc+: { subnets: subnets } },
    withSharedNodeSecurityGroup(sharedNodeSecurityGroup):: { vpc+: { sharedNodeSecurityGroup: sharedNodeSecurityGroup } },
  },

  addons: {
    withAddons(addons):: {
      addons: [
        addons[a] {
          name: a,
          configurationValues: std.toString(super.configurationValues),
        }
        for a in std.objectFields(addons)
      ],
    },
  },

  managedNodeGroups: {
    withManagedNodeGroups(managedNodeGroups):: { managedNodeGroups: managedNodeGroups },
  },

  nodeGroups: {
    withNodeGroups(nodeGroups):: { nodeGroups: nodeGroups },
  },
}
