#!/usr/bin/env bash

set -e

. /functions.sh

awsAccessId="$1"
awsSecretKey="$2"
awsRegion="$3"
awsEcrRegistry="$4"
imageRepo="$5"
imageTag="$6"
preBuildCmd="$7"
buildDockerfile="${8:-Dockerfile}"
buildDockerArgs="$9"
buildCache="${10}"
updateCache="${11:-false}"
cacheRegistry="${12}"
cacheRegistryUsername="${13}"
cacheRegistryPassword="${14}"

run_validations() {
    if [[ -z "$awsAccessId" ]] || [[ -z "$awsSecretKey" ]]; then
        error "Provide AWS credentials"
        return 2
    fi
    if [[ -z "$imageRepo" ]] || [[ -z "$imageTag" ]]; then
        error "Provide image repository and tag to build"
        return 2
    fi
    if [[ "$updateCache" = true ]]; then
        if [[ -z "$cacheRegistry" ]] || [[ -z "$cacheRegistryUsername" ]] || [[ -z "$cacheRegistryPassword" ]]; then
            error "Provide cache registry login credentials"
            return 2
        fi
    fi
}

run_validations
valid_code=$?

if [[ $valid_code != 0 ]]; then
    error "Validations failed (exit code $valid_code)"
    exit 1
fi

# configure AWS for provided key
aws configure >/dev/null << EOF
$awsAccessId
$awsSecretKey
$awsRegion


EOF
info "Configured AWS CLI"

info "Checking current AWS identity..."
aws sts get-caller-identity

# config)ure docker login access to ECR registry
cmdEcrLogin="aws ecr get-login --no-include-email" 
if [[ -n "$awsEcrRegistry" ]]; then
    cmdEcrLogin+=" --registry-ids $awsEcrRegistry"
fi
dockerCreds="$($cmdEcrLogin)" || ( \
    error "The given user doesn't have access to ECR resource"; \
    exit 2;
)
eval "$dockerCreds"
awsEcrRegistry=${awsEcrRegistry:-$(aws ecr get-authorization-token | jq -r ".authorizationData[0].proxyEndpoint" | sed -e "s|^https\?://||")}
info "Logged in to AWS registry, "$awsEcrRegistry", in docker"
set_action_output registry "$awsEcrRegistry"

find_image_in_ecr() {
    aws ecr describe-images --repository-name=$1 --image-ids=imageTag=$2
}

fullEcrImage="$awsEcrRegistry/$imageRepo:$imageTag"
set_action_output image "$fullEcrImage"

# found image => success exit
if find_image_in_ecr $imageRepo $imageTag; then
    info "Found image $imageRepo:$imageTag in ECR"
    set_action_output found "true"
    exit 0
fi
info "Didn't find given image, $imageRepo:$imageTag, in ECR; Will build anew and push the image."
set_action_output found "false"

# run prebuild commands
info "Running pre-built commands..." $([[ -n "$preBuildCmd" ]] && echo \'$preBuildCmd\' || echo 'found none. SKIPPING')
if [[ -n "$preBuildCmd" ]]; then
    eval "$preBuildCmd"
fi

# execute docker build (with optional caching)
info "Building the docker image..."
cmdBuild="docker build . -f $buildDockerfile -t $imageRepo:$imageTag $buildDockerArgs"
if [[ -n "$buildCache" ]]; then
    cmdBuild+=" --cache-from=$buildCache"
fi
info "Executing \'$cmdBuild\'..."
eval $cmdBuild

# push to AWS ECR registry
info "Pushing the given image to ECR registry..."
docker tag "$imageRepo:$imageTag" "$fullEcrImage"
docker push "$fullEcrImage"

# update cache with new image
if [[ "$updateCache" = true ]]; then
    info "Updating the cache image with the built image..."
    docker login "$cacheRegistry" --username "$cacheRegistryUsername" --password "$cacheRegistryPassword"
    docker tag "$imageRepo:$imageTag" "$buildCache"
    docker push "$buildCache"
fi
