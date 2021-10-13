// Helper utilities for AWS resources
local aws = import 'aws.libsonnet';
local role = aws.identity.v1beta1.role;
local bucket = aws.s3.v1beta1.bucket;
local bucketPolicy = aws.s3.v1alpha3.bucketPolicy;


{
  _config:: {
    serviceName: error 'serviceName must be provided',
    serviceNamespace: error 'serviceNamespace must be provided',
    crossplaneProvider: 'aws-provider',

    aws: {
      oidcUrl: error 'oidcUrl must be provided',
      accountId: error 'accountId must be provided',
      clusterName: error 'clusterName must be provided',
      accountName: error 'accountName must be provided',
      region: error 'region must be provided',
      bucket: {
        acl: 'private',
      },
    },
  },

  local s = self,
  local c = $._config,
  local aws = c.aws,

  // Resource names

  bucketName:: '%(serviceName)s-%(namespace)s-%(clusterName)s-%(accountName)s-%(region)s' % {
    serviceName: c.serviceName,
    namespace: c.serviceNamespace,
    clusterName: c.aws.clusterName,
    accountName: c.aws.accountName,
    region: c.aws.region,
  },
  
  readOnlyBucketPolicyName:: '%(serviceName)-readonly-%s' % s.bucketName,

  roleName:: '%(clusterName)s-%(namespace)s-%(serviceName)s' % {
    serviceName: c.serviceName,
    namespace: c.serviceNamespace,
    clusterName: c.aws.clusterName,
  },

  // Resource policy documents

  // Trust policy for a role so a ServiceAccount can assume it
  serviceAccountTrustRelationship:: {
    Version: '2012-10-17',
    Statement: [
      {
        Sid: '',
        Effect: 'Allow',
        Principal: {
          Federated: 'arn:aws:iam::%s:oidc-provider/%s' % [c.aws.accountId, c.aws.oidcUrl],
        },
        Action: 'sts:AssumeRoleWithWebIdentity',
        Condition: {
          StringEquals: {
            // This works because magic. Deal with it.
            [std.format('%s:sub', c.aws.oidcUrl)]: 'system:serviceaccount:%s:%s' % [c.serviceNamespace, c.serviceName],
          },
        },
      },
    ],
  },


  allowRoleToBucketPolicy:: {
    version: '2012-10-17',
    statements: [
      {
        sid: 'DownloadandUpload',
        action: ['s3:GetObject', 's3:GetObjectAcl', 's3:GetObjectVersion', 's3:PutObject', 's3:PutObjectAcl', 's3:DeleteObject', 's3:DeleteObjectVersion'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s/*' % s.bucketName],
        principal: {
          awsPrincipals: [
            {
              // If I use iamRoleArnRef here tanka wants to remove iamRoleArn because it gets added by crossplane
              // https://github.com/crossplane/provider-aws/issues/555
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
            },
          ],
        },
      },
      {
        sid: 'List',
        action: ['s3:ListBucket'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s' % s.bucketName],
        principal: {
          awsPrincipals: [
            {
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
            },
          ],
        },
      },
    ]
  },

  readOnlyBucketPolicyDocument:: {
    version: '2012-10-17',
    statements: [
      {
        sid: 'DownloadOnly',
        action: ['s3:GetObject', 's3:GetObjectVersion'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s/*' % s.bucketName],
        principal: {
          awsPrincipals: [
            {
              // If I use iamRoleArnRef here tanka wants to remove iamRoleArn because it gets added by crossplane
              // https://github.com/crossplane/provider-aws/issues/555
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
            },
          ],
        },
      },
    ]
  },


  overrides:: {
    // service_account field overrides
    // service_account will be defined by https://github.com/grafana/jsonnet-libs/blob/master/ksonnet-util/util.libsonnet#L49
    service_account+: {
      metadata+: {
        annotations+: {
          'eks.amazonaws.com/role-arn': 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % {
            accountId: c.aws.accountId,
            roleName: s.roleName,
          },
        },
      },
    },
  },

  // Resources

  readOnlyBucketPolicyResource::
    bucketPolicy.new(name=s.readOnlyBucketPolicyName, bucketName=s.bucketName, region=c.aws.region, policy=s.readOnlyBucketPolicyDocument)
    + bucketPolicy.mixin.spec.providerConfigRef.new(c.crossplaneProvider),
    
  bucket:: {
    bucket:
      bucket.new(name=s.bucketName)
      + bucket.mixin.spec.providerConfigRef.new(c.crossplaneProvider)
      + bucket.mixin.spec.forProvider.new(region=c.aws.region, acl=c.aws.bucket.acl),
    bucketPolicy:
      bucketPolicy.new(name=s.bucketName, bucketName=s.bucketName, region=c.aws.region, policy=s.allowRoleToBucketPolicy)
      + bucketPolicy.mixin.spec.providerConfigRef.new(c.crossplaneProvider),
  },

  iamRole:: {
    role:
      role.new(s.roleName)
      + role.mixin.spec.forProvider.new(s.serviceAccountTrustRelationship)
      + role.mixin.spec.providerConfigRef.new(c.crossplaneProvider),
  },

}
