{
  _config:: {
    local s = self,

    namespace: error '_config.namespace must be set',
    clusterDomain: error 'clusterDomain has to be set',
    envDomain: '%(namespace)s.%(clusterDomain)s' % { namespace: s.namespace, clusterDomain: s.clusterDomain },

    common: {
      // Shared settings between Deployment, StatefulSet and Job objects
      local common = self,

      // Object labels
      labels: {},

      // Object annotations
      annotations: {},

      // Pod Labels
      podLabels: {
        team: error 'podLabels.team must be set',
        dept: 'product',
        product: 'letsbuild',
        env: s.namespace,
      },

      // Pod annotation
      podAnnotations: {},

      // Main application containrt
      container: {
        local cont = self,

        name: common.name,
        repository: error '_config.deployment.container.repository must be set',
        tag: error '_config.deployment.container.tag must be set',
        image: '%(repository)s:%(tag)s' % { repository: cont.repository, tag: cont.tag },

        imagePullPolicy: 'IfNotPresent',

        envVars: {
          ENVIRONMENT: s.namespace,
        },
        extraEnvVars: [
          {
            name: 'HOST_IP',
            valueFrom: { fieldRef: { fieldPath: 'status.hostIP' } },
          },
          {
            name: 'POD_IP',
            valueFrom: { fieldRef: { fieldPath: 'status.podIP' } },
          },
          {
            name: 'OTEL_RESOURCE_ATTRIBUTES',
            value: 'k8s.pod.ip=$(POD_IP),container=%s' % cont.name,
          },
        ],
        envFrom: [],
      },

      sidecarContainers: [],
      initContainers: [],

    },

    deployment: s.common + {
      local depl = self,

    },

    job: s.common + {
      // overrides specific to Jobs
      annotations+: {
        // ArgoCD sync settings
        'argocd.argoproj.io/hook': 'Sync',
        'argocd.argoproj.io/hook-delete-policy': 'BeforeHookCreation',
        'argocd.argoproj.io/sync-wave': '-1',
      },
      podAnnotations+: {
        'sidecar.istio.io/inject': 'false',
        'sidecar.istio.io/proxyCPU':: null,
        'sidecar.istio.io/proxyMemory':: null,
      }

    },
    statefulSet: s.common + {
      // overrides specific to statefulsets
    },
    ingress: {
      host: error '_config.ingress.host must be set',
      // converting `host` to a list of hosts for backwards compatibility
      hosts: [self.host],
    },
    publicAPI: {
      host: 'api.%(envDomain)s' % { envDomain: s.envDomain },
      // converting `host` to a list of hosts for backwards compatibility
      hosts: [self.host],
      name: s.deployment.name,
      paths: ['/'],
    },
  },
}
