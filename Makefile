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
	./tests/charts/test-chart-layout.sh
	helm lint charts/platform/edge-gateway -f deploy/dev/edge-gateway.yaml
	helm lint charts/workloads/backstage -f deploy/dev/backstage.yaml

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
	helm upgrade --install edge-gateway charts/platform/edge-gateway \
		--namespace $(GATEWAY_NS) --create-namespace --wait \
		--kube-context $(KUBE_CONTEXT) \
		-f deploy/dev/edge-gateway.yaml
	kubectl create namespace $(BACKSTAGE_NS) --dry-run=client -o yaml | kubectl apply -f - --context $(KUBE_CONTEXT)
	kubectl label namespace $(BACKSTAGE_NS) gateway-routes=enabled --overwrite --context $(KUBE_CONTEXT)
	@echo "Checking for backstage-github-app secret..."
	@kubectl get secret backstage-github-app -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT) >/dev/null 2>&1 || \
		(echo "ERROR: Secret backstage-github-app not found in namespace $(BACKSTAGE_NS)." && \
		 echo "Create it with:" && \
		 echo '  kubectl create secret generic backstage-github-app --from-literal=APP_ID="..." --from-literal=CLIENT_ID="..." --from-literal=CLIENT_SECRET="..." --from-file=PRIVATE_KEY=path/to/private-key.pem -n $(BACKSTAGE_NS) --context $(KUBE_CONTEXT)' && \
		 exit 1)
	helm upgrade --install backstage charts/workloads/backstage \
		--namespace $(BACKSTAGE_NS) --wait --timeout 5m \
		--kube-context $(KUBE_CONTEXT) \
		-f deploy/dev/backstage.yaml
	kubectl wait --for=condition=Available deployment/backstage \
		-n $(BACKSTAGE_NS) --timeout=300s --context $(KUBE_CONTEXT)
	@echo "Verifying Backstage is reachable..."
	curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors http://backstage.localtest.me:8080 | grep -q '<title>'
	@echo "Smoke test passed."
