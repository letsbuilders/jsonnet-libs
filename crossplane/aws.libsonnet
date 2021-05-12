// Implementation of the Crossplane API as defined in https://doc.crds.dev/github.com/crossplane/provider-aws@v0.16.0

{
  s3:: {
    v1beta1:: {
      local apiVersion = { apiVersion: 's3.aws.crossplane.io/v1beta1' },
      bucket:: {
        local kind = { kind: 'Bucket' },
        new(name):: apiVersion + kind + self.mixin.metadata.withName(name) + self.mixin.spec.withDeletionPolicy('Orphan'),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            mixinInstance(spec):: __specMixin(spec),
            withDeletionPolicy(deletionPolicy):: self + __specMixin({ deletionPolicy: deletionPolicy }),
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              mixinInstance(forProvider):: __forProviderMixin(forProvider),
              new(region, acl):: self + self.withLocationConstraint(region) + self.withAcl(acl),
              withLocationConstraint(region):: self + __forProviderMixin({ locationConstraint: region }),
              withAcl(acl):: self + __forProviderMixin({ acl: acl }),
              withAccelerateConfiguration(accelerateConfiguration):: self + __forProviderMixin({ accelerateConfiguration: accelerateConfiguration }),
              withObjectLockEnabledForBucket(objectLockEnabledForBucket):: self + __forProviderMixin({ objectLockEnabledForBucket: objectLockEnabledForBucket }),
              withServerSideEncryptionConfiguration(serverSideEncryptionConfiguration):: self + __forProviderMixin({ serverSideEncryptionConfiguration: serverSideEncryptionConfiguration }),
              withLifecycleConfiguration(lifecycleConfiguration):: self + __forProviderMixin({ lifecycleConfiguration: lifecycleConfiguration }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              mixinInstance(providerConfigRef):: __providerConfigRefMixin(providerConfigRef),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
    v1alpha2:: {
      local apiVersion = { apiVersion: 's3.aws.crossplane.io/v1alpha2' },
      bucketPolicy:: {
        local kind = { kind: 'BucketPolicy' },
        new(name, bucketName, region, statements, deletionPolicy='Delete')::
          apiVersion + kind
          + self.mixin.metadata.withName(name)
          + self.mixin.spec.deletionPolicy(deletionPolicy)
          + self.mixin.spec.forProvider.new(bucketName, region, statements),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            deletionPolicy(deletionPolicy):: __specMixin({ deletionPolicy+: deletionPolicy }),
            mixinInstance(spec):: __specMixin(spec),
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              new(bucketName, region, statements, version='2012-10-17')::
                self + self.withRegion(region) + self.withBucketName(bucketName) + self.withVersion(version) + self.withStatements(statements),
              withBucketName(name):: self + __forProviderMixin({ bucketName: name }),
              withRegion(region):: self + __forProviderMixin({ region: region }),
              withStatements(statements):: self + __forProviderMixin({ statements: statements }),
              withVersion(version):: self + __forProviderMixin({ version: version }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              mixinInstance(providerConfigRef):: __providerConfigRefMixin(providerConfigRef),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
    v1alpha3:: {
      local apiVersion = { apiVersion: 's3.aws.crossplane.io/v1alpha3' },
      bucketPolicy:: {
        local kind = { kind: 'BucketPolicy' },
        new(name, bucketName, region, policy, deletionPolicy='Delete')::
          apiVersion + kind
          + self.mixin.metadata.withName(name)
          + self.mixin.spec.deletionPolicy(deletionPolicy)
          + self.mixin.spec.forProvider.new(bucketName, region, policy),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            deletionPolicy(deletionPolicy):: __specMixin({ deletionPolicy+: deletionPolicy }),
            mixinInstance(spec):: __specMixin(spec),
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              new(bucketName, region, policy)::
                self + self.withRegion(region) + self.withBucketName(bucketName) + self.withPolicy(policy),
              withBucketName(name):: self + __forProviderMixin({ bucketName: name }),
              withRegion(region):: self + __forProviderMixin({ region: region }),
              withPolicy(policy):: self + __forProviderMixin({ policy: policy }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              mixinInstance(providerConfigRef):: __providerConfigRefMixin(providerConfigRef),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
  },
  identity:: {
    v1alpha1:: {
      local apiVersion = { apiVersion: 'identity.aws.crossplane.io/v1alpha1' },
      policy:: {
        local kind = { kind: 'IAMPolicy' },
        new(name, document)::
          apiVersion + kind + self.mixin.metadata.withName(name)
          + self.mixin.spec.forProvider.new(name, document),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              new(name, document):: self + __forProviderMixin({
                name: name,
                document: std.manifestJsonEx(document, '  '),
              }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
    v1beta1:: {
      local apiVersion = { apiVersion: 'identity.aws.crossplane.io/v1beta1' },
      role:: {
        local kind = { kind: 'IAMRole' },
        new(name):: apiVersion + kind + self.mixin.metadata.withName(name),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            mixinInstance(spec):: __specMixin(spec),
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              new(assumeRolePolicyDocument):: self + __forProviderMixin({ assumeRolePolicyDocument: std.manifestJsonEx(assumeRolePolicyDocument, '  ') }),
              withDescription(description):: self + __forProviderMixin({ description: description }),
              withPath(path):: self + __forProviderMixin({ path: path }),
              withMaxSessionDuration(maxSessionDuration):: self + __forProviderMixin({ maxSessionDuration: maxSessionDuration }),
              withPermissionsBoundary(permissionsBoundary):: self + __forProviderMixin({ permissionsBoundary: permissionsBoundary }),
              withTags(tags):: self + __forProviderMixin({ tags: tags }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
            writeConnectionSecretToRef:: {
              local __writeConnectionSecretToRefMixin(writeConnectionSecretToRef) = __specMixin({ writeConnectionSecretToRef+: writeConnectionSecretToRef }),
              new(name, namespace):: self + __writeConnectionSecretToRefMixin({ name: name, namespace: namespace }),
            },
          },
        },
      },

      rolePolicyAttachment:: {
        local kind = { kind: 'IAMRolePolicyAttachment' },
        new(name, policyArnRef, roleNameRef)::
          apiVersion + kind
          + self.mixin.metadata.withName(name)
          + self.mixin.spec.forProvider.withPolicyArnRef(policyArnRef)
          + self.mixin.spec.forProvider.withRoleNameRef(roleNameRef),
        mixin:: {
          // Standard object metadata.
          metadata:: {
            local __metadataMixin(metadata) = { metadata+: metadata },
            withName(name):: self + __metadataMixin({ name: name }),
          },
          spec:: {
            local __specMixin(spec) = { spec+: spec },
            forProvider:: {
              local __forProviderMixin(forProvider) = __specMixin({ forProvider+: forProvider }),
              withPolicyArnRef(name):: self + __forProviderMixin({ policyArnRef: { name: name } }),
              withRoleNameRef(name):: self + __forProviderMixin({ roleNameRef: { name: name } }),
            },
            providerConfigRef:: {
              local __providerConfigRefMixin(providerConfigRef) = __specMixin({ providerConfigRef+: providerConfigRef }),
              new(name):: self + __providerConfigRefMixin({ name: name }),
            },
          },
        },
      },
    },
  },
}
