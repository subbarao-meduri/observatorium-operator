local cr = import 'generic-operator/config';
local thanos = (import 'github.com/observatorium/deployments/components/thanos.libsonnet');
local loki = (import 'github.com/observatorium/deployments/components/loki.libsonnet');
local api = (import 'github.com/stolostron/observatorium/jsonnet/lib/observatorium-api.libsonnet');
local obs = (import 'github.com/observatorium/deployments/components/observatorium.libsonnet');

local operatorObs = obs {

  config+:: {
    name: cr.metadata.name,
    namespace: cr.metadata.namespace,
  },

  thanos+:: thanos({
    name: cr.metadata.name,
    namespace: cr.metadata.namespace,
    commonLabels+:: {
      'app.kubernetes.io/part-of': 'observatorium',
    },
    image: if std.objectHas(cr.spec.thanos, 'image') then cr.spec.thanos.image else obs.thanos.config.image,
    version: if std.objectHas(cr.spec.thanos, 'version') then cr.spec.thanos.version else obs.thanos.config.version,
    objectStorageConfig: cr.spec.objectStorageConfig.thanos,
    hashrings: cr.spec.hashrings,
    compact+:: {
      logLevel: 'info',
      disableDownsampling: if std.objectHas(cr.spec.thanos, 'compact') && std.objectHas(cr.spec.thanos.compact, 'enableDownsampling') then !cr.spec.thanos.compact.enableDownsampling else obs.thanos.compact.config.disableDownsampling,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.compact.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'compact') then cr.spec.thanos.compact else {},

    receiveController+:: {
      hashrings: cr.spec.hashrings,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.receiveController.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'receiveController') then cr.spec.thanos.receiveController else {},

    receivers+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.receivers.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'receivers') then cr.spec.thanos.receivers else {},

    rule+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.rule.config.securityContext,
      alertmanagersURLs: if std.objectHas(cr.spec.thanos, 'rule') && std.objectHas(cr.spec.thanos.rule, 'alertmanagerURLs') then cr.spec.thanos.rule.alertmanagerURLs else obs.thanos.rule.config.alertmanagersURLs,
    } + if std.objectHas(cr.spec.thanos, 'rule') then cr.spec.thanos.rule else {},

    stores+:: {
      local deleteDelay = if std.objectHas(cr.spec.thanos, 'compact') && std.objectHas(cr.spec.thanos.compact, 'deleteDelay') then cr.spec.thanos.compact.deleteDelay else obs.thanos.compact.config.deleteDelay,
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.stores.config.securityContext,
      ignoreDeletionMarksDelay: std.ceil(std.parseInt(std.substr(deleteDelay, 0, std.length(deleteDelay) - 1)) / 2) + std.substr(deleteDelay, std.length(deleteDelay) - 1, std.length(deleteDelay)),
    } + if std.objectHas(cr.spec.thanos, 'store') then cr.spec.thanos.store else {},

    storeCache+:: (if std.objectHas(cr.spec.thanos, 'store') && std.objectHas(cr.spec.thanos.store, 'cache') then cr.spec.thanos.store.cache else {}) + {
      memoryLimitMb: if std.objectHas(cr.spec.thanos.store, 'cache') && std.objectHas(cr.spec.thanos.store.cache, 'memoryLimitMb') then cr.spec.thanos.store.cache.memoryLimitMb else obs.thanos.storeCache.config.memoryLimitMb,
      resources+: (
        if std.objectHas(cr.spec.thanos.store.cache, 'resources') then {
          memcached: cr.spec.thanos.store.cache.resources,
        } else {}
      ) + (
        if std.objectHas(cr.spec.thanos.store.cache, 'exporterResources') then {
          exporter: cr.spec.thanos.store.cache.exporterResources,
        } else {}
      ),
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.storeCache.config.securityContext,
    },

    query+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.query.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'query') then cr.spec.thanos.query else {},

    queryFrontend+:: {
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.queryFrontend.config.securityContext,
    } + if std.objectHas(cr.spec.thanos, 'queryFrontend') then cr.spec.thanos.queryFrontend else {},

    queryFrontendCache+:: (if std.objectHas(cr.spec.thanos, 'queryFrontend') && std.objectHas(cr.spec.thanos.queryFrontend, 'cache') then cr.spec.thanos.queryFrontend.cache else {}) + {
      memoryLimitMb: if std.objectHas(cr.spec.thanos.queryFrontend, 'cache') && std.objectHas(cr.spec.thanos.queryFrontend.cache, 'memoryLimitMb') then cr.spec.thanos.queryFrontend.cache.memoryLimitMb else obs.thanos.queryFrontendCache.config.memoryLimitMb,
      resources+: (
        if std.objectHas(cr.spec.thanos.queryFrontend.cache, 'resources') then {
          memcached: cr.spec.thanos.queryFrontend.cache.resources,
        } else {}
      ) + (
        if std.objectHas(cr.spec.thanos.queryFrontend.cache, 'exporterResources') then {
          exporter: cr.spec.thanos.queryFrontend.cache.exporterResources,
        } else {}
      ),
      securityContext: if std.objectHas(cr.spec, 'securityContext') then cr.spec.securityContext else obs.thanos.queryFrontendCache.config.securityContext,
    },
  }),

  loki:: if std.objectHas(cr.spec, 'loki') then loki(obs.loki.config {
    local cfg = self,
    name: cr.metadata.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: cr.metadata.namespace,
    image: if std.objectHas(cr.spec.loki, 'image') then cr.spec.loki.image else obs.loki.config.image,
    replicas: if std.objectHas(cr.spec.loki, 'replicas') then cr.spec.loki.replicas else obs.loki.config.replicas,
    version: if std.objectHas(cr.spec.loki, 'version') then cr.spec.loki.version else obs.loki.config.version,
    objectStorageConfig: if cr.spec.objectStorageConfig.loki != null then cr.spec.objectStorageConfig.loki else obs.loki.config.objectStorageConfig,
  }) else {},

  gubernator:: {},

  api:: api(obs.api.config + (
    if std.objectHas(cr.spec, 'api') then cr.spec.api else {}
  ) + {
    local cfg = self,
    name: cr.metadata.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: cr.metadata.namespace,
    commonLabels+:: {
      'app.kubernetes.io/instance': cr.metadata.name,
      'app.kubernetes.io/version': if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'version') then cr.spec.api.version else obs.api.config.version,
    },
    tenants: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'tenants') then { tenants: cr.spec.api.tenants } else obs.api.config.tenants,
    rateLimiter: {},
    metrics+: {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.thanos.queryFrontend.service.metadata.name,
        operatorObs.thanos.queryFrontend.service.metadata.namespace,
        operatorObs.thanos.queryFrontend.service.spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.thanos.receiversService.metadata.name,
        operatorObs.thanos.receiversService.metadata.namespace,
        operatorObs.thanos.receiversService.spec.ports[2].port,
      ],
    } + (
      if std.objectHas(cr.spec.api, 'additionalWriteEndpoint') then {
        additionalWriteEndpoint: cr.spec.api["additionalWriteEndpoint"],
      } else {}
    ),
    logs: if std.objectHas(cr.spec, 'loki') then {
      readEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['query-frontend-http-service'].metadata.name,
        operatorObs.loki.manifests['query-frontend-http-service'].metadata.namespace,
        operatorObs.loki.manifests['query-frontend-http-service'].spec.ports[0].port,
      ],
      tailEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['querier-http-service'].metadata.name,
        operatorObs.loki.manifests['querier-http-service'].metadata.namespace,
        operatorObs.loki.manifests['querier-http-service'].spec.ports[0].port,
      ],
      writeEndpoint: 'http://%s.%s.svc.cluster.local:%d' % [
        operatorObs.loki.manifests['distributor-http-service'].metadata.name,
        operatorObs.loki.manifests['distributor-http-service'].metadata.namespace,
        operatorObs.loki.manifests['distributor-http-service'].spec.ports[0].port,
      ],
    } else {},
  }),
};

