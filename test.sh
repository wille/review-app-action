#!/bin/bash

export GITHUB_EVENT_NAME=pull_request
export GITHUB_EVENT_PATH=fixtures/opened.json

export INPUT_IMAGE=nginx:1.18
export INPUT_WEBHOOK_SECRET=secret
export INPUT_WEBHOOK_URL=http://localhost:8080
export INPUT_REVIEW_APP_NAME=reviewapp-sample
export INPUT_REVIEW_APP_NAMESPACE=default
export INPUT_ACTION=deploy

./entrypoint.sh