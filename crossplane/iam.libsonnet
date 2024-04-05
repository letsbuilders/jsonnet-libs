{
  role(name, trustPolicy, annotations={}, labels={}):: {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'Role',
    metadata: {
      annotations: annotations,
      labels: labels {
        role: name,
      },
      name: name,
    },
    spec: {
      forProvider: {
        assumeRolePolicy: std.manifestJsonEx(trustPolicy, '  '),
      },
    },
  },
  rolePolicyAttachment(name, roleName, policyName, annotations={}, labels={}):: {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'RolePolicyAttachment',
    metadata: {
      annotations: annotations,
      labels: labels,
      name: name,
    },
    spec: {
      forProvider: {
        policyArnSelector: {
          matchLabels: {
            policy: policyName,
          },
        },
        roleSelector: {
          matchLabels: {
            role: roleName,
          },
        },
      },
    },
  },
  policy(name, resourcePolicy, annotations={}, labels={}):: {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'Policy',
    metadata: {
      labels: labels {
        policy: name,
      },
      annotations: annotations,
      name: name,
    },
    spec: {
      forProvider: {
        policy: resourcePolicy,
      },
    },
  },
  rolePolicy(name, roleName, resourcePolicy, annotations={}, labels={}):: {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'RolePolicy',
    metadata: {
      annotations: annotations,
      labels: labels,
      name: name,
    },
    spec: {
      forProvider: {
        policy: resourcePolicy,
        roleSelector: {
          matchLabels: {
            role: roleName,
          },
        },
      },
    },
  },
}