{
  manifests: std.mapWithKey(function(k, v) v {
    metadata+: {
      ownerReferences: [{
        apiVersion: cr.apiVersion,
        kind: cr.kind,
        name: cr.metadata.name,
        uid: cr.metadata.uid,
        blockOwnerdeletion: true,
        controller: true,
      }],
    } + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local labels = v.metadata.labels,
        labels: {
          [labelName]: labels[labelName]
          for labelName in std.objectFields(labels)
          if !std.setMember(labelName, ['store.thanos.io/shard'])
        } + {
          'store.observatorium.io/shard':labels['store.thanos.io/shard'],
        }
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-query-frontend-memcached')) then {
        name: 'observability-thanos-query-frontend-memcached',
      } else {}
    ),
    spec+: (
      if (std.objectHas(cr.spec, 'nodeSelector') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            nodeSelector: cr.spec.nodeSelector,
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' || v.kind == 'Deployment') then {
        template+: {
          spec+: {
            affinity: {
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions: [
                          {
                            key: 'app.kubernetes.io/name',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/name'],
                            ],
                          },
                          {
                            key: 'app.kubernetes.io/instance',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/instance'],
                            ],
                          },
                        ],
                      },
                      topologyKey: 'kubernetes.io/hostname',
                    },
                    weight: 30,
                  },
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions: [
                          {
                            key: 'app.kubernetes.io/name',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/name'],
                            ],
                          },
                          {
                            key: 'app.kubernetes.io/instance',
                            operator: 'In',
                            values: [
                              v.metadata.labels['app.kubernetes.io/instance'],
                            ],
                          },
                        ],
                      },
                      topologyKey: 'topology.kubernetes.io/zone',
                    },
                    weight: 70,
                  },
                ],
              },
            },
          },
        },
      } else {}
    ) + (
      if (v.kind == 'Service' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local selector = v.spec.selector,
        selector: {
            [labelName]: selector[labelName]
            for labelName in std.objectFields(selector)
            if !std.setMember(labelName, ['store.thanos.io/shard'])
          } + {
            'store.observatorium.io/shard': selector['store.thanos.io/shard'],
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' && std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')) then {
        local matchLabels = v.spec.selector.matchLabels,
        local labels = v.spec.template.metadata.labels,
        selector+: {
          matchLabels: {
            [labelName]: matchLabels[labelName]
            for labelName in std.objectFields(matchLabels)
            if !std.setMember(labelName, ['store.thanos.io/shard'])
          } + {
            'store.observatorium.io/shard': matchLabels['store.thanos.io/shard'],
          },
        },
        template+: {
          metadata+: {
            labels: {
              [labelName]: labels[labelName]
              for labelName in std.objectFields(labels)
              if !std.setMember(labelName, ['store.thanos.io/shard'])
            } + {
              'store.observatorium.io/shard': labels['store.thanos.io/shard'],
            },
          },
        },
        volumeClaimTemplates: [
          vct {
            metadata+:{
              labels: {
                [labelName]: matchLabels[labelName]
                for labelName in std.objectFields(matchLabels)
                if !std.setMember(labelName, ['store.thanos.io/shard'])
              } + {
                'store.observatorium.io/shard': matchLabels['store.thanos.io/shard'],
              },
            }
          }
          for vct in v.spec.volumeClaimTemplates
        ]
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'envVars') && (v.kind == 'StatefulSet' && (
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-compact') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-receive') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-rule') || 
        std.startsWith(v.metadata.name, cr.metadata.name + '-thanos-store-shard')))) then {
        template+: {
          spec+: {
            containers: [
              if std.startsWith(c.name, 'thanos-') then c {
                env+:
                  [
                    { name: envName, value: cr.spec.envVars[envName] }
                    for envName in std.objectFields(cr.spec.envVars)
                  ]
              } else c
              for c in super.containers
            ],
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'affinity') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            affinity+: cr.spec.affinity,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'tolerations') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            tolerations: cr.spec.tolerations,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec.thanos.rule, 'reloaderResources') && (v.kind == 'StatefulSet') && v.metadata.name == cr.metadata.name + '-thanos-rule') then {
        template+: {
          spec+: {
            containers: [
              if c.name == 'configmap-reloader' then c {
                resources: cr.spec.thanos.rule.reloaderResources,
              } else c
              for c in super.containers
            ],
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec, 'pullSecret') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+:{
            imagePullSecrets: [
              {
                name: cr.spec.pullSecret,
              },
            ],
          },
        },
      } else {}
    ),
  }, operatorObs.manifests),
}
