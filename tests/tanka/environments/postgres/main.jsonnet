function(namespace='test') {
  apiVersion: 'tanka.dev/v1alpha1',
  kind: 'Environment',
  metadata: {
    name: 'environments/%s' % namespace,
    namespace: 'environments/%s' % namespace,
  },
  spec: {
    namespace: namespace,
    injectLabels: true,
    resourceDefaults: {
      labels: {
        'letsbuild.com/service': 'test',
      },
    },
  },

  // Configure test environment
  data:
    (import 'letsbuilders/postgres.libsonnet') +
    {
      _config+:: {
        clusterDomain: 'test.lb4.co',
        namespace: namespace,
      },
    },

  // Assertions
  assert std.objectHas(self.data, 'postgresDatabase'),
  assert std.objectHas(self.data, 'postgresUser'),
}
