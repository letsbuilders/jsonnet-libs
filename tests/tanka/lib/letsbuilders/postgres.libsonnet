local lbPostgres = import 'postgres/postgres.libsonnet';

(import 'config.libsonnet') +
{
  local c = $._config,

  postgresDatabase: lbPostgres.database(
    databaseName='%(namespace)s-%(name)s' % {
      namespace: c.namespace,
      name: c.deployment.name,
    },
    hostName='postgres'
  ),

  postgresUser: lbPostgres.user(
    username=c.deployment.name,
    hostName=self.postgresDatabase.spec.hostRef.name,
    databaseName=self.postgresDatabase.spec.databaseName,
    secretName='%s-postgres' % c.deployment.name,
    priv='ALL',
  ),
}
