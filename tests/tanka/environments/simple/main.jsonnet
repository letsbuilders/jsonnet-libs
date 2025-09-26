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
    (import 'letsbuilders/simple.libsonnet') +
    {
      _config+:: {
        clusterDomain: 'test.lb4.co',
        namespace: namespace,
      },
    },

  // Assertions
  assert std.isObject(self.data.serviceDeployment),
  assert std.isObject(self.data.serviceDeployment.deployment),
  assert std.isObject(self.data.serviceDeployment.deployment.spec.template.spec),
  assert std.equals(self.data.serviceDeployment.deployment.spec.template.spec.containers[0].resources.limits.memory, '200Mi'),
  assert std.equals(self.data.serviceDeployment.deployment.spec.template.spec.containers[0].volumeMounts[0].name, 'tmp-dir'),
  assert std.equals(self.data.serviceDeployment.deployment.spec.template.spec.containers[0].volumeMounts[0].mountPath, '/tmp'),
  assert std.member(
    [m.name for m in self.data.serviceDeployment.deployment.spec.template.spec.volumes],
    'tmp-dir'
  ),
  assert std.equals(self.data.serviceDeployment.deployment.spec.template.spec.containers[0].resources.requests.memory, '100Mi'),


}
