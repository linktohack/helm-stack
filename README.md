# What
Deploy your `docker-compose` `stack` with Helm.

See `./docker-compose-redmine.yaml` for an (opinionated) completed stack and `./stack1.yaml` for the generated stack.

## TL;DR
```sh
helm repo add link https://linktohack.github.io/helm-stack/
kubectl create namespace your-name-space
# docker stack deploy -c docker-compose.yaml your_stack
helm -n your-name-space upgrade --install your-stack link/stack -f docker-compose.yaml
```

## Samples
Tested in a K3s cluster with `local-path` provisioner

### Dockersamples
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

### Redmine + MySQL
```sh
helm -n com-linktohack-redmine upgrade --install redmine link/stack -f docker-compose-redmine.yaml \
    --set services.db.ClusterIP.ports={3306:3306} \
    --set services.db.ports={3306:3306} \
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack
```

- `services.XXX.ports` will be exposed as `LoadBalancer` (if needed)
- addtional key `services.XXX.ClusterIP.ports` will be exposed as `ClusterIP` ports

### Bitwarden
```sh   
helm -n com-linktohack-bitwarden upgrade --install bitwarden link/stack -f ./docker-compose-bitwarden.yaml
```

### OpenVPN
```sh
helm -n com-linktohack-ipsec upgrade --install ipsec link/stack -f docker-compose-openvpn.yaml \
    --set volumes.config.driver_opts=null,volumes.config.storage=100Mi
```

## Via template
```sh
helm -n com-linktohack-redmine template openvpn link/stack -f docker-compose-redmine.yaml  \
    --set services.db.ClusterIP.ports={3306:3306} \
    --set services.db.ports={3306:3306} \
    --set services.db.deploy.placement.constraints={node.role==manager} \
    --set services.redmine.deploy.placement.constraints={node.role==manager} \
    --set chdir=/stack \
    > stack1.yaml
kubectl -n com-linktohack-redmine apply -f stack1.yaml
```

```sh
helm -n com-linktohack-ipsec template ipsec link/stack -f docker-compose-openvpn.yaml \
    --set volumes.config.storage=1Gi \
    --set volumes.config.driver_opt=null \
    > stack2.yaml  
kubectl -n com-linktohack-ipsec apply -f stack2.yaml

```

# Other works (may related)
- [kompose](https://github.com/kubernetes/kompose)
- [compose-on-kubernetes](https://github.com/docker/compose-on-kubernetes)

# How
For each of services defined in `docker-compose.yaml`, we try to extract the information into 5 kinds of K8s object: PV, PVC, Service (ClusterIP and LoadBalancer), Ingress and Deployment.

# Why
Blog post https://linktohack.com/posts/evaluate-options-to-migrate-from-swarm-to-k8s/

The same technique can be applied via a proper language instead of using a Helm template but why not standing on the shoulders of giant(s). By using Helm (the de facto package manager) we're having the ability to `namespace`d the stack, rollback and so on... for free.

# Limitation
- [X] Volume: Handle external/separated volumes
- [X] Ingress: Handle comma, semicolon separated rule (multiple hosts, path...)
- [ ] Ingress: Handle segment labels for services that expose multiple ports
- [X] Node: Handle placement constraints

# Note on Ingress
We currently support parsing `traefik` labels with three rules: `Host`, `PathPrefixStrip` and `AddPrefix`.
If either `PathPrefixStrip` or `AddPrefix` is available in the label, the annotation class of the Ingress will be set to traefik.
```
    kubernetes.io/ingress.class: traefik
```

`port` and `backend` are supported.

# Note on PV
Both inlined and separated volumes are supported. Dynamic provisioner should work as expected, for static provisioner, `hostPath` and `nfs` are supported.

# Note on node constraints
The following rules are supported:
- `node.role`
- `node.hostname`
- `node.labels`

# External keys
- `services.XXX.kind` (string, overrides automatic kind detection: `Deployment`, `DaemonSet`, `StatefulSet`)
- `services.XXX.imagePullSecrets` (string)
- `services.XXX.imagePullPolicy` (string)
- `services.XXX.serviceAccountName` (string)
- `services.XXX.terminationGracePeriodSeconds` (number)
- `services.XXX.NodePort.ports` (array, `services.XXX.ports` are for `LoadBalancer`)
- `services.XXX.ClusterIP.ports` (array)
- `volumes.XXX.storage` (string)
- `volumes.XXX.persistentVolumeReclaimPolicy` (string, either `Delete` or `Retain`)
- `chdir` (string, required in case of relative path in volume)

# Contribution
- Additional keys (e.g. `ClusterIP.ports`) should always be set via `--set` or external `values.yaml` but we
- Should have the JSON schema of `docker-compose` and additional keys

# License
MIT