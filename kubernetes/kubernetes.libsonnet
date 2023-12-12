local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local util = import 'github.com/grafana/jsonnet-libs/ksonnet-util/util.libsonnet';


local objectMetadata(object, config) =
  // object labels
  object.metadata.withLabels(
    {
      name: config.name,
      app: config.name,
      'letsbuild.com/service': config.name,
    } + config.labels
  )
  // object annotation
  + object.metadata.withAnnotations(
    {
      'argocd.argoproj.io/sync-wave': '1',
    } + config.annotations
  )
  // Pod labels
  + object.spec.template.metadata.withLabels(
    {
      name: config.name,
      app: config.name,
      version: config.container.tag,
      'letsbuild.com/service': config.name,
    } + config.podLabels
  )
  // Pod Annotation
  + object.spec.template.metadata.withAnnotations(
    {
      'sidecar.istio.io/proxyCPU': '10m',
      //      'sidecar.istio.io/proxyCPULimit': '',
      'sidecar.istio.io/proxyMemory': '80Mi',
      //      'sidecar.istio.io/proxyMemoryLimit': '',
    } + config.podAnnotations
  );

local serviceSpec(object, config) =
  local service = k.core.v1.service;

  util.serviceFor(object, nameFormat='%(port)s') +
  {
    spec+: {
      selector+: {
        // We don't want to use the version label in service selectors
        // Services should select all versions of an app
        // Otherwise rolling updates won't be possible
        version:: null,
      },
    },
  }
  + service.metadata.withLabels(
    { name: config.name, app: config.name, 'letsbuild.com/service': config.name }
    + config.labels
  )
  // object annotation
  + service.metadata.withAnnotations(
    {
      'argocd.argoproj.io/sync-wave': '1',
    } + config.annotations
  );

local containerSpecs(containersConfig) = [
  local container = k.core.v1.container;
  local port = k.core.v1.containerPort;

  // Convert key=value pairs to name,value objects
  // We use key=value pairs in `envVars` to be able to easily override them between environments
  local envVars =
    if std.objectHas(cont, 'envVars') && std.isObject(cont.envVars)
    then
      [{ name: envvar, value: cont.envVars[envvar] } for envvar in std.objectFields(cont.envVars)]
    else
      [];

  //
  local extraEnvVars = if std.objectHas(cont, 'extraEnvVars') && std.isArray(cont.extraEnvVars) then cont.extraEnvVars else [];

  container.new(cont.name, cont.image)
  + container.withCommand(if std.objectHas(cont, 'command') then cont.command else [])
  + container.withArgs(if std.objectHas(cont, 'args') then cont.args else [])
  + container.withEnv(envVars + extraEnvVars)
  + container.withEnvFrom(if std.objectHas(cont, 'envFrom') then cont.envFrom else [])
  // The 'IfNotPresent' image pull policy will pull the image only if not present: https://kubernetes.io/docs/concepts/containers/images/
  + container.withImagePullPolicy(if std.objectHas(cont, 'imagePullPolicy') then cont.imagePullPolicy else 'IfNotPresent')
  + container.withPorts(
    // Single port
    if std.objectHas(cont, 'port')
    then
      [
        port.new(cont.name, cont.port)
        + (if std.objectHas(cont, 'protocol') then port.withProtocol(cont.protocol) else {}),
      ]
    else if std.objectHas(cont, 'ports')
    then
      [
        port.new(contPort.name, contPort.port)
        + (if std.objectHas(contPort, 'protocol') then port.withProtocol(contPort.protocol) else {})
        for contPort in cont.ports
      ]
    else
      []
  )
  // https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#requests-and-limits
  + (
    if std.objectHas(cont, 'resourcesRequests')
    then
      util.resourcesRequests(cont.resourcesRequests.cpu, cont.resourcesRequests.mem)
    else
      {}
  )

  + (
    if std.objectHas(cont, 'resourcesLimits')
    then
      util.resourcesLimits(cont.resourcesLimits.cpu, cont.resourcesLimits.mem)
    else
      {}
  )
  // https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
  + (
    if std.objectHas(cont, 'readinessProbe')
    then { readinessProbe: cont.readinessProbe }
    else {}
  )
  + (
    if std.objectHas(cont, 'livenessProbe')
    then { livenessProbe: cont.livenessProbe }
    else {}
  )
  for cont in containersConfig
];

