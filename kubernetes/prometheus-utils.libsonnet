local monitorForService(name, serviceLabels, namespace, metricsPortName, metricsPath='/metrics', prometheusInstance='k8s') = {
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
      matchLabels: service.metadata.labels,
    },
    namespaceSelector: {
      matchNames: [
        namespace,
      ],
    },
  },
};

{
  monitorForService:: monitorForService,
}
