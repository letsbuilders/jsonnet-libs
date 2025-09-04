local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local statefulSet = k.apps.v1.statefulSet;
local container = k.core.v1.container;

{
  local c = $._config,
  _redis_container::
    container.new('redis', '%(registry)s/%(repository)s:%(tag)s' % c.image) +
    container.withCommand(c.command) +
    container.resources.withLimits(c.resources.limits) +
    container.resources.withRequests(c.resources.requests) +

    container.livenessProbe.exec.withCommand(['/bin/sh', '-c', 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping']) +
    container.livenessProbe.withFailureThreshold(c.livenessProbe.failureThreshold) +
    container.livenessProbe.withInitialDelaySeconds(c.livenessProbe.initialDelaySeconds) +
    container.livenessProbe.withPeriodSeconds(c.livenessProbe.periodSeconds) +
    container.livenessProbe.withSuccessThreshold(c.livenessProbe.successThreshold) +
    container.livenessProbe.withTimeoutSeconds(c.livenessProbe.timeoutSeconds) +

    container.readinessProbe.exec.withCommand(['/bin/sh', '-c', 'REDISCLI_AUTH="$REDIS_PASSWORD" redis-cli ping']) +
    container.readinessProbe.withFailureThreshold(c.readinessProbe.failureThreshold) +
    container.readinessProbe.withInitialDelaySeconds(c.readinessProbe.initialDelaySeconds) +
    container.readinessProbe.withPeriodSeconds(c.readinessProbe.periodSeconds) +
    container.readinessProbe.withSuccessThreshold(c.readinessProbe.successThreshold) +
    container.readinessProbe.withTimeoutSeconds(c.readinessProbe.timeoutSeconds) +
    container.securityContext.withRunAsUser(1001) +

    container.withVolumeMounts([
      {
        name: 'redis-data',
        mountPath: '/data',
      },
      {
        name: 'config',
        mountPath: c.config.mountPath,
      },
    ]) +

    container.withPorts([
      {
        containerPort: 6379,
        name: 'redis',
        protocol: 'TCP',
      },
    ]) +

    container.withEnv([
      {
        name: 'REDIS_PASSWORD',
        valueFrom: {
          secretKeyRef: {
            name: $.secret.metadata.name,
            key: 'redis-password',
          },
        },
      },
      {
        name: 'REDIS_PORT',
        value: '6379',
      },
    ]),

  _exporter_container::
    container.new('metrics', '%(registry)s/%(repository)s:%(tag)s' % c.metrics.image) +
    container.withPorts([
      {
        containerPort: 9121,
        name: 'metrics',
        protocol: 'TCP',
      },
    ]) +

    container.securityContext.withRunAsUser(1001) +

    container.withEnv([
      {
        name: 'REDIS_PASSWORD',
        valueFrom: {
          secretKeyRef: {
            name: $.secret.metadata.name,
            key: 'redis-password',
          },
        },
      },
      {
        name: 'REDIS_ADDR',
        value: 'redis://localhost:6379',
      },
    ]),
  statefulSet:
    statefulSet.new(c._name + '-master', replicas=c.replicas, containers=[$._redis_container, $._exporter_container]) +
    statefulSet.metadata.withLabels({
      'app.kubernetes.io/component': 'master',
    } + c.commonLabels) +

    statefulSet.spec.withServiceName(c._name + '-headless') +
    statefulSet.spec.selector.withMatchLabels({
      'app.kubernetes.io/component': 'master',
    } + c.commonLabels) +
    statefulSet.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTerms(c.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTerms) +
    statefulSet.spec.template.spec.withTolerations(c.tolerations) +
    statefulSet.spec.template.metadata.withAnnotations(c.podAnnotations) +
    statefulSet.spec.template.metadata.withLabels({
      'app.kubernetes.io/component': 'master',
    } + c.commonLabels) +
    statefulSet.spec.template.spec.withServiceAccountName($.serviceAccount.metadata.name) +
    statefulSet.spec.template.spec.securityContext.withFsGroup(1001) +

    statefulSet.spec.template.spec.withVolumes([
      {
        name: 'config',
        configMap: {
          defaultMode: 420,
          name: $.configMap.metadata.name,
        },
      },
    ]) +

    statefulSet.spec.withVolumeClaimTemplates([
      {
        kind: 'PersistentVolumeClaim',
        apiVersion: 'v1',
        metadata: {
          name: 'redis-data',
          labels: {
            'app.kubernetes.io/component': 'master',
          } + c.commonLabels,

          annotations: c.persistence.annotations,
        },
        spec: {
          accessModes: [c.persistence.accessMode],
          resources: {
            requests: {
              storage: c.persistence.size,
            },
          },
          volumeMode: 'Filesystem',
        },
      },
    ]),
}
