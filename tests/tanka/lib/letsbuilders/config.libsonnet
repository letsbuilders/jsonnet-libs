local lbInitContainers = import 'kubernetes/init-containers.libsonnet';

(import 'kubernetes/config-skeleton.libsonnet') +
{
  _config+: {
    local s = self,
    name: 'test-service',

    deployment+: {

      podLabels+: {
        team: 'devops',
      },

      // Autoscaling
      autoscaling+: {
        minReplicas: 1,
        maxReplicas: 3,
      },

      initContainers+: [
        lbInitContainers.waitForPostgres('test-service-postgres'),
      ],

      container+: {
        // Main application
        name: 'test',

        repository: '111111111111.dkr.ecr.eu-west-1.amazonaws.com/service/test',
        tag: 'sha-%s' % std.extVar('tag'),
        // Resource requirements
        resourcesRequests: {
          cpu: '100m',
          mem: '100Mi',
        },
        port: 80,
      },
      sidecars+: [
        {
          // Sidecar container
          name: 'test-sidecar',
          image: 'public.ecr.aws/letsbuild/test:latest',
          port: 9090,
        },
      ],
    },

    statefulSet+: {
      name: 'test',
      podLabels+: {
        team: 'devops'
      },
      container+: {
        // Main application
        name: 'test',

        repository: '111111111111.dkr.ecr.eu-west-1.amazonaws.com/service/test',
        tag: 'sha-%s' % std.extVar('tag'),
      }
    },
    job+: {
      name: 'test',
      podLabels+: {
        team: 'devops'
      },
      container+: {
        // Main application
        name: 'test',

        repository: '111111111111.dkr.ecr.eu-west-1.amazonaws.com/service/test',
        tag: 'sha-%s' % std.extVar('tag'),
      }
    },
    ingress+: {
      host: '%(namespace)s.%(clusterDomain)s' % { namespace: s.namespace, clusterDomain: s.clusterDomain },
    },
  },
}
