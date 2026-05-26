

local resourceLabels(name, labels={}) =
  labels {
    'app.kubernetes.io/name': name,
    'app.kubernetes.io/part-of': name,
  };

local database(name, secretRefName, databaseName='', labels={}) = {
  apiVersion: 'letsbuild.com/v1alpha1',
  kind: 'XMSSQLDatabase',
  metadata: {
    name: name,
    labels: resourceLabels(name, labels),
  },
  spec: {
    secretRefName: secretRefName,
    [if databaseName != '' then 'databaseName']: databaseName,
  },
};


local user(name, providerConfigName, permissions, databaseName='', connectionStringSecretName='', schema={}, labels={}) = {
  apiVersion: 'letsbuild.com/v1alpha1',
  kind: 'XMSSQLUser',
  metadata: {
    name: name,
    labels: resourceLabels(name, labels),
  },
  spec: {
    providerConfigName: providerConfigName,
    permissions: permissions,
    [if databaseName != '' then 'databaseName']: databaseName,
    [if connectionStringSecretName != '' then 'connectionStringSecretName']: connectionStringSecretName,
    [if schema != {} then 'schema']: schema,
  },
};

{
  database:: database,
  user:: user,
}
