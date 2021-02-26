{
  _config:: {
    namespace: error '_config.namespace must be set',
    clusterDomain: error 'clusterDomain has to be set',
    deployment: {
      name: error '_config.deployment.name must be set',
      containers: error '_config.deployment.containers must be set',
    },
    ingress: {
      host: error '_config.ingress.host must be set',
    },
  },
}
