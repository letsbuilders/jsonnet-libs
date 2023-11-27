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

local rules(name, rules, labels={ prometheus: 'operations' }) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    labels: labels,
    name: name,
  },
  spec: {
    groups: rules,
  },
};

{
  serviceMonitor:: serviceMonitor,
  podMonitor:: podMonitor,
  rules:: rules,
}
