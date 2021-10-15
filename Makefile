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
	@echo "login password"
	@$(KUBECTL) -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

.PHONY: arogocd-port
argocd-port: get-argocd-password
	@echo
	$(KUBECTL) port-forward svc/argocd-server -n argocd 8080:443

.PHONY: setup
setup: $(KUBECTL) $(KUSTOMIZE)
	echo "setup argocd"
	-@$(KUBECTL) create namespace argocd
	$(KUSTOMIZE) build argocd/base/ | $(KUBECTL) apply -n argocd -f -


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
	curl -sfL -o $@ https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
