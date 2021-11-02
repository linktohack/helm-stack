.PHONY: all
all:
	helm package .
	helm repo index .

.PHONY: test
test:
	# redmine kitchen sink
	helm -n com-linktohack-redmine template redmine . -f test/docker-compose-redmine.yaml -f test/docker-compose-redmine-override.yaml \
		--set services.db.expose={3306:3306} \
		--set services.db.ports={3306:3306} \
		--set services.db.deploy.placement.constraints={node.role==manager} \
		--set services.redmine.deploy.placement.constraints={node.role==manager} \
		--set chdir=/stack | yq -sy 'sort_by(.kind, .metadata.name) | .[]' > test/docker-compose-redmine.spec2.yaml
	diff -u test/docker-compose-redmine.spec.yaml test/docker-compose-redmine.spec2.yaml

	# dockersamples
	helm -n com-linktohack-dockersamples template dockersamples . -f test/docker-compose-dockersamples.yaml \
		| yq -sy 'sort_by(.kind, .metadata.name) | .[]' > test/docker-compose-dockersamples.spec2.yaml
	diff -u test/docker-compose-dockersamples.spec.yaml test/docker-compose-dockersamples.spec2.yaml

	# kubernetes dashboard
	helm -n com-linktohack-kubernetes-dashboard template kubernetes-dashboard . -f test/docker-compose-kubernetes-dashboard.yaml \
		| yq -sy 'sort_by(.kind, .metadata.name) | .[]' > test/docker-compose-kubernetes-dashboard.spec2.yaml
	diff -u test/docker-compose-kubernetes-dashboard.spec.yaml test/docker-compose-kubernetes-dashboard.spec2.yaml

	# traefik
	helm -n com-linktohack-traefik template traefik . \
		-f test/docker-compose-traefik.yaml \
		-f test/docker-compose-traefik-override.yaml \
		| yq -sy 'sort_by(.kind, .metadata.name) | .[]' > test/docker-compose-traefik.spec2.yaml
	diff -u test/docker-compose-traefik.spec.yaml test/docker-compose-traefik.spec2.yaml	