local publicApiIngressSpec(config) =
  local ingress = k.networking.v1.ingress;

  ingress.new(name=config.name)
  + ingress.metadata.withAnnotations(
    {
      'kubernetes.io/ingress.class': 'nginx-public',
      'argocd.argoproj.io/sync-wave': '1',
    }
    // Merge with config-specified annotations
    + if std.objectHas(config, 'annotations') then config.annotations else {}
  )
  + ingress.metadata.withLabels(
    { name: config.name, app: config.name, 'letsbuild.com/service': config.name }
    // Merge with config-specified annotations
    + if std.objectHas(config, 'labels') then config.labels else {}
  )
  + ingress.spec.withRules([
    {
      host: host,
      http: {
        paths: [
          {
            path: '/%(name)s%(path)s' % { name: config.name, path: path },
            pathType: 'Prefix',
            backend: { service: { name: 'gateway', port: { number: 80 } } },
          }
          for path in config.paths
        ],
      },
    }
    for host in config.hosts
  ]);

local ingressSpec(config, serviceObject) =
  local ingress = k.networking.v1.ingress;
  // TODO After we decide on which Ingress Contoller we'll be using some logic may be simplified
  // Set the ingress class
  local ingressClass = if std.objectHas(config, 'class') then config.class else 'nginx-public';
  // Set cert-managers issuer
  local certIssuer = if std.objectHas(config, 'certIssuer') then config.certIssuer else 'letsencrypt-prod';
  // Set 'letsbuild.com/public' annotation
  // Dictates whether should the public external-dns instance create records
  local isPublic = if std.objectHas(config, 'isPublic') then config.isPublic else false;
  // Set paths
  local paths = if std.objectHas(config, 'paths') then config.paths else ['/'];

  ingress.new(name=config.name)
  + ingress.metadata.withAnnotations(
    {
      'kubernetes.io/ingress.class': ingressClass,
      'letsbuild.com/public': std.toString(isPublic),
      'argocd.argoproj.io/sync-wave': '1',
    }
    // Merge with config-specified annotations
    + if std.objectHas(config, 'annotations') then config.annotations else {}
  )
  + ingress.metadata.withLabels(
    { name: config.name, app: config.name, 'letsbuild.com/service': config.name }
    + if std.objectHas(config, 'labels') then config.labels else {}
  )
  + ingress.spec.withRules([
    {
      host: host,
      http: {
        paths: [
          {
            path: path,
            pathType: 'Prefix',
            backend: { service: { name: serviceObject.metadata.name, port: { number: serviceObject.spec.ports[0].port } } },
          }
          for path in paths
        ],
      },
    }
    for host in config.hosts
  ])
  + ingress.spec.withTls([
    { hosts: config.hosts, secretName: if std.objectHas(config, 'secretName') then config.secretName else 'base-certificate' },
  ]);

