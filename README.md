# What
Deploy your `docker-compose` `stack` with Helm.

If you ever ask yourself, what do this thousand lines of `k8s` manifest or that monstrous helm chart does behind the scene, this chart may be what you were waiting for so long.

# TL;DR
```sh
helm repo add link https://linktohack.github.io/helm-stack/
kubectl create namespace your-stack
# docker stack deploy -c docker-compose.yaml your_stack
helm -n your-stack upgrade --install your-stack link/stack -f docker-compose.yaml --set services.XXX.expose={YYYY,ZZZZ/udp,TTTT:UUU}
```

While the inter-container communication is enabled in `swarm` either by `network` or `link`, in `k8s` if you have more than one service and they need to communicate together, you will need to expose the ports explicitly by `--set services.XXX.expose={YYYY}`

# Features (complete)
The chart is quite features complete and I was able to deploy complex stacks with it including `traefik` and `kubernetes-dashboard`. In all cases, there is a mechanism to override the generated manifests with full possibilities of `k8s` API (see below.)

- [X] Deployment: 
  - Default to `Deployment`
  - `DaemonSet` if `deploy.mode == global`
  - `kind` can be set manually (e.g. `StatefulSet`)
- [X] Node: Support placement constraints (`deploy.placement.constraints`) including:
  - `node.role`
  - `node.hostname`
  - `node.labels` (`==`, `!=`, `has`)
- [X] Service:
  - `ports` expose `LoadBlancer` by default
  - `expose` exposes `ClusterIP` services
  - `nodePorts` expose `NodePort` services
- [X] Ingress
  - Support `traefik` (1.7) labels (`deploy.labels`) as input with annotations including basic auth
  - Support CertManager `Issuer` and `ClusterIssuer` via extra labels `traefik.issuer` and `traefik.cluster-issuer`
    - Ingress class will be set to `nginx` but it can be overrided.
  - Support `segment` labels for services that expose multiple ports `traefik.port`, `traefik.first.port`, `traefik.second.port`...
  - Advanced features (`PathPrefixStrip`, custom headers...) will set the Ingress class to `traefik`, but again it can be overriden.
