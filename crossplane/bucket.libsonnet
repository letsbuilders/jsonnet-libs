{
  bucket(bucketName, region, serviceNamespace, tagSets):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'Bucket',
    metadata: {
      name: bucketName,

      labels: {
        bucket: bucketName,
      },
    },
    spec: {
      forProvider: {
        region: region,
        tags: {
          namespace: serviceNamespace,
        } + tagSets,
      },
    },
  },
  bucketAcl(bucketName, region, acl):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketACL',
    metadata: {

      name: bucketName,
    },
    spec: {
      forProvider: {
        region: region,
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        acl: acl,
      },
    },
  },
  bucketOwner(bucketName, region):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketOwnershipControls',
    metadata: {

      name: bucketName,
    },
    spec: {
      forProvider: {
        region: region,
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        rule: [
          {
            objectOwnership: 'BucketOwnerPreferred',
          },
        ],
      },
    },
  },
  bucketPolicy(bucketName, region, policy):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketPolicy',
    metadata: {

      name: bucketName,
    },
    spec: {
      forProvider: {
        region: region,
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        policy: std.manifestJsonEx(policy, '  '),
      },
    },
  },
  bucketCors(bucketName, region, corsRules):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketCorsConfiguration',
    metadata: {
      name: bucketName,
    },
    spec: {
      forProvider: {
        region: region,
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        corsRule: corsRules,
      },
    },
  },
  bucketLifeCycle(bucketName, region, rules):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketLifecycleConfiguration',
    metadata: {
      name: bucketName,
    },
    spec: {
      forProvider: {
        region: region,
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        rule: rules,
      },
    },
  },
  bucketAccess(bucketName, region, PublicAccessBlocks):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketPublicAccessBlock',
    metadata: {
      name: bucketName,
    },
    spec: {
      forProvider: {
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        region: region,
        PublicAccessBlock: PublicAccessBlocks,
      },
    },
  },
  bucketVersioning(bucketName, region, status='Enabled'):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketVersioning',
    metadata: {
      name: bucketName,
    },
    spec: {
      forProvider: {
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        region: region,
        versioningConfiguration: [
          {
            status: status,
          },
        ],
      },
    },
  },
}
