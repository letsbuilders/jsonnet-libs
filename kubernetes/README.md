### Example

The below example will create an autoscaled `Deployment` with 2 containers, a `Service` and an `Ingress`

```jsonnet

local lbKubernetes = (import 'github.com/letsbuilders/jsonnet-libs/kubernetes/kubernetes.libsonnet');
local lbInitContainers = (import 'github.com/letsbuilders/jsonnet-libs/kubernetes/init-containers.libsonnet');

(import 'github.com/letsbuilders/jsonnet-libs/kubernetes/config-skeleton.libsonnet') +
{ 
  _config+: {
    deployment: {
      name: 'example-service',
   
      // Autoscaling
      autoscaling: {
        minReplicas: 1,
        maxReplicas: 3,
      },
      
      initContainers: [
        lbInitContainers.waitForPostgres('example-service-postgres'),
      ],

      containers: [
        { 
          // Main application
          name: 'example',
          image: 'example:latest',
          // Resource requirements
          resourcesRequests: {
            cpu: '100m',
            mem: '100Mi',
          },
          port: 80,
        },
        {
          // Sidecar container
          name: 'metrics',
          image: 'public.ecr.aws/bitnami/nginx-exporter:latest',
          port: 9090,
        }
      ],
    },
    ingress: {
      host: '%(namespace)s.%(clusterDomain)s' % {namespace: s.namespace, clusterDomain: s.clusterDomain}
    }
  },
  local c = $._config,  

  // Application deployment
  webServiceDeployment:
    lbKubernetes.letsbuildServiceDeployment(
      deploymentConfig=c.deployment,
      withService=true,
      withIngress=true,
      ingressConfig=c.ingress
    )
}



```
