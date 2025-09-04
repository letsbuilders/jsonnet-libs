local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local serviceAccount = k.core.v1.serviceAccount;

{
  local c = $._config,

  serviceAccount:
    serviceAccount.new(c._name) +
    serviceAccount.metadata.withLabels(c.commonLabels),


}
