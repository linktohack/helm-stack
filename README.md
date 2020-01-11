# What
Deploy your `docker-compose` `stack` with Helm.

A lot of assumtion has been made of how you structure your stack file, I guess we need to find a way to normalize it (maybe can be found in the source of `docker`)

See `./values.yml` for an (opinated) completed stack.

## TL;DR (if it works)
```bash
# docker stack deploy -c docker-compose.yml your_stack
helm -n your-name-space upgrade --install your-stack . -f docker-compose.yml
```

## Samples
Tested in a K3s cluster with `local-path` provisioner
### Redmine + MySQL

```
helm install -n com-linktohack-bitwarden bitwarden . -f ./docker-compose-bitwarden.yaml --set services.bitwarden.ports={80:80} 
```

### Bitwarden

```bash
helm -n com-linktohack-redmine upgrade --install redmine --set services.redmine.ports={3000:3000},services.db.ports={3306:3306} . -f ./docker-compose-redmine.yaml
```

## As template
```bash
helm --namespace com-linktohack-redmine template . --debug --set services.redmine.ports={3000:3000},services.db.ports={3306:3306} > stack1.yaml      
```

# Other works (may related)
- [kompose](https://github.com/kubernetes/kompose)
- [compose-on-kubernetes](https://github.com/docker/compose-on-kubernetes)

# How
For each of the services, we try to extract the information into 5 kind of K8s object: PV, PVC, Service, Ingress and Deployment.

# License
MIT