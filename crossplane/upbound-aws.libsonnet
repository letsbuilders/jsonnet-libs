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


  allowRoleToBucketPolicy:: {
    Version: '2012-10-17',
    Statement: [
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
    bucketPolicy: s.upboundBucket.bucketPolicy(
      bucketName=s.bucketName,
      region=c.aws.region,
      policy=s.allowRoleToBucketPolicy,
    ),
  },
  bucketConfig:: {
    bucketVersioning: s.upboundBucket.bucketVersioning(
      bucketName=s.bucketName,
      region=c.aws.region,
    ),
    bucketAccess: s.upboundBucket.bucketAccess(
      bucketName=s.bucketName,
      region=c.aws.region,
      publicAccessBlocks=s.publicAccessBlocks,
    ),
    bucketLifeCycle: s.upboundBucket.bucketLifeCycle(
      bucketName=s.bucketName,
      region=c.aws.region,
      rules=s.lifeCycleRules,
    ),
    bucketCors: s.upboundBucket.bucketCors(
      bucketName=s.bucketName,
      region=c.aws.region,
      corsRules=s.corsRules
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
      resourcePolicy=s.serviceAccountTrustRelationship,
    ),
  },
}
