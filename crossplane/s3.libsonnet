{
  s3:: {
    v1beta1:: {
      local apiVersion = { apiVersion: 's3.aws.crossplane.io/v1beta1' },
      bucket:: {
        local kind = { kind: 'Bucket' },
        new(name, namespace):: apiVersion + kind + self.mixin.metadata.withName(name) + self.mixin.metadata.withNamespace(namespace) + self.mixin.metadata.withFinalizers(),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
            withNamespace(namespace):: self + __metadataMixin({ namespace: namespace }),
            withFinalizers():: self + __metadataMixin({finalizers: ['finalizer.managedresource.crossplane.io']})
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            mixinInstance(spec):: __specMixin(spec),
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              mixinInstance(forProvider):: __forProviderMixin(forProvider),
              new(region, acl):: self + self.withLocationConstraint(region) + self.withAcl(acl),
              withLocationConstraint(region):: self + __forProviderMixin({locationConstraint: region}),
              withAcl(acl):: self + __forProviderMixin({acl: acl}),
              withAccelerateConfiguration(accelerateConfiguration):: self + __forProviderMixin({accelerateConfiguration: accelerateConfiguration}),
              withObjectLockEnabledForBucket(objectLockEnabledForBucket):: self + __forProviderMixin({objectLockEnabledForBucket: objectLockEnabledForBucket}),
              withServerSideEncryptionConfiguration(serverSideEncryptionConfiguration):: self + __forProviderMixin({serverSideEncryptionConfiguration: serverSideEncryptionConfiguration}),
              withLifecycleConfiguration(lifecycleConfiguration):: self + __forProviderMixin({lifecycleConfiguration: lifecycleConfiguration}),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              mixinInstance(providerConfigRef):: __providerConfigRefMixin(providerConfigRef),
              new(name=''):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
  },
}
