local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local service = k.core.v1.service;
local servicePort = k.core.v1.servicePort;


{
  local c = $._config,
  service: {
    master:
      service.new(
        name=c._name + '-master',
        selector={ 'app.kubernetes.io/component': 'master' } + c.commonLabels,
        ports=servicePort.newNamed('tcp-redis', 6379, 'redis')
      ) +
      service.metadata.withLabels(c.commonLabels { 'app.kubernetes.io/component': 'master' }),


    headless:
      service.new(
        name=c._name + '-headless',
        selector=c.commonLabels,
        ports=servicePort.newNamed('tcp-redis', 6379, 'redis')
      ) +
      service.spec.withClusterIP('None') +
      service.metadata.withLabels(c.commonLabels),

    metrics:
      service.new(
        name=c._name + '-metrics',
        selector=c.commonLabels,
        ports=servicePort.newNamed('http-metrics', 9121, 'metrics')
      ) +
      service.metadata.withLabels(c.commonLabels { 'app.kubernetes.io/component': 'metrics' }),
  },
}
