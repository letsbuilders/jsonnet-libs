// Helper utilities for AWS resources

local awsUtil(config) = {
  local aws = import 'aws.libsonnet',

  local s = self,

  serviceAccountTrustRelationship(accountId, oidcUrl, namespace, serviceAccountName)::
    {
      Version: "2012-10-17",
      Statement: [
        {
          Sid: "",
          Effect: "Allow",
          Principal: {
            "Federated": "arn:aws:iam::%s:oidc-provider/%s" % [accountId, oidcUrl]
          },
          Action: "sts:AssumeRoleWithWebIdentity",
          Condition: {
            StringEquals: {
              // This works because magic. Deal with it.
              [std.format("%s:sub", oidcUrl)]: "system:serviceaccount:%s:%s" % [namespace, serviceAccountName]
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

    role.new(name, serviceAccountNamespace)
    + role.mixin.spec.forProvider.new(assumeRolePolicyDocument)
    + role.mixin.spec.providerConfigRef.new(config.crossplaneProvider),

};
{
  awsUtil:: awsUtil
}