local letsbuildServiceDeployment(
  deploymentConfig,
  withService=true,
  withIngress=false,
  withPublicApi=false,
  withAproplanApi=false,
  withServiceAccountObject={},
  publicApiConfig={},
  aproplanApiConfig={},
  ingressConfig={}
      ) = {
  local dc = deploymentConfig,
  local ic = ingressConfig,
  local mainContainer = containerSpecs([dc.container]),
  local sidecars = containerSpecs(dc.sidecarContainers),
  local initContainers = if std.objectHas(dc, 'initContainers') then containerSpecs(dc.initContainers) else [],

  local containers = mainContainer + sidecars,

  local s = self,

  local hpa = k.autoscaling.v2.horizontalPodAutoscaler,
  local deployment = k.apps.v1.deployment,
  local pdp = k.policy.v1.podDisruptionBudget,

  subPath(volume)::
    (if std.objectHas(volume, 'subPath') then k.core.v1.volumeMount.withSubPath(volume.subPath) else {}),
  volumeMounts(volumes)::
    local container = k.core.v1.container,
          volumeMount = k.core.v1.volumeMount,
          volume = k.core.v1.volume;
    local addMounts(c) = c + container.withVolumeMountsMixin([
      volumeMount.new(m.name, m.path) + s.subPath(m)
      for m in volumes
    ]);

    deployment.mapContainers(addMounts)
    + deployment.mixin.spec.template.spec.withVolumesMixin(std.set(std.prune(
      [
        if std.objectHas(m, 'configMap') then volume.fromConfigMap(m.name, m.configMap.name, if std.objectHas(m.configMap, 'items') then m.configMap.items else []) else null
        for m in volumes
      ] +
      [
        if std.objectHas(m, 'emptyDir') then volume.fromEmptyDir(m.name, m.emptyDir) else null
        for m in volumes
      ] +
      [
        if std.objectHas(m, 'secret') then volume.fromSecret(m.name, m.secret.secretName)
                                           + (if std.objectHas(m.secret, 'defaultMode') then volume.secret.withDefaultMode(m.secret.defaultMode) else {}) else null
        for m in volumes
      ] +
      [
        if std.objectHas(m, 'claim') then volume.fromPersistentVolumeClaim(m.name, m.claim.claimName) else null
        for m in volumes
      ]
    ), keyF=function(x) x.name)),

  deployment:
    deployment.new(dc.name, replicas=1, containers=containers)
    // Hide replicas to avoid conflicts with HPA
    + (if dc.autoscaling.enabled == true then { spec+: { replicas:: null } } else {})
    + objectMetadata(deployment, dc)
    // Pod topology spread constrains
    // https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/
    + deployment.spec.template.spec.withTopologySpreadConstraints([
      {
        maxSkew: 1,
        topologyKey: 'topology.kubernetes.io/zone',
        whenUnsatisfiable: 'ScheduleAnyway',
        labelSelector: {
          matchLabels: {
            app: dc.name,
            version: dc.container.tag,
          },
        },
      },
    ])
    // Init containers
    + deployment.spec.template.spec.withInitContainers(initContainers)
    // Pod Tolerations
    + deployment.spec.template.spec.withTolerations(dc.podTolerations)
    // Setting revisionHistoryLimit to clean up unused ReplicaSets
    + deployment.spec.withRevisionHistoryLimit(
      if std.objectHas(dc, 'revisionHistoryLimit') then dc.revisionHistoryLimit else 3
    )
    // Volume mount functions in deployments:
    + s.volumeMounts(dc.volumes)
    // Node Affinity
    + (if dc.nodeAffinity.enabledPreffered then deployment.spec.template.spec.affinity.nodeAffinity.withPreferredDuringSchedulingIgnoredDuringExecution(dc.nodeAffinity.preferred) else {})
    + (if dc.nodeAffinity.enabledRequired then deployment.spec.template.spec.affinity.nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTerms(dc.nodeAffinity.required.nodeSelectorTerms) else {})
    // Pod Affinity
    + (if dc.podAffinity.enabledPreffered then deployment.spec.template.spec.affinity.podAffinity.withPreferredDuringSchedulingIgnoredDuringExecution(dc.podAffinity.preferred) else {})
    + (if dc.podAffinity.enabledRequired then deployment.spec.template.spec.affinity.podAffinity.withRequiredDuringSchedulingIgnoredDuringExecution(dc.podAffinity.required) else {})
    // Pod Anti-Affinity
    + (if dc.podAntiAffinity.enabledPreffered then deployment.spec.template.spec.affinity.podAntiAffinity.withPreferredDuringSchedulingIgnoredDuringExecution(dc.podAntiAffinity.preferred) else {})
    + (if dc.podAntiAffinity.enabledRequired then deployment.spec.template.spec.affinity.podAntiAffinity.withRequiredDuringSchedulingIgnoredDuringExecution(dc.podAntiAffinity.required) else {})

    + deployment.spec.template.spec.withNodeSelector(dc.nodeSelector)
    + (
      if std.length(withServiceAccountObject) > 0
      then
        deployment.spec.template.spec.withServiceAccountName(withServiceAccountObject.metadata.name)
      else
        {}
    ),

  // We must generate a service if an ingress was requested
  service: if withService || withIngress then serviceSpec(s.deployment, dc) else {},

  hpa: (
    if dc.autoscaling.enabled
    then
      hpa.new(dc.name)
      + hpa.metadata.withAnnotations(dc.autoscaling.annotations)
      + hpa.spec.scaleTargetRef.withKind(s.deployment.kind)
      + hpa.spec.scaleTargetRef.withName(s.deployment.metadata.name)
      + hpa.spec.scaleTargetRef.withApiVersion(s.deployment.apiVersion)
      + hpa.spec.withMaxReplicas(dc.autoscaling.maxReplicas)
      + hpa.spec.withMinReplicas(dc.autoscaling.minReplicas)
      + hpa.spec.withMetrics(dc.autoscaling.metrics)
      + hpa.spec.behavior.scaleDown.withPolicies(dc.autoscaling.behavior.scaleDown.policies)
      + hpa.spec.behavior.scaleDown.withSelectPolicy(dc.autoscaling.behavior.scaleDown.selectPolicy)
      + hpa.spec.behavior.scaleDown.withStabilizationWindowSeconds(dc.autoscaling.behavior.scaleDown.stabilizationWindowSeconds)
      + hpa.spec.behavior.scaleUp.withPolicies(dc.autoscaling.behavior.scaleUp.policies)
      + hpa.spec.behavior.scaleUp.withSelectPolicy(dc.autoscaling.behavior.scaleUp.selectPolicy)
      + hpa.spec.behavior.scaleUp.withStabilizationWindowSeconds(dc.autoscaling.behavior.scaleUp.stabilizationWindowSeconds)
  ),

  pdp: (
    if dc.autoscaling.enabled
    then
    pdp.new(dc.name)
      + pdp.spec.withMaxUnavailable(dc.autoscaling.minReplicas - 1)
      + pdp.spec.selector.withMatchLabels(dc.labels)
  ),

  ingress: if withIngress then ingressSpec(ic, s.service),

  publicApiIngress: if withPublicApi then publicApiIngressSpec(publicApiConfig),

  aproplanApiIngress: if withAproplanApi then publicApiIngressSpec(aproplanApiConfig) + {
    metadata+: { name: 'aproplan-%s' % super.name },
    spec+: {
      rules: [
        rule {
          http+: {
            paths: [
              path { backend+: { service+: { name: 'aproplan-gateway' } } }
              for path in super.paths
            ],
          },
        }
        for rule in super.rules
      ],
    },
  },
};

