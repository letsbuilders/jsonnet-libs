local k6(name, parallelism, extraEnv=[], cleanup=true, separate=false) = {
    apiVersion: 'k6.io/v1alpha1',
    kind: 'TestRun',
    metadata: {
      name: 'k6-%s' % name,
    },
    spec: {
      parallelism: parallelism,
      separate: separate,
      script: {
        configMap: {
          name: 'k6-%s' % name,
          file: 'test.js',
        },
      },
      arguments: '--out statsd',
      runner: {
        metadata: {
          annotations: {
            'sidecar.istio.io/inject': 'false',
          },
        },
        env: [
          {
            name: 'K6_STATSD_ADDR',
            value: 'k6-statsd.k6-operator-system.svc.cluster.local:8125',
          },
        ] + extraEnv,
      },
      starter: {
        metadata: {
          annotations: {
            'sidecar.istio.io/inject': 'false',
          },
        },
      },
      [if cleanup then 'cleanup' else null]: 'post'
    }
};

local config(script, name) = {
  apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'k6-%s' % name,
    },
    data: {
      'test.js': script,
    },
};

{
  k6:: k6,
  config:: config,
}