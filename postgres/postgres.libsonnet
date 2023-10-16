local host(name, username, address='', secretName, secretKey, endpointKey='') = {
  apiVersion: 'postgres.letsbuild.com/v1alpha1',
  kind: 'Host',
  metadata: {
    name: name,
  },
  spec: {
    [if address != '' then 'address']: address,
    username: username,
    secretRef: {
      name: secretName,
      key: secretKey,
      [if endpointKey != '' then 'endpointKey']: endpointKey,
    },
  },
};

local database(databaseName, hostName, dropOnDeletion=true, name='', extensions=[]) = {
  local defaultName = '%(host)s-%(database)s' % {
    host: hostName,
    database: databaseName,
  },

  apiVersion: 'postgres.letsbuild.com/v1alpha1',
  kind: 'Database',
  metadata: {
    name: if name == '' then defaultName else name,
    annotations: {
      'argocd.argoproj.io/sync-wave': '-3',
    },
  },
  spec: {
    databaseName: databaseName,
    dropOnDeletion: dropOnDeletion,
    [if extensions != [] then 'extensions']: extensions,
    hostRef: {
      name: hostName,
    },
  },
};

local user(username, databaseName, priv, secretName='', name='', schemaCreation=false) = {

  local defaultName = '%(database)s-%(user)s' % {
    database: databaseName,
    user: username,
  },

  apiVersion: 'postgres.letsbuild.com/v1alpha2',
  kind: 'User',
  metadata: {
    name: if name == '' then defaultName else name,
    annotations: {
      'argocd.argoproj.io/sync-wave': '-2',
    },
  },
  spec: {
    username: username,
    writeConnectionSecretToRef: {
      name: if secretName == '' then defaultName else secretName,
    },
    grant: {
      databaseRef: {
        name: databaseName
      },
      schemaCreation: schemaCreation,
      priv: priv,
    },
  },
};

{
  host:: host,
  database:: database,
  user:: user,
}
