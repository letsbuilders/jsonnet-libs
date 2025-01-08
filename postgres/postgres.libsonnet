local host(name, username, address='', secretName, secretKey, endpointKey='') = {
  apiVersion: 'postgres.letsbuild.com/v1alpha1',
  kind: 'Host',
  metadata: {
    name: name,
    annotations: {
      'argocd.argoproj.io/sync-wave': '1',
    },
    finalizers: ['finalizer.postgres.letsbuild.com'],
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
    finalizers: ['finalizer.postgres.letsbuild.com'],
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
    finalizers: ['finalizer.postgres.letsbuild.com'],
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

local publication(name, databaseName, replicaUser,schemas=[], tables=[], columns={}, secretName='', publicationName='',replicaSecretRef='') = {

  local defaultName = '%(database)s-%(user)s' % {
    database: databaseName,
    user: name,
  },

  apiVersion: 'postgres.letsbuild.com/v1alpha1',
  kind: 'Publication',
  metadata: {
    name: if name == '' then defaultName else name,
    annotations: {
      'argocd.argoproj.io/sync-wave': '-1',
    },
    finalizers: ['finalizer.postgres.letsbuild.com'],
  },
  spec: {
    publicationName: if publicationName == '' then name else publicationName,
    writeConnectionSecretToRef: {
      name: if secretName == '' then defaultName else secretName,
    },
    databaseRef: {
      name: databaseName
    },
    replicaUser: replicaUser,
    [if schemas != [] then 'schemas']: schemas,
    [if tables != [] then 'tables']: tables,
    [if columns != {} then 'columns']: columns,
    [if replicaSecretRef != '' then 'readReplica']: {secretRef: replicaSecretRef},
  },
};

local subscription(name, slotName, databaseName, publication, subscriptionName='',) = {

  local defaultName = '%(database)s-%(user)s' % {
    database: databaseName,
    user: name,
  },

  apiVersion: 'postgres.letsbuild.com/v1alpha1',
  kind: 'Subscription',
  metadata: {
    name: if name == '' then defaultName else name,
    annotations: {
      'argocd.argoproj.io/sync-wave': '-1',
    },
    finalizers: ['finalizer.postgres.letsbuild.com'],
  },
  spec: {
    subscriptionName: if subscriptionName == '' then name else subscriptionName,
    slotName: slotName,
    databaseRef: {
      name: databaseName
    },
    publicationRef: {
      name: publication,
    },
  },
};

{
  host:: host,
  database:: database,
  user:: user,
  publication:: publication,
  subscription:: subscription,
}
