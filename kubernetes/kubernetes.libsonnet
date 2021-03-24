local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local util = import 'ksonnet-util/util.libsonnet';

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
      // TODO implement support for multiple ports
      std.trace('WARNING: multiple ports are not yet supported', [])
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
      util.resourcesRequests(cont.resourcesLimits.cpu, cont.resourcesLimits.mem)
    else
      {}
  )
  for cont in containersConfig
];

local ingressSpec(ingressConfig, serviceObject) =
  local ingress = k.extensions.v1beta1.ingress;
  // TODO After we decide on which Ingress Contoller we'll be using some logic may be simplified
  // Set the ingress class
  local ingressClass = if std.objectHas(ingressConfig, 'class') then ingressConfig.class else 'nginx-public';
  // Set cert-managers issuer
  local certIssuer = if std.objectHas(ingressConfig, 'certIssuer') then ingressConfig.certIssuer else 'letsencrypt-prod';
  // Set
  local isPublic = if std.objectHas(ingressConfig, 'isPublic') then ingressConfig.isPublic else false;

  ingress.new(name=serviceObject.metadata.name)
  + ingress.mixin.metadata.withAnnotations({
    'cert-manager.io/cluster-issuer': certIssuer,
    'kubernetes.io/ingress.class': ingressClass,
    'letsbuild.com/public': std.toString(isPublic),
  })
  // TODO this can hardly be called flexible
  + ingress.mixin.spec.withRules([
    {
      host: ingressConfig.host,
      http: {
        paths: [
          { path: '/', backend: { serviceName: serviceObject.metadata.name, servicePort: serviceObject.spec.ports[0].port } },
        ],
      },
    },
  ])
  + ingress.mixin.spec.withTls([
    { hosts: [ingressConfig.host], secretName: '%s-ingress-tls' % serviceObject.metadata.name },
  ]);

local letsbuildServiceDeployment(deploymentConfig, withService=true, withIngress=false, withServiceAccountObject={}, ingressConfig={}) = {
  local dc = deploymentConfig,
  local ic = ingressConfig,
  local containers = containerSpecs(dc.containers),

  local s = self,

  local hpa = k.autoscaling.v1.horizontalPodAutoscaler,
  local deployment = k.apps.v1.deployment,

  deployment:
    deployment.new(dc.name, replicas=1, containers=containers)
    // Hide replicas to avoid conflicts with HPA
    + (if std.objectHas(dc, 'autoscaling') then { spec+: { replicas:: null } } else {})
    + (
      if std.length(withServiceAccountObject) > 0
      then
        deployment.mixin.spec.template.spec.withServiceAccountName(withServiceAccountObject.metadata.name)
      else
        {}
    ),

  // We must generate a service if an ingress was requested
  service: if withService || withIngress then util.serviceFor(s.deployment) else {},

  hpa: (
    if std.objectHas(dc, 'autoscaling')
    then
      hpa.new()
      + hpa.mixin.metadata.withName(dc.name)
      + hpa.mixin.spec.scaleTargetRef.withKind(s.deployment.kind)
      + hpa.mixin.spec.scaleTargetRef.withName(s.deployment.metadata.name)
      // Override because this parameter is missing from the library
      + { spec+: { scaleTargetRef+: { apiVersion: s.deployment.apiVersion } } }
      + hpa.mixin.spec.withMaxReplicas(dc.autoscaling.maxReplicas)
      + hpa.mixin.spec.withMinReplicas(dc.autoscaling.minReplicas)
  ),

  ingress: if withIngress then ingressSpec(ic, s.service),
};

{
  // Expose library methods
  letsbuildServiceDeployment:: letsbuildServiceDeployment,
}
