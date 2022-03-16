local lbKubernetes = import 'kubernetes/kubernetes.libsonnet';

(import 'config.libsonnet') +
{
  local c = $._config,

  // Deployment definition
  serviceDeployment:
    lbKubernetes.letsbuildServiceDeployment(
      deploymentConfig=c.deployment,
      withService=true,
      withIngress=true,
      ingressConfig=c.ingress,
    ),

  statefulSet:
    lbKubernetes.letsbuildServiceStatefulSet(c.statefulSet, withService=true),
  job:
    lbKubernetes.letsbuildJob(c.job),
}
