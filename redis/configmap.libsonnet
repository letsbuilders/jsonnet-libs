local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local configMap = k.core.v1.configMap;

{
  local c = $._config,
  configMap:
    configMap.new(c._name + '-configuration', c.config.content) +
    configMap.metadata.withLabels(c.commonLabels),
}
