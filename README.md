# Overview

This repository contains an example of a Helm chart and templates for creating an environment-specific collection of ArgoCD Application/AppProject CRDs.

## Links to things I wish I had when I began learning Kubernetes

* [Pulumi's Kubernetes the Prod Way](https://pulumi.io/quickstart/k8s-the-prod-way/index.html)A great example of how to think about your platform, and the reasoning behind splitting your deployments into groups based on Risk & Functionality.
* [Cloud Native Devops with Kubernetes (free ebook)](https://www.nginx.com/resources/library/cloud-native-devops-with-kubernetes/)
* [The State of Kubernetes Configuration Management](https://blog.argoproj.io/the-state-of-kubernetes-configuration-management-d8b06c1205) A good discussion of the pros/cons of Helm, Kustomize, etc.


## ArgoCD

[ArgoCD](https://github.com/argoproj/argo-cd) is a GitOps tool for Continuous Deployment. ArgoCD will compare the Kubernetes manifests in a git repository to the manifests it reads in your Kubernetes cluster, can synchronize those manifests from git into Kubernetes, and helps you monitor the state of your services in Kubernetes.

ArgoCD can deploy your Kubernetes manifests through most of the current popular definitions -- Helm, Kustomize, ksonnet, jsonnet, or simple k8s manifests.

ArgoCD is mostly stateless, you define the desired configuration of your cluster through standard Kubernetes manifests -- ConfigMaps, Secrets, and a couple Custom Resource Definitions (CRDs).

ConfigMaps & Secrets -- you configure ArgoCD itself through its ConfigMaps and Secrets. Through these, you define the git repositories, target clusters, credentials for git/cluster, and RBAC rules for ArgoCD and your projects.

AppProject CRD -- a 'project' in ArgoCD defines which git repositories should be synched to which clusters, and RBAC rules.

Application CRD -- an 'application' defines a single git source repository and a target Kubernetes cluster, and parameters to apply to the templates.

# Problem #1 -- Application of Applications

Similar to Kubernetes itself, ArgoCD doesn't enforce strong opinions about how you should use ArgoCD. Making the transition from "Hey, this tool is neat, I think we should use it!" to actually putting it into practice in a maintainable way requires a significant design effort.

With ArgoCD, you'll need to create an Application CRD for each set of manifests you want to deploy into your cluster(s). Or, to state the problem a different way... for a given microservice, you'll likely deploy it to many different places -- you might have test, staging, production environments. You'll need a different CRD for each different deployment. How do you manage the parameterization of that? How do you promote your application from test to staging, and from staging to production?

ArgoCD is quite new, but has an active community. Emerging patterns within the ArgoCD community are declarative setup and  'application of applications' -- you can use ArgoCD to manage ArgoCD itself, and you define Application CRDs that create other Application CRDs.


## Things not covered in this example

This example is currently only focused on the problem of generating the Application CRDs. I plan to expand it soon to deploy an actual working collection of services ... but it doesn't do that now.

* deploying ArgoCD itself.
* CI/CD build pipelines
* RBAC settings for ArgoCD or the AppProjects.
* actual working example microservice projects.
* different clusters per env -- the values files all use `https://kubernetes.default.svc` as the destination, to deploy to different clusters per env, you'd change that to the cluster IP of your target cluster.


## This Example in Context

This repository holds one example of how to manage one aspect of Continuous Deployment with ArgoCD, and in one particular way -- a helm template that creates a bunch of Application/AppProject CRDs for the different target environments. It fit our needs, and supported the developer workflow we found convenient. Your needs may be different, and you'll likely weigh all the factors of your CD process differently than I did.


### Context

We have a couple dozen microservices. An 'environment' is a cluster+namespace. For example, the 'test' environment is all of our services deployed to a 'test' namespace in a particular cluster.

#### Repositories
We split our microservice source code and the kubernetes manifests into separate repositories (go [here](https://argoproj.github.io/argo-cd/user-guide/best_practices/) for discussion of why that's useful) -- an 'application' repository and a 'deployment' repository.

Repository layout:
* platform
  * apps
    * $SVC -- the application repository
    * cd-$SVC -- the deployment repository for $SVC
  * infra
    * $SVC
    * cd-$SVC

#### Branching Strategy and CI/CD Pipeline

You have a handful of different strategies for configure ArgoCD to [track changes in your git repositories](https://argoproj.github.io/argo-cd/user-guide/tracking_strategies/). I've chosen to do branch tracking.

In my application repositories, we use github-flow like branching. Short-lived feature branches off of master for development, master should always be an a production-ready state. Occasionally, we'll have hotfix/release branches, but those should be very rare.

In my deployment repositories, I have specifically named branches for each target environment -- `test` for test env, `staging` for staging env, etc. Developers create feature branches off of `master`, and create merge requests to come back to master. The `master` branch is sync'd to development environments, but should be in a state that is ready for production.

Developers interact with the different environments via Merge Requests.

To fix a bug and deploy the fix to the 'test' environment:
* The developer makes a bugfix on a feature branch in their application repository, and creates a Merge Request to the master.
* on MR approval, the MR is merged to master.
* on merge to master, the CI pipeline is kicked off.
* the CI pipeline in the application repository does the following
  * calculates SemVer via [gitversion](https://gitversion.readthedocs.io)
  * builds the docker image and tags with SemVer
  * pushes to the docker registry, tags the application repository with the SemVer
  * runs static analysis, uploads BOM, etc
  * triggers CD pipeline in the deployment repository -- passing SemVer, image name, etc
* the CD pipeline in the deployment repository does the following
  * updates the deployment manifests for the service on the `master` branch
  * tags the deployment repository with the SemVer
  * runs validation on the manifests -- helm lint, kubeval, etc
  * if helm, packages the manifests and pushes to a helm repository.
  * merges the manifests from the `master` branch to the `test` branch
  * ArgoCD for the test environment is setup to auto-sync the manifests fromt he `test` branch into the Kubernetes cluster.

To promote a change from the `test` to `staging` environments (or `staging` to `production`):
* developer/qa creates a Merge Request in the deployment repository
* upon MR approval, the MR is merged to target branch
* ArgoCD for the target environment is setup to auto-sync the manifests from the target branch into the appropriate Kubernetes cluster.