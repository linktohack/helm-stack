# What
Deploy your `docker-compose` `stack` with Helm.

A lot of assumption has been made of how you structure your stack file, I guess we need to find a way to normalize it (maybe can be found in the source of `docker`)

See `./values.yml` for an (opinionated) completed stack and `./stack1.yaml` for the geerated stack.

## TL;DR (if it works)
```bash
# docker stack deploy -c docker-compose.yml your_stack
helm -n your-name-space upgrade --install your-stack . -f docker-compose.yml
```

## Samples
Tested in a K3s cluster with `local-path` provisioner

### Redmine + MySQL
```
helm -n com-linktohack-redmine upgrade --install redmine . -f docker-compose-redmine.yaml --set services.db.clusterip.ports={3306:3306},services.db.ports={30306:3306}
```

- `services.[service].ports` will be exposed as `NodePort` (if needed)
- addtional key `services.[service].clusterip.ports` will be exposed as `ClusterIP` ports

### Bitwarden
```bash
helm -n com-linktohack-bitwarden upgrade --install bitwarden . -f ./docker-compose-bitwarden.yaml
```

## As template
```bash
helm -n com-linktohack-redmine template . -f docker-compose-redmine.yaml --set services.db.clusterip.ports={3306:3306},services.db.ports={30306:3306} > stack1.yml
```

# Other works (may related)
- [kompose](https://github.com/kubernetes/kompose)
- [compose-on-kubernetes](https://github.com/docker/compose-on-kubernetes)

# How
For each of the services, we try to extract the information into 5 kinds of K8s object: PV, PVC, Service (NodePort and ClusterIP), Ingress and Deployment.

# Why
Blog post https://linktohack.com/posts/evaluate-options-to-migrate-from-swarm-to-k8s/

The same technique can be applied via a proper language instead of using a Helm template why not standing on the shoulders of giant(s). Helm is the de facto package manager, using Helm we're having the ability to `namespace`d the stack, rollback and so on... for free.

# Limitation
- [ ] Volume: Handle external/separated volumes
- [ ] Ingress: Handle comma, semicolon separated rule (multiple hosts, path...)
- [ ] Ingress: Handle segment labels for services expose multiple ports

# Contribution
- Additional keys (e.g. `clusterip.ports`) should always be set via `--set` or external `values.yml` but we
- Should have the JSON schema of `docker-compose` and additional keys

# License
MIT