local k6(name) = {
    apiVersion: 'k6.io/v1alpha1',
    kind: 'K6',
    metadata: {
      name: 'k6-sample',
    },
    spec: {
      parallelism: 2,
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
        ],
      },
    },
};

local config(script) = {
  local scriptData = importstr script,
  apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name: 'k6-test',
    },
    data: scriptData,
};

{
  k6:: k6,
  config:: config,
}
