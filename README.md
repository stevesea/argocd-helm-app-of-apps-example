# Overview

This repository contains an example of a Helm chart and templates for creating an environment-specific collection of ArgoCD Application/AppProject CRDs.

## Links to things I wish I had when I began learning Kubernetes

* [Pulumi's Kubernetes the Prod Way](https://pulumi.io/quickstart/k8s-the-prod-way/index.html)A great example of how to think about your platform, and the reasoning behind splitting your deployments into groups based on Risk & Functionality.
* [Cloud Native Devops with Kubernetes (free ebook)](https://www.nginx.com/resources/library/cloud-native-devops-with-kubernetes/)
* [The State of Kubernetes Configuration Management](https://blog.argoproj.io/the-state-of-kubernetes-configuration-management-d8b06c1205) A good discussion of the pros/cons of Helm, Kustomize, etc.


## ArgoCD

[ArgoCD](https://github.com/argoproj/argo-cd) is a GitOps tool for Continuous Deployment. ArgoCD will compare the Kubernetes manifests in a git repository to the manifests it reads in your Kubernetes cluster, can synchronize those manifests from git into Kubernetes, and helps you monitor the state of your services in Kubernetes.

Kubernetes manifests can be simple manifests, but ArgoCD also supports Helm, Kustomize, ksonnet, and jsonnet.

ArgoCD is mostly stateless, you define the desired configuration of your cluster through standard Kubernetes manifests -- ConfigMaps, Secrets, and a couple Custom Resource Definitions (CRDs).

ConfigMaps & Secrets -- you configure ArgoCD itself through its ConfigMaps and Secrets. Through these, you define the git repositories, target clusters, credentials for git/cluster, and RBAC rules for ArgoCD and your projects.

AppProject CRD -- a 'project' in ArgoCD defines which git repositories should be synched to which clusters, and RBAC rules.

Application CRD -- an 'application' defines a single git source repository and a target Kubernetes cluster, and parameters to apply to the templates.

# The Problem

Similar to Kubernetes, ArgoCD doesn't enforce strong opinions about the best way for you to use it. There are recommendations and best practices... but, making the transition from "Hey, this tool is neat, I think we should use it!" to actually putting it into practice in a maintainable way requires a significant design effort.

With ArgoCD, you'll need to create an Application CRD for each set of manifests you want to deploy into your cluster(s). Or, to state the problem a different way... for a given microservice, you'll likely deploy it to many different places -- you might have test, staging, production environments. You'll need a different CRD for each different deployment. How do you manage the parameterization of that?

ArgoCD is quite new, but has an active community. An emerging pattern with ArgoCD are declarative setup and  'application of applications' -- you can use ArgoCD to manage ArgoCD itself, and you define Application CRDs that create other Application CRDs.

## This Example

This repository holds one example of how to manage one aspect of the problem, in one particular way -- a helm template that creates a bunch of Application/AppProject CRDs for the different target environments. It fit our needs, and supported the developer workflow we found convenient. Your needs may be different, and you'll likely weigh all the factors of your CD process differently than I did.


### Things not covered in this example

This example is strictly focused on the problem of generating the Application CRDs. I plan to expand it soon to deploy an actual working collection of services ... but it doesn't do that now.

* deploying ArgoCD itself.
* RBAC settings for ArgoCD or the AppProjects.
* actual working example microservice projects.
* different clusters per env -- the values files all use `https://kubernetes.default.svc` as the destination, to deploy to different clusters per env, you'd change that to the cluster IP of your target cluster.
