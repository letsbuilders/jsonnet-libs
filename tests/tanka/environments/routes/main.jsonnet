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
    (import 'letsbuilders/routes.libsonnet') +
    {
      _config+:: {
        clusterDomain: 'test.lb4.co',
        namespace: namespace,
      },
    },

  // Assertions
  assert std.isObject(self.data.serviceDeployment),
  assert std.isObject(self.data.serviceDeployment.routes),
  local routes = self.data.serviceDeployment.routes,
  assert routes.kind == 'HTTPRoute',
  assert routes.metadata.name == 'test-service',
  assert std.isArray(routes.spec.rules[0].backendRefs),
  assert routes.spec.rules[0].backendRefs[0].name == 'test-service',
  assert routes.spec.rules[0].backendRefs[0].port == 80,
  assert routes.spec.parentRefs[0].name == 'external',
}