local letsbuildServiceStatefulSet(statefulsetConfig, withService=true, withIngress=false, ingressConfig={}) = {
  local sts = statefulsetConfig,
  local mainContainer = containerSpecs([sts.container]),
  local sidecars = containerSpecs(sts.sidecarContainers),
  local initContainers = if std.objectHas(sts, 'initContainers') then containerSpecs(sts.initContainers) else [],

  local containers = mainContainer + sidecars,

  local ic = ingressConfig,

  local s = self,

  local hpa = k.autoscaling.v2.horizontalPodAutoscaler,
  local statefulSet = k.apps.v1.statefulSet,
  local pdp = k.policy.v1.podDisruptionBudget,

  statefulSet:
    statefulSet.new(sts.name, replicas=1, containers=containers)
    // Hide replicas to avoid conflicts with HPA
    + (if sts.autoscaling.enabled == true then { spec+: { replicas:: null } } else {})
    // Object metadata
    + objectMetadata(statefulSet, sts)
    // Nodeselector
    + statefulSet.spec.template.spec.withNodeSelector(sts.nodeSelector)
    + statefulSet.spec.template.spec.withTolerations(sts.podTolerations)
    + statefulSet.spec.template.spec.withInitContainers(initContainers)
    // Setting revisionHistoryLimit to clean up unused ReplicaSets
    + statefulSet.spec.withRevisionHistoryLimit(
      if std.objectHas(sts, 'revisionHistoryLimit') then sts.revisionHistoryLimit else 3
    )
    + statefulSet.spec.withServiceName(sts.name),

  service: if withService then serviceSpec(s.statefulSet, sts) else {},

  ingress: if withIngress then ingressSpec(ic, s.service),

  hpa: (
    if sts.autoscaling.enabled
    then
      hpa.new(sts.name)
      + hpa.metadata.withAnnotations(sts.autoscaling.annotations)
      + hpa.spec.scaleTargetRef.withKind(s.statefulSet.kind)
      + hpa.spec.scaleTargetRef.withName(s.statefulSet.metadata.name)
      + hpa.spec.scaleTargetRef.withApiVersion(s.statefulSet.apiVersion)
      + hpa.spec.withMaxReplicas(sts.autoscaling.maxReplicas)
      + hpa.spec.withMinReplicas(sts.autoscaling.minReplicas)
      + hpa.spec.withMetrics(sts.autoscaling.metrics)
      + hpa.spec.behavior.scaleDown.withPolicies(sts.autoscaling.behavior.scaleDown.policies)
      + hpa.spec.behavior.scaleDown.withSelectPolicy(sts.autoscaling.behavior.scaleDown.selectPolicy)
      + hpa.spec.behavior.scaleDown.withStabilizationWindowSeconds(sts.autoscaling.behavior.scaleDown.stabilizationWindowSeconds)
      + hpa.spec.behavior.scaleUp.withPolicies(sts.autoscaling.behavior.scaleUp.policies)
      + hpa.spec.behavior.scaleUp.withSelectPolicy(sts.autoscaling.behavior.scaleUp.selectPolicy)
      + hpa.spec.behavior.scaleUp.withStabilizationWindowSeconds(sts.autoscaling.behavior.scaleUp.stabilizationWindowSeconds)
  ),

  pdp: (
    if sts.autoscaling.enabled
    then
    pdp.new(sts.name)
      + pdp.spec.withMaxUnavailable(sts.autoscaling.minReplicas - 1)
      + pdp.spec.selector.withMatchLabels(sts.labels)
  )
};

