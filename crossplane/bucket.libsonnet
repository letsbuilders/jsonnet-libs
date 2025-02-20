{
  bucket(bucketName, region, serviceNamespace, tagSets, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'Bucket',
    metadata: {
      name: bucketName,
      annotations: annotations,
      labels: labels {
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
  bucketAcl(bucketName, region, acl, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'BucketACL',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
  bucketOwner(bucketName, region, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'BucketOwnershipControls',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
        rule: {
          objectOwnership: 'BucketOwnerPreferred',
        },
      },
    },
  },
  bucketPolicy(bucketName, region, policy, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketPolicy',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
  bucketCors(bucketName, region, corsRules, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketCorsConfiguration',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
  bucketLifeCycle(bucketName, region, rules, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'BucketLifecycleConfiguration',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
  bucketAccess(bucketName, region, publicAccessBlocks, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketPublicAccessBlock',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
      name: bucketName,
    },
    spec: {
      forProvider: publicAccessBlocks {
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        region: region,
      },
    },
  },
  bucketVersioning(bucketName, region, status='Enabled', annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'BucketVersioning',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
        versioningConfiguration: {
          status: status,
        },
      },
    },
  },
  bucketNotifications(bucketName, region, queues, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta1',
    kind: 'BucketNotification',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
      name: bucketName,
    },
    spec: {
      forProvider: {
        bucketSelector: {
          matchLabels: {
            bucket: bucketName,
          },
        },
        queue: queues,
        region: region,
      },
    },
  },
  bucketEncryption(bucketName, region, encryptionRules, annotations={}, labels={}):: {
    apiVersion: 's3.aws.upbound.io/v1beta2',
    kind: 'BucketServerSideEncryptionConfiguration',
    metadata: {
      annotations: annotations,
      labels: labels {
        bucket: bucketName,
      },
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
        rule: encryptionRules,
      },
    },
  },
}
