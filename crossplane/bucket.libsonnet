    local bucket(bucketName, region, serviceNamespace, tagSets) = {
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
    };
    local bucketAcl(bucketName, region, acl) = {
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
    };
    local bucketOwner(bucketName, region) = {
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
    };
    local bucketPolicy(bucketName, region, policy) = {
      apiVersion: 's3.aws.upbound.io/v1beta1',
      kind: 'BucketPolicy',
      metadata: {
        labels: {
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
    };
{
    bucket:: bucket,
    bucketAcl:: bucketAcl,
    bucketOwner:: bucketOwner,
    bucketPolicy:: bucketPolicy,
}