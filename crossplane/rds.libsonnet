{
  parameterGroup(name, family, region, parameters, labels={}):: {
    apiVersion: 'rds.aws.upbound.io/v1beta1',
    kind: 'ParameterGroup',
    metadata: {
      name: '%s-%s-root' % [name, family],
      labels: labels {
        dbInstance: name,
      },
    },
    spec: {
      forProvider: {
        region: region,
        family: family,
        parameter: parameters,
      },
    },
  },

  rdsInstance(name, region, parameters, serviceNamespace, secretName, tagSets, annotations={}, labels={}):: {
    apiVersion: 'rds.aws.upbound.io/v1beta2',
    kind: 'Instance',
    metadata: {
      name: name,
      annotations: annotations,
      labels: labels {
        dbInstance: name,
      },
    },
    spec: {
      deletionPolicy: 'Orphan',
      forProvider: parameters {
        region: region,
        identifier: name,
        passwordSecretRef: {
          name: 'master-%s-rds' % name,
          key: 'password',
          namespace: serviceNamespace,
        },
        tags+: {
          namespace: serviceNamespace,
        } + tagSets,
      },
      writeConnectionSecretToRef: {
        name: secretName,
        namespace: serviceNamespace,
      },
    },
  },

  rdsInstanceReadOnly(name, region, parameters, serviceNamespace, secretName, tagSets, annotations={}, labels={}):: {
    apiVersion: 'rds.aws.upbound.io/v1beta2',
    kind: 'Instance',
    metadata: {
      name: name,
      annotations: annotations,
      labels: labels {
        dbInstance: name,
      },
    },
    spec: {
      deletionPolicy: 'Orphan',
      managementPolicies: ['Observe', 'Create', 'Update', 'Delete'],
      forProvider: parameters {
        region: region,
        identifier: name,
        tags+: {
          namespace: serviceNamespace,
        } + tagSets,
      },
      writeConnectionSecretToRef: {
        name: secretName,
        namespace: serviceNamespace,
      },
    },
  },

}
