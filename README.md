# michaels-cal-container

Container image and Kubernetes manifests for
[foxfirecodes/michaels-cal](https://github.com/foxfirecodes/michaels-cal), which
logs in to the Michaels employee portal and turns your schedule into an ICS
calendar.

The container refreshes the calendar every `REFRESH_INTERVAL` seconds (default
6 h) and serves only `/michaels-cal.ics` on port 8080. The script's other
output (HTML, JSON) contains personal data and is never served.

## Build

The Containerfile builds from the upstream repo as its context:

```bash
git clone https://github.com/foxfirecodes/michaels-cal && cd michaels-cal
docker build -f /path/to/Containerfile -t ghcr.io/<owner>/michaels-cal:latest .
```

The `build-image` GitHub Action does this and pushes to ghcr.io.

## Deploy

1. Set the image in `k8s/deployment.yaml` and the host in `k8s/ingress.yaml`.
2. Put your own address/timezone in `k8s/configmap.yaml`.
3. Create the credentials secret (do not commit real values):
   ```bash
   kubectl create namespace michaels-cal
   kubectl -n michaels-cal create secret generic michaels-cal \
     --from-literal=MICHAELS_USER=... --from-literal=MICHAELS_PASS=...
   ```
   and remove `secret.yaml` from `k8s/kustomization.yaml`.
4. If the ghcr package is private, create a pull secret and uncomment
   `imagePullSecrets` in the Deployment:
   ```bash
   kubectl -n michaels-cal create secret docker-registry ghcr \
     --docker-server=ghcr.io --docker-username=<user> --docker-password=<PAT with read:packages>
   ```
5. `kubectl apply -k k8s`

The calendar exposes your shift schedule and has no authentication. Add auth at
the ingress or use an unguessable path if it is reachable from the internet.
