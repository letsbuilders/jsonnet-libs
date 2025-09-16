{
  local s = self,

  name: error 'name needs to be provided',
  region: error 'region needs to be provided',
  version: error 'version needs to be provided',
  accountId:: error 'accountId needs to be provided',

  vpc: {
    cidr: '',
    id: error 'vpc.id needs to be provided',
    // the shared node SG should be created by this module https://github.com/letsbuilders/infrastructure-letsbuild-modules/blob/master/aws/vpc/main.tf#L77
    // and we use it so node can connect with a private ECR endpoint
    sharedNodeSecurityGroup:: null,
    subnets: {
      private: {},
    },
  },

  addons: {
    'vpc-cni': {
      resolveConflicts: 'overwrite',
      configurationValues: {
        env: {
          ENABLE_PREFIX_DELEGATION: 'true',
          WARM_ENI_TARGET: '0',
          WARM_PREFIX_TARGET: '0',
          WARM_IP_TARGET: '2',
          MINIMUM_IP_TARGET: '10',
          AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG: 'true',
          ENI_CONFIG_LABEL_DEF: 'topology.kubernetes.io/zone',
        },
      },
    },
    coredns: {
      resolveConflicts: 'overwrite',
      configurationValues: {
        affinity: {
          nodeAffinity: {
            requiredDuringSchedulingIgnoredDuringExecution: {
              nodeSelectorTerms: [
                {
                  matchExpressions: [
                    {
                      key: 'letsbuild.com/purpose',
                      operator: 'In',
                      values: ['management'],
                    },
                  ],
                },
              ],
            },
          },
        },
        tolerations: [
          {
            key: 'management',
            value: 'true',
            effect: 'NoSchedule',
          },
        ],
      },
    },
  },

  iam: {
    withOIDC: true,
    serviceAccounts: [
      {
        metadata: {
          name: 'argocd-repo-server',
          namespace: 'argocd',
        },
        attachPolicyARNs: [
          'arn:aws:iam::%(accountId)s:policy/%(name)s-argocd' % s,
        ],
        roleName: '%s-argocd' % s.name,
        roleOnly: true,
      },
    ],
  },

  cloudWatch: {
    clusterLogging: {
      enableTypes: ['api'],
      logRetentionInDays: 3,
    },
  },

  // This field should be used to configure node groups with different subnets than the cluster was originally configured with
  // https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html#vpc-increase-ip-addresses
  nodegroupSubnets: s.vpc.subnets.private,

  managedNodeGroups: {
    default:: {
      amiFamily: 'AmazonLinux2023',
      labels: {},
      tags: {
        ['k8s.io/cluster-autoscaler/%s' % s.name]: 'owned',
        'k8s.io/cluster-autoscaler/enabled': 'TRUE',
      },
      iam: {
        attachPolicyARNs: [
          // neeeded to connect our clusters to Anodot
          // https://cloudcost.anodot.com/hc/en-us/articles/6041323733404-How-to-connect-an-AWS-Cluster-for-tracking-K8s-Costs
          'arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy',
          // policy to allow Session Manager connect
          'arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore',
          // default node policies
          'arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy',
          'arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy',
          'arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly',
        ],
        // needed for pull-through-cache images. When image is pulled first time we need permissions to create an image repo in ecr
        attachPolicy: {
          Version: '2012-10-17',
          Statement: [
            {
              Effect: 'Allow',
              Resource: '*',
              Action: [
                'ecr:CreateRepository',
                'ecr:ReplicateImage',
                'ecr:BatchImportUpstreamImage',
                'ecr:BatchGetImage',
              ],
            },
          ],
        },
      },
      overrideBootstrapCommand: std.manifestYamlDoc(self._overrideBootstrapCommand, indent_array_in_object=true, quote_keys=false),
      _overrideBootstrapCommand:: {
        apiVersion: 'node.eks.aws/v1alpha1',
        kind: 'NodeConfig',
        spec: {
          kubelet: {
            config: {
              // Set max pods to kubelet's default because we use IP prefix reservation
              // https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
              maxPods: 110,
            },
          },
        },
      },
      // subnets - hidden by default. To use subents this field needs to be unhidden
      subnets:: s.nodegroupSubnets,
      // availabilityZones - unhidden by default. To use subnets this fields needs to be hidden
      availabilityZones: std.objectFields(s.vpc.subnets.private),
      privateNetworking: true,
      propagateASGTags: true,
      spot: true,
    },

    management: self.default {
      maxSize: error 'managedNodeGroups.management.maxSize needs to be set',
      minSize: error 'managedNodeGroups.management.minSize needs to be set',
      instanceTypes: error 'managedNodeGroups.management.instanceTypes needs to be set',

      labels: {
        'letsbuild.com/purpose': 'management',
      },
      taints: [
        {
          key: 'management',
          value: 'true',
          effect: 'NoSchedule',
        },
      ],

      iam+: {
        withAddonPolicies: {
          autoScaler: true,
          externalDNS: true,
          certManager: true,
        },
        attachPolicyARNs+: [
          'arn:aws:iam::%(accountId)s:policy/%(name)s-external-dns-dynamodb' % s,
        ],
      },
    },

    worker: self.default {
      maxSize: error 'managedNodeGroups.worker.maxSize needs to be set',
      minSize: error 'managedNodeGroups.worker.minSize needs to be set',
      instanceTypes: error 'managedNodeGroups.worker.instanceTypes needs to be set',
      labels: {
        'letsbuild.com/purpose': 'worker',
      },
    },

    data: self.default {
      maxSize: error 'managedNodeGroups.data.maxSize needs to be set',
      minSize: error 'managedNodeGroups.data.minSize needs to be set',
      instanceTypes: error 'managedNodeGroups.data.instanceTypes needs to be set',
      labels: {
        'letsbuild.com/purpose': 'data',
      },
      taints: [
        {
          key: 'data',
          value: 'true',
          effect: 'NoSchedule',
        },
      ],
    },
  },
  nodeGroups: {
    default:: {
      labels: {},
      tags: {
        ['k8s.io/cluster-autoscaler/%s' % s.name]: 'owned',
        'k8s.io/cluster-autoscaler/enabled': 'TRUE',
      },
      privateNetworking: true,
      propagateASGTags: true,
      subnets:: s.nodegroupSubnets,
      availabilityZones: std.objectFields(s.vpc.subnets.private),
      asgSuspendProcesses: ['AZRebalance'],
      instancesDistribution: {
        capacityRebalance: true,
        spotAllocationStrategy: 'capacity-optimized',
      },
      iam: {
        attachPolicyARNs: [
          // policy to allow Session Manager connect
          'arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore',
          // default node policies
          'arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy',
          'arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy',
          'arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly',
        ],
        // needed for pull-through-cache images. When image is pulled first time we need permissions to create an image repo in ecr
        attachPolicy: {
          Version: '2012-10-17',
          Statement: [
            {
              Effect: 'Allow',
              Resource: '*',
              Action: [
                'ecr:CreateRepository',
                'ecr:ReplicateImage',
                'ecr:BatchImportUpstreamImage',
                'ecr:BatchGetImage',
              ],
            },
          ],
        },
      },
    },
  },
}
