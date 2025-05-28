// Helper utilities for AWS resources
local aws = import 'provider-aws.libsonnet';

local role = aws.iam.v1beta1.role;
local bucket = aws.s3.v1beta1.bucket;
local bucketPolicy = aws.s3.v1alpha3.bucketPolicy;


(import 'bucket.libsonnet') + {
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
      bucketReplication: {
        enabled: false,
        roleName: '',
        accountId: '',
      },
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

  local tagSets = {
    [key]: c.aws.tagging[key]
    for key in std.objectFields(c.aws.tagging)
  },

  // Resource names
  upboundBucket:: import 'bucket.libsonnet',
  upboundIAM:: import 'iam.libsonnet',
  upboundKms:: import 'kms.libsonnet',
  upboundRds:: import 'rds.libsonnet',

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
  keyName:: '%(clusterName)s-%(namespace)s-%(serviceName)s' % {
    serviceName: c.serviceName,
    namespace: c.serviceNamespace,
    clusterName: c.aws.clusterName,
  },
  rdsName:: '%(clusterName)s-%(namespace)s-%(serviceName)s' % {
    serviceName: c.serviceName,
    namespace: c.serviceNamespace,
    clusterName: c.aws.clusterName,
  },
  rdsSecretName:: 'rds-%s-creds' % c.serviceName,

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
    Version: '2012-10-17',
    Statement: [
      {
        Sid: 'DownloadandUpload',
        Action: ['s3:GetObject', 's3:GetObjectAcl', 's3:GetObjectVersion', 's3:PutObject', 's3:PutObjectAcl', 's3:DeleteObject', 's3:DeleteObjectVersion'],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s/*' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
        },
      },
      {
        Sid: 'List',
        Action: ['s3:ListBucket'],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
        },
      },
    ],
  },

  allowBucketWithReplication:: {
    Version: '2012-10-17',
    Statement: [
      {
        Sid: 'AllowBucketReplication',
        Action: [
          's3:List*',
          's3:GetBucketVersioning',
          's3:PutBucketVersioning',
        ],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.bucketReplication.accountId, roleName: s.aws.bucketReplication.roleName },
        },
      },
      {
        Sid: 'AllowBatchJobPrivate',
        Action: [
          's3:ReplicateDelete',
          's3:ReplicateObject',
        ],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s/*' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.bucketReplication.accountId, roleName: s.aws.bucketReplication.roleName },
        },
      },
      {
        Sid: 'DownloadandUpload',
        Action: ['s3:GetObject', 's3:GetObjectAcl', 's3:GetObjectVersion', 's3:PutObject', 's3:PutObjectAcl', 's3:DeleteObject', 's3:DeleteObjectVersion'],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s/*' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
        },
      },
      {
        Sid: 'List',
        Action: ['s3:ListBucket'],
        Effect: 'Allow',
        Resource: ['arn:aws:s3:::%s' % s.bucketName],
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.aws.accountId, roleName: s.roleName },
        },
      },
    ],
  },

  keyPolicy:: {
    Version: '2012-10-17',
    Statement: [
      {
        Sid: 'Allow direct access to key metadata to the account',
        Effect: 'Allow',
        Principal: {
          AWS: 'arn:aws:iam::%(accountId)s:root' % { accountId: c.aws.accountId },
        },
        Action: ['kms:*'],
        Resource: ['*'],
      },
    ],
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
    bucket: s.upboundBucket.bucket(
      bucketName=s.bucketName,
      region=c.aws.region,
      serviceNamespace=c.serviceNamespace,
      tagSets=tagSets,
    ),
    bucketAcl: s.upboundBucket.bucketAcl(
      bucketName=s.bucketName,
      region=c.aws.region,
      acl=c.aws.bucket.acl,
    ),
    bucketOwner: s.upboundBucket.bucketOwner(
      bucketName=s.bucketName,
      region=c.aws.region,
    ),
    bucketPolicy: if c.aws.bucketReplication.enabled == true then s.upboundBucket.bucketPolicy(
      bucketName=s.bucketName,
      region=c.aws.region,
      policy=s.allowBucketWithReplication,
    ) else s.upboundBucket.bucketPolicy(
      bucketName=s.bucketName,
      region=c.aws.region,
      policy=s.allowRoleToBucketPolicy,
    ),
    [if c.aws.bucket.scan == true then 'bucketNotifications']: s.upboundBucket.bucketNotifications(
      bucketName=s.bucketName,
      region=c.aws.region,
      queues=s.notificationConfiguration.queueConfigurations,
    ),
    [if std.objectHasAll(s, 'versioning') then 'bucketVersioning']: s.upboundBucket.bucketVersioning(
      bucketName=s.bucketName,
      region=c.aws.region,
    ),
    [if std.objectHasAll(s, 'publicAccessBlocks') then 'bucketAccess']: s.upboundBucket.bucketAccess(
      bucketName=s.bucketName,
      region=c.aws.region,
      publicAccessBlocks=s.publicAccessBlocks,
    ),
    [if std.objectHasAll(s, 'lifeCycleRules') then 'bucketLifeCycle']: s.upboundBucket.bucketLifeCycle(
      bucketName=s.bucketName,
      region=c.aws.region,
      rules=s.lifeCycleRules,
    ),
    [if std.objectHasAll(s, 'corsRules') then 'corsRules']: s.upboundBucket.bucketCors(
      bucketName=s.bucketName,
      region=c.aws.region,
      corsRules=s.corsRules
    ),
    [if std.objectHasAll(s, 'encryptionRules') then 'encryptionRules']: s.upboundBucket.bucketEncryption(
      bucketName=s.bucketName,
      region=c.aws.region,
      encryptionRules=s.encryptionRules
    ),
  },

  iamRole:: {
    role: s.upboundIAM.role(
      name=s.roleName,
      trustPolicy=s.serviceAccountTrustRelationship,
    ),
  },
  iamRoleConfig:: {
    rolePolicy: s.upboundIAM.rolePolicy(
      name=s.roleName,
      roleName=s.roleName,
      resourcePolicy=s.resourcePolicy,
    ),
  },

  key:: {
    key: s.upboundKms.key(
      name=s.keyName,
      region=c.aws.region,
      policy=s.keyPolicy,
    ),
    alias: s.upboundKms.keyAlias(
      name=s.keyName,
      region=c.aws.region,
    ),
  },

  rds:: {
    instance: s.upboundRds.rdsInstance(
      name=s.rdsName,
      region=c.aws.region,
      parameters=s.rdsParameters,
      serviceNamespace=c.serviceNamespace,
      secretName=s.rdsSecretName,
      tagSets=tagSets,
    ),
  },
  rdsReadOnly:: {
    instanceReadOnly: s.upboundRds.rdsInstanceReadOnly(
      name='%s-ro' % s.rdsName,
      region=c.aws.region,
      parameters=s.rdsParametersReadOnly,
      serviceNamespace=c.serviceNamespace,
      secretName='%s-ro' % s.rdsSecretName,
      tagSets=tagSets,
    ),
  },
  rdsParameterGroup:: {
    parametersRds: s.upboundRds.parameterGroup(
      name=s.rdsName,
      region=c.aws.region,
      parameters=s.parameterGroupParams,
      family=c.aws.rdsFamily,
    ),
  },
}
