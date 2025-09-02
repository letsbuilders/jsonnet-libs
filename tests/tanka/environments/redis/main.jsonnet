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
    (import 'letsbuilders/redis.libsonnet') +
    {
      _config+:: {

      },
    },

  // Assertions
  assert std.objectHas(self.data, 'redis'),
  assert std.objectHas(self.data.redis, 'statefulSet'),
  assert std.objectHas(self.data.redis, 'service'),
  assert std.objectHas(self.data.redis.service, 'master'),
  assert std.objectHas(self.data.redis.service, 'headless'),
  assert std.assertEqual(self.data.redis.service.headless.spec.clusterIP, 'None'),
  assert std.objectHas(self.data.redis.service, 'metrics'),
  assert std.objectHas(self.data.redis, 'secret'),
  assert std.objectHas(self.data.redis.secret.data, 'redis-password'),
  assert std.objectHas(self.data.redis, 'configMap'),
  assert std.objectHas(self.data.redis.configMap.data, 'master.conf'),
  assert std.objectHas(self.data.redis.configMap.data, 'redis.conf'),
}
