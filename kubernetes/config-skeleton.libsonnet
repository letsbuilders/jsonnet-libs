{
  _config:: {
    local s = self,

    namespace: error '_config.namespace must be set',
    clusterDomain: error 'clusterDomain has to be set',
    envDomain: '%(namespace)s.%(clusterDomain)s' % { namespace: s.namespace, clusterDomain: s.clusterDomain },

    deployment: {
      local depl = self,

      name: error '_config.deployment.name must be set',

      container: {
        local cont = self,

        name: depl.name,
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
            name: 'CONTAINER_NAME',
            value: cont.name,
          },
        ],
        envFrom: [],
      },

      sidecarContainers: [],
      initContainers: [],
    },
    job: {
      local job = self,

      name: error '_config.job.name must be set',

      container: {
        local cont = self,

        name: job.name,

        repository: error '_config.job.container.repository must be set',
        tag: error '_config.job.container.tag must be set',
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
            name: 'CONTAINER_NAME',
            value: cont.name,
          },
        ],
        envFrom: [],
      },
    },
    statefulSet: {
      local sts = self,

      name: error '_config.statefulSet.name must be set',


      container: {
        local cont = self,

        name: sts.name,

        repository: error '_config.statefulSet.container.repository must be set',
        tag: error '_config.statefulSet.container.tag must be set',
        image: '%(repository)s:%(tag)s' % { repository: cont.repository, tag: cont.tag },

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
            name: 'CONTAINER_NAME',
            value: cont.name,
          },
        ],
        envFrom: [],
      },
      sidecarContainers: [],
      initContainers: [],
    },
    ingress: {
      host: error '_config.ingress.host must be set',
    },
    publicAPI: {
      host: 'api.%(envDomain)s' % { envDomain: s.envDomain },
      name: s.deployment.name,
      paths: ['/'],
    },
  },
}
