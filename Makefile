KIND_VERSION = 0.11.1
KUBERNETES_VERSION = 1.21.1
KUSTOMIZE_VERSION = 4.2.0

KIND := $(shell pwd)/bin/kind
KUBECTL := $(shell pwd)/bin/kubectl
KUSTOMIZE := $(shell pwd)/bin/kustomize
ARGOCD := $(shell pwd)/bin/argocd

ARGOCD_VERSION = 2.1.3
GRAFANA_OPERATOR_VERSION = 4.0.1
VM_OPERATOR_VERSION = 0.19.1
CERT_MANAGER_VERSION = 1.6.0
MEOWS_VERSION = 0.4.2
MCING_VERSION = 0.2.0
METALLB_VERSION = 0.11.0

.PHONY: start
start: $(KIND)
	$(KIND) create cluster --name=kmdkuk --config cluster-config/cluster-config.yaml

.PHONY: get-argocd-password
get-argocd-password:
	@$(KUBECTL) -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d

.PHONY: get-grafana-password
get-grafana-password:
	@$(KUBECTL) -n monitoring-system get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_USER}' | base64 -d
	@echo
	@$(KUBECTL) -n monitoring-system get secret grafana-admin-credentials -o jsonpath='{.data.GF_SECURITY_ADMIN_PASSWORD}' | base64 -d

.PHONY: setup
setup: $(KUBECTL) $(KUSTOMIZE) $(ARGOCD)
	@echo "setup argocd"
	-@$(KUBECTL) create namespace argocd
	$(KUSTOMIZE) build argocd/base/ | $(KUBECTL) apply -n argocd -f -
	$(KUBECTL) wait -n argocd deploy/argocd-server --for condition=available --timeout 3m
	sleep 10
	$(ARGOCD) login localhost:30080 --insecure --username admin --password $(shell make get-argocd-password)
	$(ARGOCD) app create argocd-config --upsert --repo https://github.com/kmdkuk/kind-cluster.git --path argocd-config/base \
				--dest-namespace argocd --dest-server https://kubernetes.default.svc --sync-policy none --revision main


.PHONY: stop
stop: $(KIND)
	$(KIND) delete cluster --name=kmdkuk

.PHONY: clean
clean:
	rm -rf bin

.PHONY: update-cert-manager
update-cert-manager:
	curl -sLf -o cert-manager/base/upstream/cert-manager.yaml \
		https://github.com/jetstack/cert-manager/releases/download/v${CERT_MANAGER_VERSION}/cert-manager.yaml

.PHONY: update-argocd
update-argocd:
	curl -sfL -o argocd/base/upstream/install.yaml https://raw.githubusercontent.com/argoproj/argo-cd/v${ARGOCD_VERSION}/manifests/install.yaml

.PHONY: update-mcing
update-mcing:
	curl -sfL -o mcing/base/upstream/install.yaml https://github.com/kmdkuk/MCing/releases/download/v${MCING_VERSION}/install.yaml

.PHONY: update-meows
update-meows:
	rm -rf /tmp/meows
	cd /tmp; git clone --depth 1 -b "v${MEOWS_VERSION}" https://github.com/cybozu-go/meows.git
	rm -rf meows/base/upstream/*
	cp -r /tmp/meows/config/* meows/base/upstream
	rm -rf /tmp/meows

.PHONY: update-metallb
update-metallb:
	rm -rf /tmp/metallb
	cd /tmp; git clone --depth 1 -b v${METALLB_VERSION} https://github.com/metallb/metallb
	rm -f metallb/base/upstream/*
	cp /tmp/metallb/manifests/*.yaml metallb/base/upstream
	rm -rf /tmp/metallb

.PHONY: update-grafana-operator
update-grafana-operator:
	rm -rf /tmp/grafana-operator
	cd /tmp; git clone --depth 1 -b v${GRAFANA_OPERATOR_VERSION} https://github.com/grafana-operator/grafana-operator.git
	rm -rf monitoring/base/grafana-operator/upstream/*
	cp -r /tmp/grafana-operator/config/* monitoring/base/grafana-operator/upstream/
	cp /tmp/grafana-operator/deploy/operator.yaml monitoring/base/grafana-operator/upstream/
	rm -rf /tmp/grafana-operator

.PHONY: update-victoriametrics-operator
update-victoriametrics-operator:
	rm -rf /tmp/operator
	cd /tmp; git clone --depth 1 -b v${VM_OPERATOR_VERSION} https://github.com/VictoriaMetrics/operator
	rm -rf monitoring/base/victoriametrics/upstream/*
	cp -r /tmp/operator/config/* monitoring/base/victoriametrics/upstream/
	rm -rf /tmp/operator

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
