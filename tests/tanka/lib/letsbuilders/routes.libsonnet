local lbKubernetes = import 'kubernetes/kubernetes.libsonnet';

(import 'config.libsonnet') +
{
  local c = $._config,

  // Deployment definition with HTTPRoute enabled
  serviceDeployment:
    lbKubernetes.letsbuildServiceDeployment(
      deploymentConfig=c.deployment,
      withService=true,
      withRoutes=true,
    ),
}
