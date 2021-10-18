.PHONY: all
all:
	helm package .
	helm repo index .

.PHONY: test
test:
	helm -n com-linktohack-redmine template redmine . -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
		--set services.db.expose={3306:3306} \
		--set services.db.ports={3306:3306} \
		--set services.db.deploy.placement.constraints={node.role==manager} \
		--set services.redmine.deploy.placement.constraints={node.role==manager} \
		--set chdir=/stack | yq -sy 'sort_by(.kind, .metadata.name) | .[]' > stack2.yaml
	cmp stack1.yaml stack2.yaml

.PHONY: diff
diff:
	helm -n com-linktohack-redmine template redmine . -f docker-compose-redmine.yaml -f docker-compose-redmine-override.yaml \
		--set services.db.expose={3306:3306} \
		--set services.db.ports={3306:3306} \
		--set services.db.deploy.placement.constraints={node.role==manager} \
		--set services.redmine.deploy.placement.constraints={node.role==manager} \
		--set chdir=/stack | yq -sy 'sort_by(.kind, .metadata.name) | .[]' > stack2.yaml
	diff -u stack1.yaml stack2.yaml
