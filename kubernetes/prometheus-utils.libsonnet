local serviceMonitor(name, serviceLabels, namespace, metricsPortName, metricsPath='/metrics', prometheusInstance='application') = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'ServiceMonitor',
  metadata: {
    name: name,
    labels: {
      app: name,
      prometheus: prometheusInstance,
    },
  },
  spec: {
    endpoints: [
      {
        port: metricsPortName,
        path: metricsPath,
      },
    ],
    selector: {
      matchLabels: serviceLabels,
    },
    namespaceSelector: {
      matchNames: [
        namespace,
      ],
    },
  },
};


local podMonitor(name, podLabels, namespace, metricsPortName, metricsPath='/metrics', prometheusInstance='application') = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PodMonitor',
  metadata: {
    name: name,
    labels: {
      app: name,
      prometheus: prometheusInstance,
    },
  },

  spec: {
    namespaceSelector: {
      matchNames: [
        namespace,
      ],
    },
    selector: {
      matchLabels: podLabels,
    },
    podMetricsEndpoints: [
      {
        port: metricsPortName,
        path: metricsPath,
      },
    ],
  },
};

local rules(name, rules, cluster, labels={ prometheus: 'operations' }) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    labels: labels,
    name: name,
  },
  spec: {
    groups: [
      {
        name: rule.name,
        rules: [
          x {
            annotations+: {
              query: x.expr,
              link: 'https://grafana.monitoring.%(cluster)s1.eu-west-1.aws.%(cluster)s.lb4.co' % { cluster: cluster },
            },
          }
          for x in rule.rules
        ],
      }
      for rule in rules
    ],
  },
};

{
  serviceMonitor:: serviceMonitor,
  podMonitor:: podMonitor,
  rules:: rules,
}
