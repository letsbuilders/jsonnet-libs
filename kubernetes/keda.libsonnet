local metricDefinition(type, queue, value, activationThreshold, server, authentication, useCachedMetrics, metricType) =
  {
    type: type,
    useCachedMetrics: useCachedMetrics,
    metricType: metricType,
    [if authentication != '' then 'authenticationRef']: authentication,
    metadata: {
      serverAddress: server,
      query: queue,
      threshold: value,
      activationThreshold: activationThreshold,
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
    } + config.annotations,
  },
  spec: {
    scaleTargetRef: config.scaleTarget,
    pollingInterval: config.pollingInterval,
    cooldownPeriod: config.cooldownPeriod,
    minReplicaCount: config.minReplicas,
    maxReplicaCount: config.maxReplicas,
    fallback: config.fallback,
    advanced: {
      restoreToOriginalReplicaCount: config.restoreToOriginalReplicaCount,
      horizontalPodAutoscalerConfig: {
        behavior: config.behavior,
      },
    },
    triggers: [
      metricDefinition(
        type=(if std.objectHas(trigerConfig, 'type') then trigerConfig.type else 'prometheus'),
        queue=trigerConfig.queue,
        value=std.toString(trigerConfig.value),
        activationThreshold=(if std.objectHas(trigerConfig, 'activationThreshold') then std.toString(trigerConfig.activationThreshold) else '0'),
        server=(if std.objectHas(trigerConfig, 'server') then trigerConfig.server else 'http://thanos-query.monitoring.svc.cluster.local:9090'),
        authentication=(if std.objectHas(trigerConfig, 'authentication') then trigerConfig.authentication else ''),
        useCachedMetrics=(if std.objectHas(trigerConfig, 'useCachedMetrics') then trigerConfig.useCachedMetrics else false),
        metricType=(if std.objectHas(trigerConfig, 'metricType') then trigerConfig.metricType else 'AverageValue'),
      )
      for trigerConfig in config.trigerConfigs
    ],
  },
};

{
  scaledObject:: scaledObject,
}
