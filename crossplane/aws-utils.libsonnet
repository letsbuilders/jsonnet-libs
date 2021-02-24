// Helper utilities for AWS resources

local awsUtil(config) = {
  local aws = import 'aws.libsonnet',

  local s = self,

  serviceAccountTrustRelationship(accountId, oidcUrl, namespace, serviceAccountName)::
    {
      Version: '2012-10-17',
      Statement: [
        {
          Sid: '',
          Effect: 'Allow',
          Principal: {
            'Federated': 'arn:aws:iam::%s:oidc-provider/%s' % [accountId, oidcUrl]
          },
          Action: 'sts:AssumeRoleWithWebIdentity',
          Condition: {
            StringEquals: {
              // This works because magic. Deal with it.
              [std.format('%s:sub', oidcUrl)]: 'system:serviceaccount:%s:%s' % [namespace, serviceAccountName]
            }
          }
        }
      ],
    },

  roleForServiceAccount(name, serviceAccount)::
    local serviceAccountName = serviceAccount.metadata.name;
    local serviceAccountNamespace = serviceAccount.metadata.namespace;

    local assumeRolePolicyDocument = s.serviceAccountTrustRelationship(config.accountId, config.oidcUrl, serviceAccountNamespace, serviceAccountName);

    local role = aws.identity.v1beta1.role;

    role.new(name)
    + role.mixin.spec.forProvider.new(assumeRolePolicyDocument)
    + role.mixin.spec.providerConfigRef.new(config.crossplaneProvider),

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
              iamRoleArn: 'arn:aws:iam::%(accountId)s:role/%(roleName)s' % {accountId: config.accountId, roleName: roleName},
            }
          ]
        }
      },
      {
        sid: 'List',
        action: ['s3:ListBucket'],
        effect: 'Allow',
        resource: ['arn:aws:s3:::%s' % bucketName],
        principal: {
          awsPrincipals: [
            {
              iamRoleArnRef: {
                name:roleName
              }
            }
          ]
        }
      }
    ];

    bucketPolicy.new(name=bucketName, bucketName=bucketName, region=bucketRegion, statements=statements)
    + bucketPolicy.mixin.spec.providerConfigRef.new(config.crossplaneProvider),

};
{
  awsUtil:: awsUtil
}
