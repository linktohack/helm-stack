
template-all:
	helm template a .. -f docker-compose-dockersamples.yaml > docker-compose-dockersamples.spec.yaml
	helm template a .. -f docker-compose-kubernetes-dashboard.yaml > docker-compose-kubernetes-dashboard.spec.yaml
	helm template a .. -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml > docker-compose-redmine.spec.yaml
	helm template a .. -f docker-compose-traefik.yaml -f docker-compose-traefik-override.yaml > docker-compose-traefik.spec.yaml
