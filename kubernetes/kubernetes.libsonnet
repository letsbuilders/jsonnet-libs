local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local util = import 'github.com/grafana/jsonnet-libs/ksonnet-util/util.libsonnet';


local objectMetadata(object, config) =
  // object labels
  object.mixin.metadata.withLabels(
    {
      name: config.name, app: config.name, 'letsbuild.com/service': config.name
    } + config.labels
  )
  // object annotation
  + object.mixin.metadata.withAnnotations(
    {
      'argocd.argoproj.io/sync-wave': '1',
    } + config.annotations
  )
  // Pod labels
  + object.mixin.spec.template.metadata.withLabels(
    {
      name: config.name, app: config.name, version: config.container.tag, 'letsbuild.com/service': config.name
    } + config.podLabels
  )
  // Pod Annotation
  + object.mixin.spec.template.metadata.withAnnotations(
    {
      'sidecar.istio.io/proxyCPU': '10m',
      //      'sidecar.istio.io/proxyCPULimit': '',
      'sidecar.istio.io/proxyMemory': '80Mi',
      //      'sidecar.istio.io/proxyMemoryLimit': '',
    } + config.podAnnotations
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
  + container.withEnv(envVars + extraEnvVars)
  + container.withEnvFrom(if std.objectHas(cont, 'envFrom') then cont.envFrom else [])
  // The 'IfNotPresent' image pull policy will pull the image only if not present: https://kubernetes.io/docs/concepts/containers/images/
  + container.withImagePullPolicy(if std.objectHas(cont, 'imagePullPolicy') then cont.imagePullPolicy else 'IfNotPresent')
  + container.withPorts(
    // Single port
    if std.objectHas(cont, 'port')
    then
      [port.new(cont.name, cont.port)]
    else if std.objectHas(cont, 'ports')
    then
      [
        port.new(contPort.name, contPort.port)
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

local publicApiIngressSpec(publicApiConfig) =
  local ingress = k.extensions.v1beta1.ingress;

  ingress.new(name=publicApiConfig.name)
  + ingress.mixin.metadata.withAnnotations(
    {
      'kubernetes.io/ingress.class': 'nginx-public',
    }
    // Merge with config-specified annotations
    + if std.objectHas(publicApiConfig, 'annotations') then publicApiConfig.annotations else {}
  )
  + ingress.mixin.spec.withRules([
    {
      host: publicApiConfig.host,
      http: {
        paths: [
          {
            path: '/%(name)s%(path)s' % { name: publicApiConfig.name, path: path },
            pathType: 'Prefix',
            backend: { serviceName: 'gateway', servicePort: 80 },
          }
          for path in publicApiConfig.paths
        ],
      },
    },
  ]);

local ingressSpec(ingressConfig, serviceObject) =
  local ingress = k.extensions.v1beta1.ingress;
  // TODO After we decide on which Ingress Contoller we'll be using some logic may be simplified
  // Set the ingress class
  local ingressClass = if std.objectHas(ingressConfig, 'class') then ingressConfig.class else 'nginx-public';
  // Set cert-managers issuer
  local certIssuer = if std.objectHas(ingressConfig, 'certIssuer') then ingressConfig.certIssuer else 'letsencrypt-prod';
  // Set 'letsbuild.com/public' annotation
  // Dictates whether should the public external-dns instance create records
  local isPublic = if std.objectHas(ingressConfig, 'isPublic') then ingressConfig.isPublic else false;
  // Set paths
  local paths = if std.objectHas(ingressConfig, 'paths') then ingressConfig.paths else ['/'];

  ingress.new(name=serviceObject.metadata.name)
  + ingress.mixin.metadata.withAnnotations(
    {
      'kubernetes.io/ingress.class': ingressClass,
      'letsbuild.com/public': std.toString(isPublic),
    }
    // Merge with config-specified annotations
    + if std.objectHas(ingressConfig, 'annotations') then ingressConfig.annotations else {}
  )
  + ingress.mixin.spec.withRules([
    {
      host: ingressConfig.host,
      http: {
        paths: [
          { path: path, backend: { serviceName: serviceObject.metadata.name, servicePort: serviceObject.spec.ports[0].port } }
          for path in paths
        ],
      },
    },
  ])
  + ingress.mixin.spec.withTls([
    { hosts: [ingressConfig.host], secretName: 'base-certificate' },
  ]);

local letsbuildServiceDeployment(deploymentConfig, withService=true, withIngress=false, withPublicApi=false, withServiceAccountObject={}, publicApiConfig={}, ingressConfig={}) = {
  local dc = deploymentConfig,
  local ic = ingressConfig,
  local mainContainer = containerSpecs([dc.container]),
  local sidecars = containerSpecs(dc.sidecarContainers),
  local initContainers = if std.objectHas(dc, 'initContainers') then containerSpecs(dc.initContainers) else [],

  local containers = mainContainer + sidecars,

  local s = self,

  local hpa = k.autoscaling.v1.horizontalPodAutoscaler,
  local deployment = k.apps.v1.deployment,

  deployment:
    deployment.new(dc.name, replicas=1, containers=containers)
    // Hide replicas to avoid conflicts with HPA
    + (if std.objectHas(dc, 'autoscaling') then { spec+: { replicas:: null } } else {})
    + objectMetadata(deployment, dc)
    // Pod topology spread constrains
    // https://kubernetes.io/docs/concepts/workloads/pods/pod-topology-spread-constraints/
    + deployment.mixin.spec.template.spec.withTopologySpreadConstraints([
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
    + deployment.mixin.spec.template.spec.withInitContainers(initContainers)
    // Setting revisionHistoryLimit to clean up unused ReplicaSets
    + deployment.mixin.spec.withRevisionHistoryLimit(
      if std.objectHas(dc, 'revisionHistoryLimit') then dc.revisionHistoryLimit else 3
    )
    + deployment.mixin.spec.template.spec.withNodeSelector({
      'kubernetes.io/os': 'linux',
      'letsbuild.com/purpose': 'worker',
      'kubernetes.io/arch': 'amd64',
    })
    + (
      if std.length(withServiceAccountObject) > 0
      then
        deployment.mixin.spec.template.spec.withServiceAccountName(withServiceAccountObject.metadata.name)
      else
        {}
    ),

  // We must generate a service if an ingress was requested
  service:
    if withService || withIngress
    then util.serviceFor(s.deployment, nameFormat='%(port)s') + {
      spec+: {
        selector+: {
          // We don't want to use the version label in service selectors
          // Services should select all versions of an app
          // Otherwise rolling updates won't be possible
          version:: null,
        },
      },
    }
    else {},

  hpa: (
    if std.objectHas(dc, 'autoscaling')
    then
      hpa.new(dc.name)
      + hpa.mixin.spec.scaleTargetRef.withKind(s.deployment.kind)
      + hpa.mixin.spec.scaleTargetRef.withName(s.deployment.metadata.name)
      // Override because this parameter is missing from the library
      + { spec+: { scaleTargetRef+: { apiVersion: s.deployment.apiVersion } } }
      + hpa.mixin.spec.withMaxReplicas(dc.autoscaling.maxReplicas)
      + hpa.mixin.spec.withMinReplicas(dc.autoscaling.minReplicas)
  ),

  ingress: if withIngress then ingressSpec(ic, s.service),

  publicApiIngress: if withPublicApi then publicApiIngressSpec(publicApiConfig),
};

local letsbuildServiceStatefulSet(statefulsetConfig, withService=true) = {
  local sts = statefulsetConfig,
  local mainContainer = containerSpecs([sts.container]),
  local sidecars = containerSpecs(sts.sidecarContainers),
  local initContainers = if std.objectHas(sts, 'initContainers') then containerSpecs(sts.initContainers) else [],

  local containers = mainContainer + sidecars,

  local s = self,

  local hpa = k.autoscaling.v1.horizontalPodAutoscaler,
  local statefulSet = k.apps.v1.statefulSet,

  statefulSet:
    statefulSet.new(sts.name, replicas=1, containers=containers)
    // Hide replicas to avoid conflicts with HPA
    + (if std.objectHas(sts, 'autoscaling') then { spec+: { replicas:: null } } else {})
    // Object metadata
    + objectMetadata(statefulSet, sts)
    // Nodeselector
    + statefulSet.mixin.spec.template.spec.withNodeSelector({
      'kubernetes.io/os': 'linux',
      'letsbuild.com/purpose': 'worker',
      'kubernetes.io/arch': 'amd64',
    })
    + statefulSet.mixin.spec.template.spec.withInitContainers(initContainers)
    // Setting revisionHistoryLimit to clean up unused ReplicaSets
    + statefulSet.mixin.spec.withRevisionHistoryLimit(
      if std.objectHas(sts, 'revisionHistoryLimit') then sts.revisionHistoryLimit else 3
    )
    + statefulSet.mixin.spec.withServiceName(sts.name),

  service: if withService then util.serviceFor(s.statefulSet, nameFormat='%(port)s') else {},

  hpa: (
    if std.objectHas(sts, 'autoscaling')
    then
      hpa.new(sts.name)
      + hpa.mixin.spec.scaleTargetRef.withKind(s.statefulSet.kind)
      + hpa.mixin.spec.scaleTargetRef.withName(s.statefulSet.metadata.name)
      // Override because this parameter is missing from the library
      + { spec+: { scaleTargetRef+: { apiVersion: s.statefulSet.apiVersion } } }
      + hpa.mixin.spec.withMaxReplicas(sts.autoscaling.maxReplicas)
      + hpa.mixin.spec.withMinReplicas(sts.autoscaling.minReplicas)
  ),
};

local letsbuildJob(config, withServiceAccountObject={}) = {
  local job = k.batch.v1.job,

  local containers = containerSpecs([config.container]),
  local initContainers = if std.objectHas(config, 'initContainers') then containerSpecs(config.initContainers) else [],

  job:
    job.new()
    + job.mixin.metadata.withName(config.name)
    + job.mixin.spec.template.spec.withNodeSelector({
      'kubernetes.io/os': 'linux',
      'letsbuild.com/purpose': 'worker',
      'kubernetes.io/arch': 'amd64',
    })
    + objectMetadata(job, config)
    + job.mixin.spec.withBackoffLimit(0)
    + job.mixin.spec.withTtlSecondsAfterFinished(180)
    + job.mixin.spec.template.spec.withRestartPolicy('Never')
    + job.mixin.spec.template.spec.withContainers(containers)
    + job.mixin.spec.template.spec.withInitContainers(initContainers)
    + (
      if std.length(withServiceAccountObject) > 0
      then
        job.mixin.spec.template.spec.withServiceAccountName(withServiceAccountObject.metadata.name)
        + job.mixin.spec.template.spec.withAutomountServiceAccountToken(true)
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
