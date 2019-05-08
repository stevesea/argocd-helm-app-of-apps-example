# Overview

This repository contains an example of a Helm chart and templates for creating an environment-specific collection of Argo CD Application/AppProject CRDs.

## Links to information I wish I knew when I began learning Kubernetes

* [Pulumi's Kubernetes the Prod Way](https://pulumi.io/quickstart/k8s-the-prod-way/index.html)

  A great example of how to think about your platform, and the reasoning behind splitting your deployments into groups based on Risk & Functionality.
* [Cloud Native Devops with Kubernetes (free ebook)](https://www.nginx.com/resources/library/cloud-native-devops-with-kubernetes/)

  I really like how this is presents the information -- lots of k8s resources focus on 'how', but this covers the 'why' and puts it into context well.

* [The State of Kubernetes Configuration Management](https://blog.argoproj.io/the-state-of-kubernetes-configuration-management-d8b06c1205)

  A good discussion of the pros/cons of Helm, Kustomize, etc.


## Argo CD

[Argo CD](https://github.com/argoproj/argo-cd) is a GitOps tool for Continuous Deployment. Argo CD will compare the Kubernetes manifests in a git repository to the manifests it reads in your Kubernetes cluster, can synchronize those manifests from git into Kubernetes, and helps you monitor the state of your services in Kubernetes.

Argo CD can deploy your Kubernetes manifests using any of the usual methods -- Helm, Kustomize, ksonnet, jsonnet, or simple k8s manifests. I really like this aspect of Argo CD. It gives you the freedom to use whichever tool is right for the job at hand -- for simple things, just use manifests; to reduce boilerplate, use kustomize; for tasks that require the complexity of templates (e.g. loops, if/else, lots of params), use helm or jsonnet.

Argo CD is mostly stateless, you define the desired configuration of your cluster through Kubernetes manifests -- [ConfigMaps, Secrets, and a couple Custom Resource Definitions (CRDs)](https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/).

ConfigMaps & Secrets -- you configure Argo CD itself through its ConfigMaps and Secrets. Through these, you define the git repositories, target clusters, credentials for git/cluster, and RBAC rules for Argo CD and your projects.

[AppProject CRD](https://argoproj.github.io/argo-cd/operator-manual/project.yaml) -- a 'project' in Argo CD defines which git repositories should be synched to which clusters, and RBAC rules.

[Application CRD](https://argoproj.github.io/argo-cd/operator-manual/application.yaml) -- an 'application' defines a single git source repository and a target Kubernetes cluster, and parameters to apply to the templates.

# Problem #1 -- Application of Applications

Similar to Kubernetes itself, Argo CD doesn't enforce strong opinions about how you should use Argo CD. And also similar to Kubernetes, making the transition from "Hey, this tool is neat, I think we should use it!" to actually putting it into practice in a maintainable way requires a significant amount of complex decisions.

With Argo CD, you'll need to create an Application CRD for each set of manifests you want to deploy into your cluster(s). Or, to state the problem a different way... for a given microservice, you'll likely deploy it to many different places -- you might have test, staging, production environments. You'll need a different CRD for each different deployment. How do you manage the parameterization of `N` Applications across `M` environments? How do you promote your application from test to staging, and from staging to production? How does your CI/CD process fit into all this?

Argo CD is quite new (just like everything else Kubernetes-related), but has an active community. Emerging patterns within the community are [declarative setup](https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/) and ['application of applications'](https://argoproj.github.io/argo-cd/operator-manual/cluster-bootstrapping/) -- you use Argo CD to manage Argo CD itself, and you define Application CRDs that create other Application CRDs.


## Things not covered in this example

This example is currently only focused on the problem of generating the Application CRDs. I plan to expand it to cover bootstrapping an Argo CD cluster, and to deploy an actual working collection of services ... but it doesn't do that now.

Other critical details you'll need to figure out to use Argo CD, but which aren't covered by this example:
* deploying Argo CD itself.
* CI/CD pipelines
* RBAC settings for Argo CD or the AppProjects.
* actual working example microservice projects and build pipelines for same.
* different clusters per env -- the values files all use `https://kubernetes.default.svc` as the destination (this is the local cluster that Argo CD is running within), to deploy to different clusters per env, you'd change that to the cluster IP of your target cluster.


## The Context of this Example

This repository holds one example of how to manage a single aspect of Continuous Deployment with Argo CD, and in one particular way -- a helm template that creates a bunch of Application/AppProject CRDs for the different target environments. It fit my needs, and supported the developer workflow I found convenient. Your needs will be different, and you'll likely weigh the factors of your CD process differently than I did.

We have a couple dozen microservices. An 'environment' is a cluster+namespace to which our services have been deployed. For example, the 'test' environment is all of our services deployed to a 'test' namespace in a particular cluster.

### Repositories
We split our microservice source code and the kubernetes manifests into two separate repositories (go [here](https://argoproj.github.io/argo-cd/user-guide/best_practices/) for discussion of why that's useful) -- an 'application' repository and a 'deployment' repository.

Some things may only have 'deployment' repositories -- 3rd party applications, k8s manifests that are useful to combine into a logical group, etc.

Example repository layout:
* platform/
  * apps/
    * auth/ -- auth-related application & deployment repos
      * $SVC -- the application repository
      * cd-$SVC -- the deployment repository for $SVC
    * onboarding/ -- user onboarding related application and deployment repos
      * $SVC -- the application repository
      * cd-$SVC -- the deployment repository for $SVC
  * infra/
    * utils/ -- general utilities (Storage class config, service-discovery helpers, logging & monitoring related things, etc)
      * $SVC
      * cd-$SVC
    * identity/ -- identity-related stuff in a subgroup to help isolate RBAC rules for it
      * service-accounts/ -- manifests for creating the k8s service accounts

### Branching Strategy and CI/CD Pipeline

There are a handful of different strategies for configuring Argo CD to [track changes in your git repositories](https://argoproj.github.io/argo-cd/user-guide/tracking_strategies/). I've chosen to do branch tracking.

In my application repositories, I use github-flow like branching. The `master` branch should always be in a production-ready state. Short-lived feature branches are created off of `master` for new features and bugfixes. Occasionally, we'll have hotfix/release branches -- those are very rare, but sometimes necessary.

In my deployment repositories, I have specifically named branches for each target environment. The `master` branch should always be kept production-ready. An Argo CD deployment syncs the `master` branch to developer environments. A 'nonprod' Argo CD deployment syncs `test` branch to test cluster and `staging` branch to the staging cluster. A 'prod' Argo CD deployment syncs `production` branch to the production cluster. When Developers/QA are ready to push their changes to a wider audience, they create merge requests from master to the target environment's branch.

Developers interact with the different environments via git through Merge Requests. Through SSO, they'll be granted read-only access to Argo CD to monitor the target environments.

To fix a bug and deploy the fix to the 'test' environment:
* The developer makes a bugfix on a feature branch in their application repository, and creates a Merge Request to master.
* on MR approval, the MR is merged to master.
* on merge to master, the CI pipeline is kicked off.
  * the CI pipeline in the application repository does the following
    * calculates SemVer via [gitversion](https://gitversion.readthedocs.io)
    * builds the docker image and tags with SemVer
    * pushes to the docker registry
    * tags the application repository with the SemVer
    * runs static analysis, uploads BOM, etc
    * triggers CD pipeline in the deployment repository -- passing SemVer, image name, etc
  * the CD pipeline in the deployment repository does the following
    * updates the deployment manifests for the service on the `master` branch
    * tags the deployment repository with the SemVer
    * runs validation on the manifests -- helm lint, kubeval, etc
    * if helm, packages the manifests and pushes to a helm repository.
    * merges the manifests from the `master` branch to the `test` branch
    * Argo CD for the test environment is setup to auto-sync the manifests fromt he `test` branch into the Kubernetes cluster.

To promote a change from the `test` to `staging` environments (or `staging` to `production`):
* developer/qa creates a Merge Request in the deployment repository from source to target branch
* upon MR approval (qa and business stake holders are mandatory approvers), the MR is merged to target branch
* Argo CD for the target environment is setup to auto-sync the manifests from the target branch into the appropriate Kubernetes cluster.

## Finally, the example itself...

In this repository, there are two Helm charts. The Helm charts have two templates -- one that creates AppProjects and another that creates Applications.

The templates are driven by the maps in the values.yaml files -- they contains a map of projects, and a map of applications. In each chart, there are values overrides for each environment.

- __argocd-helm-app-of-apps-example__
  - __argocd-example-infra__
    - __templates__
      - [applications.yaml](argocd-example-infra/templates/applications.yaml)
      - [projects.yaml](argocd-example-infra/templates/projects.yaml)
    - [Chart.yaml](argocd-example-infra/Chart.yaml)
    - [production-values.yaml](argocd-example-infra/production-values.yaml)
    - [staging-values.yaml](argocd-example-infra/staging-values.yaml)
    - [test-values.yaml](argocd-example-infra/test-values.yaml)
    - [values.yaml](argocd-example-infra/values.yaml)
  - __argocd-example-apps__
    - __templates__
      - [applications.yaml](argocd-example-apps/templates/applications.yaml)
      - [projects.yaml](argocd-example-apps/templates/projects.yaml)
    - [Chart.yaml](argocd-example-apps/Chart.yaml)
    - [staging-values.yaml](argocd-example-apps/staging-values.yaml)
    - [production-values.yaml](argocd-example-apps/production-values.yaml)
    - [test-values.yaml](argocd-example-apps/test-values.yaml)
    - [values.yaml](argocd-example-apps/values.yaml)

To make use of these charts, I create a set of Argo CD Application CRDs. For example, with my argocd-test deployment, I'd deploy the following CRDs into my argocd namespace:

```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: argocd
spec:
  description: project for management of Argo CD itself
  # some of my apps within argocd project need to create cluster resources
  clusterResourceWhitelist:
  - group: '*'
    kind: '*'
  destinations:
  - namespace: argocd
    server: https://kubernetes.default.svc
  sourceRepos:
  - https://github.com/stevesea/argocd-helm-app-of-apps-example.git
  #
  # lots of other repos here
  #
  - https://github.com/helm/charts.git
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-apps
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: argocd
  syncPolicy:
    automated:
      prune: true
  source:
    path: argocd-example-apps
    repoURL: https://github.com/stevesea/argocd-helm-app-of-apps-example.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-infra
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: argocd
  syncPolicy:
    automated:
      prune: true
  source:
    path: argocd-example-infra
    repoURL: https://github.com/stevesea/argocd-helm-app-of-apps-example.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml
```

The above Application CRDs use helm to generate the 'test' Application CRDs and deploy them to the `argocd` namespace. To see what what those manifests look like, run `helm template argocd-example-apps -f argocd-example-apps/test-values.yaml`

You'll get this output:

```yaml
---
# Source: argocd-example-apps/templates/projects.yaml

---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: test-auth
spec:
  description: auth services -- api gateway, auth
  sourceRepos:
    - https://MY_APPS_REPOSITORY/auth/*

  destinations:
    - namespace: test
      server: https://kubernetes.default.svc

---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: test-onboarding
spec:
  description: onboarding services -- user PII, etc
  sourceRepos:
    - https://MY_APPS_REPOSITORY/onboarding/*

  destinations:
    - namespace: test
      server: https://kubernetes.default.svc



---
# Source: argocd-example-apps/templates/applications.yaml

---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-api-gateway
spec:
  destination:
    namespace: test
    server: https://kubernetes.default.svc
  project: test-auth
  syncPolicy:
    automated:
      prune: true
  source:
    path: api-gateway
    repoURL: https://MY_APPS_REPOSITORY/auth/cd-api-gateway.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml

---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-auth-service
spec:
  destination:
    namespace: test
    server: https://kubernetes.default.svc
  project: test-auth
  syncPolicy:
    automated:
      prune: true
  source:
    path: auth-service
    repoURL: https://MY_APPS_REPOSITORY/auth/cd-auth-service.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml

---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-mailqueue
spec:
  destination:
    namespace: test
    server: https://kubernetes.default.svc
  project: test-onboarding
  syncPolicy:
    automated:
      prune: true
  source:
    path: mailqueue
    repoURL: https://MY_APPS_REPOSITORY/auth/cd-mailqueue.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml

---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-pdf-service
spec:
  destination:
    namespace: test
    server: https://kubernetes.default.svc
  project: test-onboarding
  syncPolicy:
    automated:
      prune: true
  source:
    path: pdf-service
    repoURL: https://MY_APPS_REPOSITORY/onboarding/cd-pdf-service.git
    targetRevision: test
    helm:
      valueFiles:
      - test-values.yaml

  ignoreDifferences:
  - group: apps
    kind: Deployment
    jsonPointers:
    - /spec/replicas


```