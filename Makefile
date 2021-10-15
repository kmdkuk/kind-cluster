KIND_VERSION = 0.11.1
KUBERNETES_VERSION = 1.21.1
KUSTOMIZE_VERSION = 4.2.0

KIND := $(shell pwd)/bin/kind
KUBECTL := $(shell pwd)/bin/kubectl
KUSTOMIZE := $(shell pwd)/bin/kustomize
ARGOCD := $(shell pwd)/bin/argocd

ARGOCD_VERSION = 2.1.3

.PHONY: start
start: $(KIND)
	$(KIND) create cluster --name=kmdkuk --config cluster-config/cluster-config.yaml

.PHONY: get-argocd-password
get-argocd-password:
	@$(KUBECTL) -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

.PHONY: setup
setup: $(KUBECTL) $(KUSTOMIZE) $(ARGOCD)
	@echo "setup argocd"
	-@$(KUBECTL) create namespace argocd
	$(KUSTOMIZE) build argocd/base/ | $(KUBECTL) apply -n argocd -f -
	$(KUBECTL) wait -n argocd deploy/argocd-server --for condition=available --timeout 3m
	$(ARGOCD) login localhost:30080 --insecure --username admin --password $(shell make get-argocd-password)
	$(ARGOCD) app create argocd-config --upsert --repo https://github.com/kmdkuk/kind-cluster.git --path argocd-config/base \
				--dest-namespace argocd --dest-server https://kubernetes.default.svc --sync-policy none --revision main


.PHONY: stop
stop: $(KIND)
	$(KIND) delete cluster --name=kmdkuk

.PHONY: clean
clean:
	rm -rf bin

.PHONY: update-argocd
update-argocd:
	curl -sfL -o argocd/base/upstream/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

$(KIND):
	mkdir -p bin
	curl -sfL -o $@ https://github.com/kubernetes-sigs/kind/releases/download/v$(KIND_VERSION)/kind-linux-amd64
	chmod a+x $@

$(KUBECTL):
	mkdir -p bin
	curl -sfL -o $@ https://dl.k8s.io/release/v$(KUBERNETES_VERSION)/bin/linux/amd64/kubectl
	chmod a+x $@

$(KUSTOMIZE):
	mkdir -p bin
	wget -O bin/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v$(KUSTOMIZE_VERSION)_linux_amd64.tar.gz
	tar zxf bin/kustomize.tar.gz -C bin
	rm bin/kustomize.tar.gz

$(ARGOCD):
	mkdir -p bin
	curl -sfL -o $@ https://github.com/argoproj/argo-cd/releases/download/v${ARGOCD_VERSION}/argocd-linux-amd64
	chmod a+x $@
