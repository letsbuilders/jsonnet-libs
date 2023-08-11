// Helper utilities for AWS resources
local aws = import 'provider-aws.libsonnet';

local role = aws.iam.v1beta1.role;
local bucket = aws.s3.v1beta1.bucket;
local bucketPolicy = aws.s3.v1alpha3.bucketPolicy;


{
  _config:: {
    local s = self,

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
        scan: false,
        lifecycleRules: [],
        notifications: {
          queueArn: 'queueArn',
          events: 'events',
        },
      },
      tagging: {
        kubernetes_cluster: s.aws.clusterName,
        kubernetes_namespace: s.serviceNamespace,
        kubernetes_deployment: s.serviceName,
        kubernetes_container: s.serviceName,
      },
    },
  },

  local s = self,
  local c = $._config,

  // Resource tags
  // convert a map of tags defined in c.aws.tagging to a list of key,value pairs
  // This allows easy overriding of tags in c.aws.tagging and generates a format required by crossplane API

  local tagSets = [
    { key: key, value: c.aws.tagging[key] }
    for key in std.objectFields(c.aws.tagging)
  ],

  // Resource names

  bucketName:: '%(serviceName)s-%(namespace)s-%(clusterName)s-%(accountName)s-%(region)s' % {
    serviceName: c.serviceName,
    namespace: c.serviceNamespace,
    clusterName: c.aws.clusterName,
    accountName: c.aws.accountName,
    region: c.aws.region,
  },
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


  allowRoleToBucketPolicy:: [
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
  ],

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

  // notificationConfiguration  for S3 virus scan
  // https://github.com/letsbuilders/DevOps/issues/59
  notificationConfiguration:: {
    queueConfigurations: [
      {
        queueArn: c.aws.bucket.notifications.queueArn,
        events: [
          c.aws.bucket.notifications.events,
        ],
      },
    ],
  },

  // Resources
  bucket:: {
    bucket:
      bucket.new(name=s.bucketName)
      + bucket.mixin.spec.withDeletionPolicy('Orphan')
      + bucket.mixin.spec.providerConfigRef.withName(c.crossplaneProvider)
      + bucket.mixin.spec.forProvider.withLocationConstraint(c.aws.region)
      + bucket.mixin.spec.forProvider.tagging.withTagSet(tagSets)
      + bucket.mixin.spec.forProvider.withAcl(c.aws.bucket.acl)
      + (if c.aws.bucket.scan == true then bucket.mixin.spec.forProvider.notificationConfiguration.withQueueConfigurations(s.notificationConfiguration.queueConfigurations)
         else {})
      + (if std.length(c.aws.bucket.lifecycleRules) > 0 then bucket.mixin.spec.forProvider.lifecycleConfiguration.withRules(c.aws.bucket.lifecycleRules) else {}),
    bucketPolicy:
      bucketPolicy.new(name=s.bucketName)
      + bucketPolicy.mixin.spec.forProvider.withBucketName(s.bucketName)
      + bucketPolicy.mixin.spec.forProvider.withRegion(c.aws.region)
      + bucketPolicy.mixin.spec.forProvider.policy.withVersion('2012-10-17')
      + bucketPolicy.mixin.spec.forProvider.policy.withStatements(s.allowRoleToBucketPolicy)
      + bucketPolicy.mixin.spec.providerConfigRef.withName(c.crossplaneProvider),
  },

  iamRole:: {
    role:
      role.new(s.roleName)
      + role.mixin.spec.forProvider.withAssumeRolePolicyDocument(std.manifestJsonEx(s.serviceAccountTrustRelationship, '  '))
      + role.mixin.spec.providerConfigRef.withName(c.crossplaneProvider),
  },

}