- [X] Volume: Handle inline/top-level volumes/external volumes
  - Automatic switch to `volumeClaimTemplates` for `StatefulSet` (really useful if combine with cloud provider's dynamic provisioner).
  - Dynamic provisioner should work as expected `volumes.XXX.driver_opts.type` maps directly to `storageClassName` including treatments for
    - `none` (default storage class)
    - `nfs`
    - `emptyDir`
  - Support `none` (map to `hostPath` if `volumes.XXX.driver_opts.device` presents) and `nfs` (support `addr` in `volumes.XXX.driver_opts.o`, `volumes.XXX.driver_opts.device`) static provisioner. 
- [X] Config: Handle top-level configs/external configs
  - Support both short and long syntax
  - Data can be integrated directly via `data` external key
  - Support mouting as directory by setting `file` to null. See [Advance: full override](#advance-full-override) to see how to insert more than one files
- [X] Secret: Handle top-level secrets/external secrets
  - Support both short and long syntax
  - Data can be integrated directly via `data` and `stringData` external keys
  - Support mouting as directory by setting `file` to null. See [Advance: full override](#advance-full-override) to see how to insert more than one files
- [X] Health check
  - Support both `shell` and `exec` form. For advace features /.e.g/ `httpGet`, please use full override bellow

# Example
## Dockersamples
Tested in a K3s cluster with `local-path` provisioner.

```sh
❯ helm -n com-linktohack-docker-on-compose upgrade --install sample link/stack -f docker-compose-dockersamples.yaml
Release "sample" does not exist. Installing it now.
NAME: sample
LAST DEPLOYED: Tue Jan 14 18:38:42 2020
NAMESPACE: com-linktohack-docker-on-compose
STATUS: deployed
REVISION: 1
TEST SUITE: None

❯ kubectl get all -n com-linktohack-docker-on-compose                                                                                                                                                                                                     stack/git/master 
NAME                                   READY   STATUS    RESTARTS   AGE
pod/svclb-web-loadbalancer-tcp-hk9sb   1/1     Running   0          2m2s
pod/web-57bbd888fb-dvqxj               1/1     Running   0          2m2s
pod/db-769769498d-6zqx8                1/1     Running   0          2m2s
pod/words-6465f956d-kmk9c              1/1     Running   0          2m2s
pod/words-6465f956d-sw9t2              1/1     Running   0          2m2s
pod/words-6465f956d-vchlm              1/1     Running   0          2m2s
pod/words-6465f956d-l9lnd              1/1     Running   0          2m2s
pod/words-6465f956d-2lsbz              1/1     Running   0          2m2s

NAME                           TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)           AGE
service/web-loadbalancer-tcp   LoadBalancer   10.43.235.241   2.56.99.175   33000:31908/TCP   2m4s

NAME                                        DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
daemonset.apps/svclb-web-loadbalancer-tcp   1         1         1       1            1           <none>          2m4s

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web     1/1     1            1           2m4s
deployment.apps/db      1/1     1            1           2m4s
deployment.apps/words   5/5     5            5           2m4s

NAME                              DESIRED   CURRENT   READY   AGE
replicaset.apps/web-57bbd888fb    1         1         1       2m4s
replicaset.apps/db-769769498d     1         1         1       2m4s
replicaset.apps/words-6465f956d   5         5         5       2m4s
```

## More complex examples
Please see below.

# How
Golang template + Sprig are quite a pleasure to work as a full-feature language.

# Why
Blog post https://linktohack.com/posts/evaluate-options-to-migrate-from-swarm-to-k8s/

The same technique can be applied via a proper language instead of using a Helm template but why not standing on the shoulders of giant(s). By using Helm (the de facto package manager) we're having the ability rollback and so on... for free.

# Extra keys
These keys are either not existed in `docker-compose` format or have the meaning changed. They're should be set via `--set` or second `values.yaml`.

- Services
  - `services.XXX.kind` (string, overrides automatic kind detection: `Deployment`, `DaemonSet`, `StatefulSet`)
  - `services.XXX.imagePullSecrets` (string, name of the secret)
  - `services.XXX.imagePullPolicy` (string)
  - `services.XXX.serviceAccountName` (string)
  - `services.XXX.expose` (array, ports to be exposed for other services via `ClusterIP`)
  - `services.XXX.ports` (array, ports to be exposed via `LoadBalancer`)
  - `services.XXX.nodePorts` ( ports to be exposed as `NodePort`)
- Volumes
  - `volumes.XXX.storage` (string, default `1Gi` for dynamic provisioner)
  - `volumes.XXX.subPath` (string)
- Config
  - `config.XXX.file` (string | null, required by `swarm`, can be set to `null` to mount config as a directory)
  - `config.XXX.data` (string)
- Secret
  - `secrets.XXX.file` (string | null, required by `swarm`, can be set to `null` to mount secret as a directory)
  - `secrets.XXX.data` (string)
  - `secrets.XXX.stringData` (string)
- Top levels
  - `chdir` (string, required in case of rusing relative paths in volumes)
  - `Raw` (array, manifests that should be deployed as is)

# Advance: Full override
`Raw` property allows us to deploy arbitrary manifests, but most of time, there is a better way.

The properties of the manifests can be overridden (merged) with the values from `services.XXX.Kind` and `volumes.XXX.Kind`...

You will now have full control of the output manifests. While this is a deep merge operation, apart from the `containers` properties bellow, you cannot set the value of an individual item inside a list but have to replace the whole list instead.

The full list of all the `Kind`s can be found in the listing below, please note that `services.XXX.imagePullPolicy`, `volumes.XXX.storage`, `configs.XXX.data` `secrets.XXX.stringData` are already recognized as extra keys.

```yaml
services:
  redmine:
    ClusterIP: {}
    NodePort: {}
    LoadBalancer:
      tcp: {}
      upd: {}
    Ingress:
      default: {}
      seg: {}
    Auth:
      default: {}
      seg: {}
    Deployment:
      spec:
        template:
          spec:
            containers:
              - name: override-name
                imagePullPolicy: Always
volumes:
  db:
    PV:
      spec:
        capacity:
          storage: 10Gi
        persistentVolumeReclaimPolicy: Retain
    PVC:
      spec:
        resources:
          requests:
            storage: 10Gi
configs:
  redmine_config:
    ConfigMap:
      data:
        hello.yaml: there
secrets:
  tested:
    Secret:
      stringData: ""
```

# Other works
- [kompose](https://github.com/kubernetes/kompose)
- [compose-on-kubernetes](https://github.com/docker/compose-on-kubernetes)

# Contribution
- More `traefik` headers
- JSON schema of `docker-compose` and extra keys

# More examples
## Redmine + MySQL
This example contains almost all the possible configurations of this stack.

```sh
helm -n com-linktohack-redmine upgrade --install redmine link/stack -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
    --set services.db.expose={3306:3306} \
    --set services.db.ports={3306:3306} \
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack --debug --dry-run
```

- `services.XXX.ports` will be exposed as `LoadBalancer` (if needed)
- Additional key `services.XXX.expose` will be exposed as `ClusterIP` ports

## Traefik ingress
```sh   
helm -n kube-system upgrade --install traefik link/stack -f docker-compose-traefik.yml -f docker-compose-traefik-override.yml
```

## Kubernetes dashboard (with basic auth and skip login)
- Create `kubernetes-dashboard` service account
- Bind it with `cluster-admin` role

```sh
helm -n kubernetes-dashboard upgrade --install dashboard link/stack -f docker-compose-kubernetes-dashboard.yml 
```

## Via template
```sh
helm -n com-linktohack-redmine template redmine link/stack -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
    --set services.db.expose={3306:3306} \
    --set services.db.ports={3306:3306} \
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack --debug > stack1.yaml
kubectl -n com-linktohack-redmine apply -f stack1.yaml
```

# License
MIT