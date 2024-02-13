local metric_definition(type, queue='', value='', activationThreshold='0', server) =
  {
    type: type,
    metadata: {
      serverAddress: server,
      query: queue,
      // 'sum(rabbitmq_queue_messages{namespace="%(namespace)s",queue="%(queue)s"}) by (queue)' % {namespace: namespace, queue: queue},
      threshold: value,
      activationThreshold: 'activationThreshold',
      unsafeSsl: 'true',
    },
  };

local scaledObject(config) = {
  apiVersion: 'keda.sh/v1alpha1',
  kind: 'ScaledObject',
  metadata: {
    name: config.name,
    annotations: {
      'scaledobject.keda.sh/transfer-hpa-ownership': 'true',
    },
  },
  spec: {
    scaleTargetRef: config.scaleTarget,
    pollingInterval: config.pollingInterval,
    cooldownPeriod: config.cooldownPeriod,
    minReplicaCount: config.minReplicaCount,
    maxReplicaCount: config.maxReplicaCount,
    fallback: config.fallback,
    advanced: {
      restoreToOriginalReplicaCount: config.restoreToOriginalReplicaCount,
      horizontalPodAutoscalerConfig: {
        behavior: config.behavior,
      },
    },
    triggers: [
      metric_definition(
        type=(if std.objectHas(trigerConfig, 'type') then trigerConfig.type else 'prometheus'),
        queue=trigerConfig.queue,
        value=std.toString(trigerConfig.value),
        activationThreshold=(if std.objectHas(trigerConfig, 'activationThreshold') then std.toString(trigerConfig.activationThreshold) else '0'),
        server=(if std.objectHas(trigerConfig, 'server') then trigerConfig.server else 'http://thanos-query.monitoring.svc.cluster.local:9090')
      )
      for trigerConfig in config.trigerConfigs
    ],
  },
};

{
  scaledObject:: scaledObject,
}
