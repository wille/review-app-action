#!/bin/bash

[[ "$GITHUB_EVENT_NAME" != "pull_request" ]] && echo "Only 'pull_request' workflows are supported" && exit 1
[[ -z "$GITHUB_EVENT_PATH" ]] && echo "Missing GITHUB_EVENT_PATH" && exit 1
[[ -z "$INPUT_WEBHOOK_SECRET" ]] && echo "Missing INPUT_WEBHOOK_SECRET" && exit 1
[[ -z "$INPUT_WEBHOOK_URL" ]] && echo "Missing INPUT_WEBHOOK_URL" && exit 1
[[ -z "$INPUT_REVIEW_APP_NAME" ]] && echo "Missing INPUT_REVIEW_APP_NAME" && exit 1
[[ -z "$INPUT_ACTION" ]] && echo "Missing INPUT_ACTION" && exit 1

github_event_data=$(cat "$GITHUB_EVENT_PATH")

event_field() {
    echo "$github_event_data" | jq -r "$1"
}

webhook_data=$(cat <<EOF | jq
{
    "reviewAppName": "$INPUT_REVIEW_APP_NAME",
    "reviewAppNamespace": "$INPUT_REVIEW_APP_NAMESPACE",
    "repositoryUrl": "$(event_field .repository.html_url)",
    "branchName": "$(event_field .pull_request.head.ref)",
    "pullRequestUrl": "$(event_field .pull_request.html_url)",
    "image": "$INPUT_IMAGE",
    "merged": $(event_field .pull_request.merged),
    "sender": "$(event_field .sender.html_url)"
}
EOF
)

WEBHOOK_SIGNATURE_256=$(echo -n "$webhook_data" | \
    openssl dgst -sha256 -hmac "$INPUT_WEBHOOK_SECRET" -binary | \
    xxd -p | \
    tr -d '\n'
)

if [ "$INPUT_DEBUG" = true ]; then
    echo "Webhook data: $webhook_data"
    echo "Webhook signature: $WEBHOOK_SIGNATURE_256"
fi

case $INPUT_ACTION in
    "deploy")
        [[ -z "$INPUT_IMAGE" ]] && echo "Missing INPUT_IMAGE" && exit 1
        curl --fail-with-body \
            -H "Content-Type: application/json" \
            -H "User-Agent: github-deployment-action" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -X POST \
            --data "$webhook_data" "$INPUT_WEBHOOK_URL/v1"
        ;;
    "close")
        curl --fail-with-body \
            -H "Content-Type: application/json" \
            -H "User-Agent: github-deployment-action" \
            -H "X-Hub-Signature-256: sha256=$WEBHOOK_SIGNATURE_256" \
            -X DELETE \
            --data "$webhook_data" "$INPUT_WEBHOOK_URL/v1"
        ;;
    *)
        echo "Invalid action: $INPUT_ACTION"
        exit 1
        ;;
esac

curl_status=$?
exit $curl_status
