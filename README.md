# What
Deploy your `docker-compose` `stack` with Helm.

See `./docker-compose-redmine.yaml` for a completed stack and `./stack1.yaml` for the generated manifest. External keys can be found in `./docker-compose-redmine-override.yaml`s.

# TL;DR
```sh
helm repo add link https://linktohack.github.io/helm-stack/
kubectl create namespace your-stack
# docker stack deploy -c docker-compose.yaml your_stack
helm -n your-stack upgrade --install your-stack link/stack -f docker-compose.yaml
```

# Features
The chart is still in its early days, but it is already quite complete and I was able to deploy complex stacks with it including `traefik` and `kubernetes-dashboard`. In all cases, there is a mechanism to override the output manifest with full possibilities of K8S API (see bellow.)

- [X] Deployment: Automatically or manually: `Deployment`, `DaemonSet`, `StatefulSet`
- [X] Node: Handle placement constraints
  - `node.role`
  - `node.hostname`
  - `node.labels`
- [X] Service: `LoadBlancer` by default, easy to expose `ClusterIP` and `NodePort` via an extra key
- [X] Ingress
  - Support `traefik` labels as input with annotations. Advance features require `traefik` as Ingress controller
  - Support segment labels for services that expose multiple ports
- [X] Volume: Handle inline/external/separated volumes
  - Automatic switch to `volumeClaimTemplates` for `StatefulSet`.
  - Dynamic provisioner should work as expected, for static provisioner, `hostPath` and `nfs` are supported.
- [X] Config: Handle external/separated configs (manually, Helm doesn't allow to import external file at the moment)
- [X] Secret: Handle external/separated secrets (manually, Helm doesn't allow to import external file at the moment)

# Example
## Dockersamples
Tested in a K3s cluster with `local-path` provisioner

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
Golang template + Sprig is quite pleasure to work as a full-feature language.

# Why
Blog post https://linktohack.com/posts/evaluate-options-to-migrate-from-swarm-to-k8s/

The same technique can be applied via a proper language instead of using a Helm template but why not standing on the shoulders of giant(s). By using Helm (the de facto package manager) we're having the ability to `namespace`d the stack, rollback and so on... for free.

# Extra keys
- Services
  - `services.XXX.kind` (string, overrides automatic kind detection: `Deployment`, `DaemonSet`, `StatefulSet`)
  - `services.XXX.imagePullSecrets` (string)
  - `services.XXX.imagePullPolicy` (string)
  - `services.XXX.serviceAccountName` (string)
  - `services.XXX.clusterIP.ports` (array)
  - `services.XXX.nodePort.ports` (array, `services.XXX.ports` are for `LoadBalancer`)
- Volumes
  - `volumes.XXX.storage` (string, default `1Gi`)
  - `volumes.XXX.subPath` (string)
- Config
  - `config.XXX.file` (string | null, required by `swarm`, can be set to `null` to mount as directory)
  - `config.XXX.data` (string)
- Secret
  - `secrets.XXX.file` (string | null, required by `swarm`, can be set to `null` to mount as directory)
  - `secrets.XXX.data` (string)
  - `secrets.XXX.stringData` (string)
- Top levels
  - `chdir` (string, required in case of relative path in volume)

# Advance: Full override
The properies of the manifests can be overridden (merged) with the values from `services.XXX.Kind` and `volumes.XXX.Kind`.

You will now to have full control of the output manifests. While this is a deep merge operation, apart from the `containers` properties bellow, you cannot set the value of an invidual item inside a list but have to replace the whole list instead.

The full list of all the `Kind`s can be found in the example bellow, please note that `services.XXX.imagePullPolicy` and `volumes.XXX.storage` have already existed as extra keys

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
              - name: override-namexxx
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

```

# Other works (may related)
- [kompose](https://github.com/kubernetes/kompose)
- [compose-on-kubernetes](https://github.com/docker/compose-on-kubernetes)

# Contribution
- Additional keys (e.g. `clusterIP.ports`) should always be set via `--set` or external `values.yaml` but we
- Should have the JSON schema of `docker-compose` and additional keys

# More examples
## Redmine + MySQL
```sh
helm -n com-linktohack-redmine upgrade --install redmine /Users/qle/Downloads/sup/stack -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
    --set services.db.clusterIP.ports={3306:3306} \
    --set services.db.ports={3306:3306} \
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack --debug --dry-run
```

- `services.XXX.ports` will be exposed as `LoadBalancer` (if needed)
- addtional key `services.XXX.clusterIP.ports` will be exposed as `ClusterIP` ports

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
helm -n com-linktohack-redmine template redmine /Users/qle/Downloads/sup/stack -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
    --set services.db.clusterIP.ports={3306:3306} \
    --set services.db.ports={3306:3306} \ 
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack --debug > stack1.yaml
kubectl -n com-linktohack-redmine apply -f stack1.yaml
```

# License
MIT