local letsbuildJob(config, withServiceAccountObject={}) = {
  local job = k.batch.v1.job,

  local containers = containerSpecs([config.container]),
  local initContainers = if std.objectHas(config, 'initContainers') then containerSpecs(config.initContainers) else [],

  job:
    job.new()
    + job.metadata.withName(config.name)
    + job.spec.template.spec.withNodeSelector(config.nodeSelector)
    + objectMetadata(job, config)
    + job.spec.withBackoffLimit(0)
    + job.spec.withTtlSecondsAfterFinished(180)
    + job.spec.template.spec.withTolerations(config.podTolerations)
    + job.spec.template.spec.withRestartPolicy('Never')
    + job.spec.template.spec.withContainers(containers)
    + job.spec.template.spec.withInitContainers(initContainers)
    + (
      if std.length(withServiceAccountObject) > 0
      then
        job.spec.template.spec.withServiceAccountName(withServiceAccountObject.metadata.name)
        + job.spec.template.spec.withAutomountServiceAccountToken(true)
      else
        {}
    ),
};

{
  // Expose library methods
  letsbuildServiceDeployment:: letsbuildServiceDeployment,
  letsbuildServiceStatefulSet:: letsbuildServiceStatefulSet,
  letsbuildJob:: letsbuildJob,
}
