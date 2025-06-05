local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local hpa = k.autoscaling.v2.horizontalPodAutoscaler;

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

local keda(config) = {
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
    pollingInterval: config.keda.pollingInterval,
    cooldownPeriod: config.keda.cooldownPeriod,
    minReplicaCount: config.minReplicas,
    maxReplicaCount: config.maxReplicas,
    [if config.keda.idleReplicaCount != null then 'idleReplicaCount']:config.keda.idleReplicaCount,
    [if config.keda.fallback != null then 'fallback']:config.keda.fallback,
    advanced: {
      restoreToOriginalReplicaCount: config.keda.restoreToOriginalReplicaCount,
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
      for trigerConfig in config.keda.trigerConfigs
    ] + (if std.objectHas(config.keda, 'customTriger') then config.keda.customTriger else []),
  },
};
local horizontalPodAutoscaler(config) = (
  hpa.new(config.name)
  + hpa.metadata.withAnnotations(config.annotations)
  + hpa.spec.scaleTargetRef.withKind(config.scaleTarget.kind)
  + hpa.spec.scaleTargetRef.withName(config.scaleTarget.name)
  + hpa.spec.scaleTargetRef.withApiVersion(config.scaleTarget.apiVersion)
  + hpa.spec.withMaxReplicas(config.maxReplicas)
  + hpa.spec.withMinReplicas(config.minReplicas)
  + hpa.spec.withMetrics(config.metrics)
  + hpa.spec.behavior.scaleDown.withPolicies(config.behavior.scaleDown.policies)
  + hpa.spec.behavior.scaleDown.withSelectPolicy(config.behavior.scaleDown.selectPolicy)
  + hpa.spec.behavior.scaleDown.withStabilizationWindowSeconds(config.behavior.scaleDown.stabilizationWindowSeconds)
  + hpa.spec.behavior.scaleUp.withPolicies(config.behavior.scaleUp.policies)
  + hpa.spec.behavior.scaleUp.withSelectPolicy(config.behavior.scaleUp.selectPolicy)
  + hpa.spec.behavior.scaleUp.withStabilizationWindowSeconds(config.behavior.scaleUp.stabilizationWindowSeconds)
);

{
  keda:: keda,
  horizontalPodAutoscaler:: horizontalPodAutoscaler,
}
