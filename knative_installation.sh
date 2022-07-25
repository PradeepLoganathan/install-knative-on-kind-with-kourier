
#check and ensure docker version
docker version

#check and ensure kind version
kind --version

# delete kind clusters as needed
# kind delete cluster --name kind

#create kind cluster
kind create cluster --name knative-cluster --config kind-knative-cluster.yaml

#check kind cluster info
kubectl cluster-info --context kind-knative-cluster

#check if the context is pointing to the right cluster
kubectl config get-contexts

#install knative CRD's
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.0.0/serving-crds.yaml
kubectl wait --for=condition=Established --all crd

#install knative core
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.0.0/serving-core.yaml
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n knative-serving > /dev/null

#install Kourier
kubectl apply -f https://github.com/knative/net-kourier/releases/download/knative-v1.0.0/kourier.yaml
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n kourier-system
kubectl wait pod --timeout=-1s --for=condition=Ready -l '!job-name' -n knative-serving

#dns configuration

# Set the environment variable EXTERNAL_IP to External IP Address of the Worker Node
EXTERNAL_IP="127.0.0.1"

# Set the environment variable KNATIVE_DOMAIN as the DNS domain using nip.io
# nip.io provides Free wildcard DNS services for IP addresses. The nip.io service is a 
# “dead simple wildcard DNS for any IP Address”, and it allows you to map example domain names like magic.127.0.0.1.nip.io to 127.0.0.1
# easy and powerful solution for generating domain names that map to a local app or Kubernetes cluster, and you can use this domain name 
# with a public CA to avoid the need to use self-signed certificates
# check the answers section for the A record
KNATIVE_DOMAIN="$EXTERNAL_IP.nip.io"
echo KNATIVE_DOMAIN=$KNATIVE_DOMAIN
dig $KNATIVE_DOMAIN

# check the config-domain configmap
kubectl describe configmaps config-domain -n knative-serving


#Configure DNS for Knative Serving with the custom domain setup above. We are patching rather than create a new one.
kubectl patch configmap -n knative-serving config-domain -p "{\"data\": {\"$KNATIVE_DOMAIN\": \"\"}}"

#Kourier is an Ingress for Knative Serving. Kourier is a lightweight alternative for the
#Istio ingress as its deployment consists only of an Envoy proxy and a control plane for it.
#install the Kourier controller
# By default, the Kourier service is set to be of type LoadBalancer. On local machines, 
# this type doesn’t work, so you’ll have to change the type to NodePort and add nodePort
# elements to the two listed ports.

kubectl apply -f kourier.yaml

#set Kourier as the default networking layer for Knative Serving
# Configure Knative Serving to use the proper "ingress.class"

# check the config-domain configmap
kubectl describe configmaps config-network -n knative-serving

kubectl patch configmap/config-network \
  --namespace knative-serving \
  --type merge \
  --patch '{"data":{"ingress.class":"kourier.ingress.networking.knative.dev"}}'

#check pods are up and running
kubectl get pods -n knative-serving
kubectl get pods -n kourier-system
kubectl get svc  -n kourier-system

#use kn to create the service
kn service create hello \
--image gcr.io/knative-samples/helloworld-go \
--port 8080 \
--env TARGET=Knative

kubectl wait ksvc hello --all --timeout=-1s --for=condition=Ready

#get service url
SERVICE_URL=$(kubectl get ksvc hello -o jsonpath='{.status.url}')
echo $SERVICE_URL

#excercise the service
curl $SERVICE_URL

#check pods are up and running
kubectl get pod -l serving.knative.dev/service=hello

open $SERVICE_URL

kubectl get pod -l serving.knative.dev/service=hello -w

# NAME                                      READY   STATUS    RESTARTS   AGE
# hello-00001-deployment-659dfd67fb-gk74w   2/2     Running   0          53s

kubectl get pod -l serving.knative.dev/service=hello -w
# NAME                                      READY   STATUS    RESTARTS   AGE
# hello-00001-deployment-659dfd67fb-5ps9x   2/2     Running   0          90s
# hello-00001-deployment-659dfd67fb-5ps9x   2/2     Terminating   0          2m25s
# hello-00001-deployment-659dfd67fb-5ps9x   1/2     Terminating   0          2m27s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     Pending       0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     Pending       0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     ContainerCreating   0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   1/2     Running             0          1s
# hello-00001-deployment-659dfd67fb-wgnkj   2/2     Running             0          1s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m55s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m56s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m56s

# NAME                                      READY   STATUS    RESTARTS   AGE
# hello-00001-deployment-659dfd67fb-5ps9x   2/2     Running   0          90s
# hello-00001-deployment-659dfd67fb-5ps9x   2/2     Terminating   0          2m25s
# hello-00001-deployment-659dfd67fb-5ps9x   1/2     Terminating   0          2m27s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     Pending       0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     Pending       0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   0/2     ContainerCreating   0          0s
# hello-00001-deployment-659dfd67fb-wgnkj   1/2     Running             0          1s
# hello-00001-deployment-659dfd67fb-wgnkj   2/2     Running             0          1s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m55s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m56s
# hello-00001-deployment-659dfd67fb-5ps9x   0/2     Terminating         0          2m56s
# hello-00001-deployment-659dfd67fb-wgnkj   2/2     Terminating         0          88s
# hello-00001-deployment-659dfd67fb-npmr5   0/2     Pending             0          0s
# hello-00001-deployment-659dfd67fb-npmr5   0/2     Pending             0          0s
# hello-00001-deployment-659dfd67fb-npmr5   0/2     ContainerCreating   0          0s
# hello-00001-deployment-659dfd67fb-npmr5   1/2     Running             0          2s
# hello-00001-deployment-659dfd67fb-npmr5   2/2     Running             0          2s
# hello-00001-deployment-659dfd67fb-wgnkj   1/2     Terminating         0          90s

# cleanup cluster
kind delete cluster --name knative-cluster