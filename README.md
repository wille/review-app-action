[![GitHub release](https://img.shields.io/github/release/wille/review-app-action.svg?style=flat-square)](https://github.com/wille/review-app-action/releases/latest)

# Review App Action

A Github Action to be used with [Review App Operator](https://github.com/wille/review-app-operator) to create staging/preview environments for pull requests.

Prerequisites:
- A Kubernetes cluster with Review App Operator installed and configured correctly
- A `ReviewApp` resource in the cluster
- Docker registry to push images from your workflow to your cluster pull and run

## Usage

Below is an example workflow to build, push and deploy a Docker image to a Kubernetes cluster using the Review App Operator.

## Workflow to create a review app for a pull request


### `.github/workflows/pull_request.yml`

```yaml
name: Pull Request

on:
  pull_request:
    types:
      - opened
      - synchronize
      - reopened

concurrency:
  group: review-app-${{ github.head_ref }}
  cancel-in-progress: false

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@692973e3d937129bcbf40652eb9f2f61becf3332 # 4.1.7

      # Create a pending deployment on the Pull Request page
      - name: Create Github deployment
        uses: bobheadxi/deployments@88ce5600046c82542f8246ac287d0a53c461bca3
        id: create_deployment
        with:
          step: start
          token: ${{ secrets.GITHUB_TOKEN }}
          env: ${{ github.head_ref }}
          ref: ${{ github.head_ref }}

      - name: Login to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.REGISTRY_USER }}
          password: ${{ secrets.REGISTRY_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          push: true
          # Tags the new image with the commit hash and the branch name
          tags: |
            user/app:${{ github.event.pull_request.head.sha }}

      - name: Deploy
        id: deploy
        uses: wille/review-app-action@master
        with:
          review_app_name: my-reviewapp
          review_app_namespace: staging
          webhook_url: https://review-app-operator-webhooks.example.com
          webhook_secret: ${{ secrets.REVIEW_APP_WEBHOOK_SECRET }}
          image: user/app:${{ github.event.pull_request.head.sha }}@sha256:${{ steps.build.outputs.digest }}

      # Update the pending deployment on the Pull Request page
      - name: Update deployment status
        uses: bobheadxi/deployments@88ce5600046c82542f8246ac287d0a53c461bca3
        if: always()
        with:
          step: finish
          token: ${{ secrets.GITHUB_TOKEN }}
          status: ${{ job.status }}
          env: ${{ github.head_ref }}
          ref: ${{ github.head_ref }}
          deployment_id: ${{ steps.create_deployment.outputs.deployment_id }}
          env_url: ${{ steps.deploy.outputs.review_app_url }}
```


> [!NOTE]  
> This action is not supported in `push` workflows. Review App Operator is designed to only target pull requests and not branches.

> [!NOTE]
> The `review_app_name` and `review_app_namespace` must match the `metadata.name` and `metadata.namespace` of the `ReviewApp` resource in Kubernetes.


## Workflow to tear down the review app environment when the pull request is closed
### `.github/workflows/close_pull_request.yml`

```yaml
name: Close Pull Request
on:
  pull_request:
    types:
      - closed
concurrency:
  group: review-app-${{ github.head_ref }}
  cancel-in-progress: true

jobs:
  cleanup:
    name: Cleanup review app environment
    runs-on: ubuntu-latest
    steps:
      - name: Close review app
        uses: wille/review-app-operator-action@master
        continue-on-error: true
        with:
          review_app_name: my-reviewapp
          review_app_namespace: staging
          webhook_url: https://review-app-operator-webhooks.example.com
          webhook_secret: ${{ secrets.REVIEW_APP_OPERATOR_WEBHOOK_SECRET }}

      - name: Destroy Github environment
        uses: bobheadxi/deployments@88ce5600046c82542f8246ac287d0a53c461bca3
        with:
          step: deactivate-env
          token: ${{ secrets.GITHUB_TOKEN }}
          env: ${{ github.head_ref }}
          desc: Pull request closed
```

# Inputs

| Name | Type | Description |
|------|-------------|----------|
| `review_app_name` | string | Name of the `ReviewApp` resource in Kubernetes (required) |
| `review_app_namespace` | string | Namespace where the `ReviewApp` is deployed in Kubernetes (required) |
| `webhook_url` | string | URL to the Review App Operator webhook (required) |
| `webhook_secret` | string | Secret to authenticate the webhook (required) |
| `image` | string | Image to deploy |

# Outputs

| Name | Type | Description |
|------|-------------|----------|
| `review_app_url` | string | URL to the deployed review app. A review app may have more than one URL, only the first one will be set |