local k6(name, parallelism, extraEnv=[], cleanup=true, separate=false) = {
    local cleanJobs = if cleanup then {cleanup: 'post'} else {},
    apiVersion: 'k6.io/v1alpha1',
    kind: 'K6',
    metadata: {
      name: 'k6-%s' % name,
    },
    spec: {
      parallelism: parallelism,
      separate: separate,
      script: {
        configMap: {
          name: 'k6-test',
          file: 'test.js',
        },
      },
      arguments: '--out statsd',
      runner: {
        env: [
          {
            name: 'K6_STATSD_ADDR',
            value: 'k6-statsd.k6-operator-system.svc.cluster.local:8125',
          },
        ] + extraEnv,
      },
    }
    + cleanJobs
};

local config(script) = {
  apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'k6-test',
    },
    data: {
      'test.js': script,
    },
};

{
  k6:: k6,
  config:: config,
}