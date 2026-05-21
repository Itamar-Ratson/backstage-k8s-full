.PHONY: smoke tf-check charts-lint charts-test rbac-test rbac-admin-auth-test

KUBE_CONTEXT := kind-backstage
GATEWAY_NS := gateway
BACKSTAGE_NS := backstage

tf-check:
	terraform -chdir=terraform fmt -check -recursive
	terraform -chdir=terraform init -backend=false -input=false
	terraform -chdir=terraform validate

charts-lint:
	./tests/charts/test-actionlint.sh
	./tests/charts/test-templates-registered.sh
	helm lint charts/edge-gateway -f deploy/dev/edge-gateway.yaml
	helm lint charts/backstage -f deploy/dev/backstage.yaml

charts-test:
	./tests/charts/test-backstage-image.sh
	./tests/charts/test-backstage-secrets.sh
	./tests/charts/test-backstage-oauth.sh
	./tests/charts/test-backstage-configmap.sh
	./tests/charts/test-backstage-catalog-config.sh
	./tests/charts/test-backstage-mkdocs-image-toolchain.sh
	./tests/charts/test-backstage-techdocs-config.sh
	./tests/charts/test-backstage-kubernetes-label.sh
	./tests/charts/test-backstage-rbac.sh
	./tests/charts/test-edge-gateway-kubernetes-label.sh
	./tests/charts/test-helm-chart-techdocs-scaffold.sh
	./tests/charts/test-helm-chart-kubernetes-scaffold.sh
	./tests/charts/test-ci-cd-pipeline-scaffold.sh

rbac-test:
	./tests/rbac/test-rbac-policies-csv.sh

rbac-admin-auth-test:
	./tests/rbac/test-github-admin-auth-config.sh

smoke: tf-check charts-lint charts-test
	terraform -chdir=terraform apply -auto-approve
	helm upgrade --install edge-gateway charts/edge-gateway \
		--namespace $(GATEWAY_NS) --create-namespace --wait \
		--kube-context $(KUBE_CONTEXT) \
		-f deploy/dev/edge-gateway.yaml
	kubectl create namespace $(BACKSTAGE_NS) --dry-run=client -o yaml | kubectl apply -f - --context $(KUBE_CONTEXT)
	kubectl label namespace $(BACKSTAGE_NS) gateway-routes=enabled --overwrite --context $(KUBE_CONTEXT)
	@echo "Checking for backstage-github-token secret..."
	@kubectl get secret backstage-github-token -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT) >/dev/null 2>&1 || \
		(echo "ERROR: Secret backstage-github-token not found in namespace $(BACKSTAGE_NS)." && \
		 echo "Create it with:" && \
		 echo '  kubectl create secret generic backstage-github-token --from-literal=GITHUB_TOKEN="$$GITHUB_TOKEN" -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT)' && \
		 exit 1)
	@echo "Checking for backstage-github-oauth secret..."
	@kubectl get secret backstage-github-oauth -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT) >/dev/null 2>&1 || \
		(echo "ERROR: Secret backstage-github-oauth not found in namespace $(BACKSTAGE_NS)." && \
		 echo "Create it with:" && \
		 echo '  kubectl create secret generic backstage-github-oauth --from-literal=AUTH_GITHUB_CLIENT_ID="..." --from-literal=AUTH_GITHUB_CLIENT_SECRET="..." -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT)' && \
		 exit 1)
	helm upgrade --install backstage charts/backstage \
		--namespace $(BACKSTAGE_NS) --wait --timeout 5m \
		--kube-context $(KUBE_CONTEXT) \
		-f deploy/dev/backstage.yaml \
		--set-file rbac.policies=backstage/rbac-policies.csv \
		--set-file rbac.users=users.yaml
	kubectl wait --for=condition=Available deployment/backstage \
		-n $(BACKSTAGE_NS) --timeout=300s --context $(KUBE_CONTEXT)
	@echo "Verifying Backstage is reachable..."
	curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors http://backstage.localtest.me:8080 | grep -q '<title>'
	@echo "Smoke test passed."
