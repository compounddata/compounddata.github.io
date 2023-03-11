---
title: "A self hosted container registery on k3s"
date: 2022-08-07T14:49:26+10:00
draft: true
notes: |
  # 20220807 
  there is alot of yak shaving here. To run a docker registery you
  need to expose the TLS key and certificate to the Pod. To do this, it's best
  to run cert-manager to manage certificates. But cert-manager will not expose
  the Certificate TLS key which is a Secret outside of kube-system. There are
  ways to replicate Secrets to other namespaces, with
  https://github.com/mittwald/kubernetes-replicator looking to be the best
  solution. cert-manager provides a doc on how this is all done at
  https://cert-manager.io/docs/faq/sync-secrets/#syncing-arbitrary-secrets-across-namespaces-using-extensions
---

This tutorial uses [cert-manager](https://cert-manager.io) to manage the TLS certificates that the docker registery uses. docker registery works best when it has access to the TLS certificate and key.

Initialize a `kustomization.yaml`:
```shell
$ kustomize init
```

Create a `PersistentVolume` within `persistentvolume.yaml` using the k3s Local Storage Provider:
```shell
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: container-registry-pv
spec:
  storageClassName: local-path
  capacity:
    storage: 2Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /var/lib/container-registry
```
 - `spec.capacity.storage` is the size of 
 - `spec.hostPath.path` is the path on the host where containers within the registery will be stored. 

Append a `PersistentVolumeClaim` to `persistentvolume.yaml`:
```shell
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: container-registry-pvc
  namespace: kube-system
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
 ```
  - `spec.resources.requests.storage` has to match the `spec.capacity.storage` set within the `PersistentVolume`.

Create `Service` within `service.yaml`:
```shell
---
apiVersion: v1
kind: Service
metadata:
  name: container-registry
  namespace: kube-system
spec:
  type: LoadBalancer
  selector:
    app: container-registry
  ports:
  - protocol: TCP
    port: 8050
    targetPort: 5000
```

Create a `Deployment` within `deployment.yaml`:
```shell
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: container-registry
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: container-registry
  replicas: 1
  template:
    metadata:
      labels:
        app: container-registry
    spec:
      containers:
      - name: container-registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: container-storage-filesystem
          mountPath: "/container-registry"
        - name: certs-vol
          mountPath: "/certs"
          readOnly: true
        env:
        - name: REGISTRY_HTTP_TLS_CERTIFICATE
          value: "/certs/tls.crt"
        - name: REGISTRY_HTTP_TLS_KEY
          value: "/certs/tls.key"
      volumes:
      - name: container-storage-filesystem
        persistentVolumeClaim:
          claimName: container-registry-pvc
      - name: certs-vol
        secret:
          secretName: wildcard-compounddata-com-tls
```
