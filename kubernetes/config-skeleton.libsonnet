{
  _config:: {
    local s = self,
    namespace: error '_config.namespace must be set',
    clusterDomain: error 'clusterDomain has to be set',
    deployment: {
      name: error '_config.deployment.name must be set',
      container: {
        local cont = self,

        name: error '_config.deployment.container.name must be set',
        repository: error '_config.deployment.container.repository must be set',
        tag: error '_config.deployment.container.tag must be set',
        image: '%(repository)s:%(tag)s' % { repository: cont.repository, tag: cont.tag },

        imagePullPolicy: 'IfNotPresent',
        envVars: {
          ENVIRONMENT: s.namespace,
        },
        extraEnvVars: [{
          name: 'HOST_IP',
          valueFrom: { fieldRef: { fieldPath: 'status.hostIP' } },
        }],
        envFrom: [],
      },
      sidecarContainers: [],
      initContainers: [],
    },
    job: {
      name: error '_config.job.name must be set',
      container: {
        local cont = self,

        name: error '_config.job.container.name must be set',

        repository: error '_config.job.container.repository must be set',
        tag: error '_config.job.container.tag must be set',
        image: '%(repository)s:%(tag)s' % { repository: cont.repository, tag: cont.tag },

        imagePullPolicy: 'IfNotPresent',

        envVars: {
          ENVIRONMENT: s.namespace,
        },
        extraEnvVars: [],
        envFrom: [],
      },
    },
    ingress: {
      host: error '_config.ingress.host must be set',
    },
  },
}
