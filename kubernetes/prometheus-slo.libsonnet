// convert set of key=value labels to a prometheus query selector
local selectorFromLabels(labels) = std.join(', ', [
  '%s="%s"' % [name, labels[name]]
  for name in std.objectFields(labels)
]);

// SLI error ratio
local errorRule(error_query, total_query, window, labels) = {
  record: 'slo:sli_error:ratio_rate%s' % window,
  expr: '(%(error_query)s) / (%(total_query)s)' % {
    error_query: error_query % { window: window },
    total_query: total_query % { window: window },
  },
  labels: labels + { window: window },
};

// error budgets, burn rates, SLO
local metaRules(objective, labels, selector) =
  [
    {
      record: 'slo_info',
      expr: 'vector(1)',
      labels: labels,
    },
    {
      record: 'slo:objective:ratio',
      expr: 'vector(%s)' % (std.parseJson(objective) / 100),
      labels: labels,
    },
    {
      record: 'slo:error_budget:ratio',
      expr: 'vector(1-%s)' % (std.parseJson(objective) / 100),
      labels: labels,
    },
    {
      record: 'slo:time_period:days',
      expr: 'vector(30)',
      labels: labels,
    },
    {
      record: 'slo:current_burn_rate:ratio',
      expr: 'slo:sli_error:ratio_rate5m{%(selector)s} / on(namespace, slo, component) group_left slo:error_budget:ratio{%(selector)s}' % { selector: selector },
      labels: labels,
    },
    {
      record: 'slo:period_burn_rate:ratio',
      expr: 'slo:sli_error:ratio_rate30d{%(selector)s} / on(namespace, slo, component) group_left slo:error_budget:ratio{%(selector)s}' % { selector: selector },
      labels: labels,
    },
    {
      record: 'slo:period_error_budget_remaining:ratio',
      expr: '1 - slo:period_burn_rate:ratio{%(selector)s}' % { selector: selector },
      labels: labels,
    },
  ];


local sloRules(slo, objective, namespace, product, component, error_query, total_query, additionalLabels={}) =
// labels to add to all metrics
  local labels = {
    slo: slo,
    namespace: namespace,
    component: component,
    product: product,
  } + additionalLabels;

  // metric selector based on defined metrics
  local selector = selectorFromLabels(labels);

  [
    {
      // SLI ratios
      name: 'slo-sli-%s-errors' % slo,
      rules: [
        errorRule(error_query, total_query, '5m', labels),
        errorRule(error_query, total_query, '30m', labels),
        errorRule(error_query, total_query, '1h', labels),
        errorRule(error_query, total_query, '2h', labels),
        errorRule(error_query, total_query, '6h', labels),
        errorRule(error_query, total_query, '1d', labels),
        {
          record: 'slo:sli_error:ratio_rate30d',
          expr: 'sum_over_time(slo:sli_error:ratio_rate5m{%(selector)s}[30d]) / count_over_time(slo:sli_error:ratio_rate5m{%(selector)s}[30d])' % {
            selector: selector,
          },
          labels: labels,
        },
      ],
    },
    {
      // error budgets, burn rates, SLO
      name: 'slo-meta-recordings-%s' % slo,
      rules: metaRules(objective=objective, labels=labels, selector=selector),
    },
  ];

{
  sloRules:: sloRules,
}