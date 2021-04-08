// Helper utilities for AWS resources

function(config) {
  local aws = import 'aws.libsonnet',

  local s = self,
  _config:: {
    oidcUrl: error 'oidcUrl must be provided',
    accountId: error 'accountId must be provided',
    clusterName: error 'clusterName must be provided',
    accountName: error 'accountName must be provided',
    region: error 'region must be provided',
  } + config,

  local c = s._config,

  serviceAccountTrustRelationship(accountId, oidcUrl, namespace, serviceAccountName):: {
    Version: '2012-10-17',
    Statement: [
      {
        Sid: '',
        Effect: 'Allow',
        Principal: {
          Federated: 'arn:aws:iam::%s:oidc-provider/%s' % [accountId, oidcUrl],
        },
        Action: 'sts:AssumeRoleWithWebIdentity',
        Condition: {
          StringEquals: {
            // This works because magic. Deal with it.
            [std.format('%s:sub', oidcUrl)]: 'system:serviceaccount:%s:%s' % [namespace, serviceAccountName],
          },
        },
      },
    ],
  },

  s3BucketName(serviceName, namespace):: '%(serviceName)s-%(namespace)s-%(clusterName)s-%(accountName)s-%(region)s' % {
    serviceName: serviceName,
    namespace: namespace,
    clusterName: c.clusterName,
    accountName: c.accountName,
    region: c.region,
  },

  iamRoleForService(serviceName, namespace):: '%(clusterName)s-%(namespace)s-%(serviceName)s' % {
    serviceName: serviceName,
    namespace: namespace,
    clusterName: c.clusterName,
  },

  eksServiceAccountAnnotation(serviceName, namespace):: {
    metadata+: {
      annotations+: {
        'eks.amazonaws.com/role-arn': 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % {
          accountId: c.accountId,
          roleName: s.iamRoleForService(serviceName, namespace),
        }
      }
    }
  },

  roleForServiceAccount(name, serviceAccount)::
    local serviceAccountName = serviceAccount.metadata.name;
    local serviceAccountNamespace = serviceAccount.metadata.namespace;

    local assumeRolePolicyDocument = s.serviceAccountTrustRelationship(c.accountId, c.oidcUrl, serviceAccountNamespace, serviceAccountName);

    local role = aws.identity.v1beta1.role;

    role.new(name)
    + role.mixin.spec.forProvider.new(assumeRolePolicyDocument)
    + role.mixin.spec.providerConfigRef.new(c.crossplaneProvider),

  allowRoleToBucketPolicy(role, bucket)::
    local bucketPolicy = aws.s3.v1alpha2.bucketPolicy;
    local bucketName = bucket.metadata.name;
    local bucketRegion = bucket.spec.forProvider.locationConstraint;
    local roleName = role.metadata.name;

    local statements = [
      {
        sid: 'DownloadandUpload',
        action: ['s3:GetObject', 's3:GetObjectAcl', 's3:GetObjectVersion', 's3:PutObject', 's3:PutObjectAcl', 's3:DeleteObject', 's3:DeleteObjectVersion'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s/*' % bucketName],
        principal: {
          awsPrincipals: [
            {
              // If I use iamRoleArnRef here tanka wants to remove iamRoleArn because it gets added by crossplane
              // https://github.com/crossplane/provider-aws/issues/555
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.accountId, roleName: roleName },
            },
          ],
        },
      },
      {
        sid: 'List',
        action: ['s3:ListBucket'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s' % bucketName],
        principal: {
          awsPrincipals: [
            {
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % { accountId: c.accountId, roleName: roleName },
            },
          ],
        },
      },
    ];

    bucketPolicy.new(name=bucketName, bucketName=bucketName, region=bucketRegion, statements=statements)
    + bucketPolicy.mixin.spec.providerConfigRef.new(c.crossplaneProvider),

}
