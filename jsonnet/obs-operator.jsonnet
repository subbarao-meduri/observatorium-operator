local cr = import 'generic-operator/config';
local thanos = (import 'github.com/observatorium/deployments/components/thanos.libsonnet');
local loki = (import 'github.com/observatorium/deployments/components/loki.libsonnet');
local api = (import 'github.com/observatorium/observatorium/jsonnet/lib/observatorium-api.libsonnet');
local obs = (import 'github.com/observatorium/deployments/components/observatorium.libsonnet');

local operatorObs = obs {

  thanos+:: thanos({
    name: cr.metadata.name,
    namespace: cr.metadata.namespace,
    compact+:: {
      objectStorageConfig: cr.spec.objectStorageConfig.thanos,
      logLevel: 'info',
      disableDownsampling: if std.objectHas(cr.spec, 'compact') && std.objectHas(cr.spec.compact, 'enableDownsampling') then !cr.spec.compact.enableDownsampling else obs.thanos.compact.config.disableDownsampling,
    } + if std.objectHas(cr.spec, 'compact') then cr.spec.compact else {},

    receiveController+:: {
      hashrings: cr.spec.hashrings,
    } + if std.objectHas(cr.spec, 'thanosReceiveController') then cr.spec.thanosReceiveController else {},

    receivers+:: {
      hashrings: cr.spec.hashrings,
      objectStorageConfig: cr.spec.objectStorageConfig.thanos,
    } + if std.objectHas(cr.spec, 'receivers') then cr.spec.receivers else {},

    rule+:: {
      objectStorageConfig: cr.spec.objectStorageConfig.thanos,
    } + if std.objectHas(cr.spec, 'rule') then cr.spec.rule else {},

    stores+:: {
      objectStorageConfig: cr.spec.objectStorageConfig.thanos,
    } + if std.objectHas(cr.spec, 'store') then cr.spec.store else {},

    storeCache+:: (if std.objectHas(cr.spec, 'store') && std.objectHas(cr.spec.store, 'cache') then cr.spec.store.cache else {}) + {
      memoryLimitMb: if std.objectHas(cr.spec.store, 'cache') && std.objectHas(cr.spec.store.cache, 'memoryLimitMb') then cr.spec.store.cache.memoryLimitMb else obs.thanos.storeCache.config.memoryLimitMb,
      resources+: (
        if std.objectHas(cr.spec.store.cache, 'resources') then {
          memcached: cr.spec.store.cache.resources
        } else {}
      ) + (
        if std.objectHas(cr.spec.store.cache, 'exporterResources') then {
          exporter: cr.spec.store.cache.exporterResources
        } else {}
      ),
    },

    query+:: if std.objectHas(cr.spec, 'query') then cr.spec.query else {},

    queryFrontend+:: if std.objectHas(cr.spec, 'queryFrontend') then cr.spec.queryFrontend else {},
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

  api:: api(obs.api.config {
    local cfg = self,
    name: cr.metadata.name + '-' + cfg.commonLabels['app.kubernetes.io/name'],
    namespace: cr.metadata.namespace,
    image: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'image') then cr.spec.api.image else obs.api.config.image,
    version: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'version') then cr.spec.api.version else obs.api.config.version,
    replicas: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'replicas') then cr.spec.api.replicas else obs.api.config.replicas,
    resources: if std.objectHas(cr.spec.api, 'resources') then cr.spec.api.resources else obs.api.config.resources,
    tls: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'tls') then cr.spec.api.tls else obs.api.config.tls,
    rbac: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'rbac') then cr.spec.api.rbac else obs.api.config.rbac,
    tenants: if std.objectHas(cr.spec, 'api') && std.objectHas(cr.spec.api, 'tenants') then { tenants: cr.spec.api.tenants } else obs.api.config.tenants,
    rateLimiter: {},
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
    },
    spec+: (
      if (std.objectHas(obs.config, 'nodeSelector') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            nodeSelector: obs.config.nodeSelector,
          },
        },
      } else {}
    ) + (
      if (v.kind == 'StatefulSet' || v.kind == 'Deployment') then {
        template+: {
          spec+:{
            affinity: {
              podAntiAffinity: {
                preferredDuringSchedulingIgnoredDuringExecution: [
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions:[
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
                      topologyKey: "kubernetes.io/hostname",
                    },
                    weight: 30,
                  },
                  {
                    podAffinityTerm: {
                      labelSelector: {
                        matchExpressions:[
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
                      topologyKey: "topology.kubernetes.io/zone",
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
      if (std.objectHas(obs.config, 'affinity') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+: {
            affinity+: obs.config.affinity,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(obs.config, 'tolerations') && (v.kind == 'StatefulSet' || v.kind == 'Deployment')) then {
        template+: {
          spec+:{
            tolerations: obs.config.tolerations,
          },
        },
      } else {}
    ) + (
      if (std.objectHas(cr.spec.rule, 'reloaderResources') && (v.kind == 'StatefulSet') && v.metadata.name == obs.config.name + '-thanos-rule') then {
        template+: {
          spec+:{
            containers: [
              if c.name == 'configmap-reloader' then c {
                resources: cr.spec.rule.reloaderResources,
              } else c
              for c in super.containers
            ],
          },
        },
      } else {}
    ),
  }, operatorObs.manifests),
}
