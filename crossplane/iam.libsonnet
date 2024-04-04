  local role(name, trustPolicy) = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'Role',
    metadata: {
      labels: {
        'role': name,
      },
      name: name,
    },
    spec: {
      forProvider: {
        assumeRolePolicy: trustPolicy,
      },
    },
  };
  local rolePolicyAttachment(name, roleName, policyName) = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'RolePolicyAttachment',
    metadata: {
      labels: {
        'role-policy': '%s-%s' % [roleName, policyName],
      },
      name: name,
    },
    spec: {
      forProvider: {
        policyArnSelector: {
          matchLabels: {
            'policy': policyName,
          },
        },
        roleSelector: {
          matchLabels: {
            'role': roleName,
          },
        },
      },
    },
  };
  local policy(name, resourcePolicy) = {
    apiVersion: 'iam.aws.upbound.io/v1beta1',
    kind: 'Policy',
    metadata: {
      labels: {
        'policy': name,
      },
      name: name,
    },
    spec: {
      forProvider: {
        policy: resourcePolicy,
      },
    },
  };

  {
    role:: role,
    rolePolicyAttachment:: rolePolicyAttachment,
    policy:: policy,
  }