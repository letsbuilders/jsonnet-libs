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

      // Example of usage of volumeMounts:
      // Add in config.deployment section next values:
        volumes: [
          {
            name: 'configmap-volume',
            path: '/configmap',
            configMap: {
              name: 'my-cm',
            },
          },
          {
            name: 'emptydir-volume',
            path: '/emptydir',
            subPath: '/emptydir/emptydir',
            emptyDir: {
              sizeLimit: '500Mi',
            },
          },
          {
          name: 'pvc-volume',
          path: '/pvc',
          readOnly: false,
          subPath: '/pvc/pvc.txt',
          claim: {
            claimName: 'my-pvc'
          }
        },
          {
            name: 'secret-volume',
            path: '/secret',
            subPath: '/secret/secret.txt',
            secret: {
              secretName: 'my-secret',
              defaultMode: 256,
            },
          },
        ],

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
    ),
  configmap:
    configMap.new('testName')
    + configMap.withData({ 'testKey': (
      (importstr 'configmap.json')
    )})
}



```
