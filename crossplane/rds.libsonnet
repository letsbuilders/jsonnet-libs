{
  parameterGroup(name, family, region, parameters):: {
    apiVersion: 'rds.aws.upbound.io/v1beta1',
    kind: 'ParameterGroup',
    metadata: {
      name: '%s-%s-root' % [name, family],
    },
    spec: {
      forProvider: {
        region: region,
        family: family,
        parameter: parameters,
      },
    },
  },

  rdsInstance(name, region, parameters, serviceNamespace, secretName, annotations={}, labels={}):: {
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
        passwordSecretRef: {
          name: 'master-%s-rds' % name,
          key: 'password',
          namespace: serviceNamespace,
        },
        tags+: {
          namespace: serviceNamespace,
        },
      },
      writeConnectionSecretToRef: {
        name: secretName,
        namespace: serviceNamespace,
      },
    },
  },

  rdsInstanceReadOnly(name, region, parameters, serviceNamespace, secretName, annotations={}, labels={}):: {
    apiVersion: 'rds.aws.upbound.io/v1beta2',
    kind: 'Instance',
    metadata: {
      name: '%s-ro' % name,
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
        tags+: {
          namespace: serviceNamespace,
        },
      },
      writeConnectionSecretToRef: {
        name: '%s-ro' % secretName,
        namespace: serviceNamespace,
      },
    },
  },

}
