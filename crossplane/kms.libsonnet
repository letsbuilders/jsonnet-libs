{
  key(name, region, policy, annotations={}, labels={}):: {
    apiVersion: 'kms.aws.upbound.io/v1beta1',
    kind: 'Key',
    metadata: {
      annotations: annotations,
      labels: labels {
        key: name,
      },
      name: name,
    },
    spec: {
      deletionPolicy: 'Orphan',
      forProvider: {
        region: region,
        policy: std.manifestJsonEx(policy, '  '),
        description: 'Created with Crossplane',
        tags: {
          name: name,
        },
      },
    },
  },
  keyAlias(name, region, annotations={}, labels={}):: {
    apiVersion: 'kms.aws.upbound.io/v1beta1',
    kind: 'Alias',
    metadata: {
      annotations: annotations,
      labels: labels {
        key: name,
      },
      name: name,
    },
    spec: {
      forProvider: {
        region: region,
        targetKeyIdSelector: {
          matchLabels: {
            key: name,
          },
        },
      },
    },
  },
}
