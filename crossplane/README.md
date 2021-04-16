All resources configured by `aws-utils.libsonnet` are hidden by default. To render their manifests unhide them, for example:
```jsonnet
{
  aws: (import 'github.com/letsbuilders/jsonnet-libs/crossplane/aws-utils.libsonnet')
  + { bucket::: super.bucket }
} 
```

### Add a bucket for your service

```jsonnet
{
  aws: (import 'github.com/letsbuilders/jsonnet-libs/crossplane/aws-utils.libsonnet') + {
    _config+:: {
      aws+: {
        oidcUrl: '<oidcUrl>',
        accountId: '<accountId>',
        clusterName: '<clusterName>',
        accountName: '<accountName>',
        region: '<region>'
      },
      serviceName: '<serviceName>',
      serviceNamespace: '<serviceNamespace>',
    },
    // Unhide resources
    bucket::: super.bucket,
    iamRole::: super.iamRole,
    
  },
  // Add role annotations to your service account
  rbac+: { service_account+: s.aws.overrides.service_account },
}
```
