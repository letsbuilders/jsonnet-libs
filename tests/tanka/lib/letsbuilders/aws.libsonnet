{
  aws: (import 'crossplane/aws-utils.libsonnet') + {
    _config+:: {
      aws+: {
        region: 'eu-west-1',
        clusterName: 'test1',
        accountId: '1111111111111',
        accountName: 'letsbuild-test',
        oidcUrl: 'oidc.eks.eu-west-1.amazonaws.com/id/TESTTESTTESTTESTTESTTEST',
        crossplaneProvider: 'aws-provider',
        clusterDomain: 'test.lb4.co',
      },
      serviceName: 'test',
      serviceNamespace: 'test',
    },
    iamRole::: super.iamRole,
    bucket::: super.bucket,

  },
}
