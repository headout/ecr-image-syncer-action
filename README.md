## AWS ECR Image Syncer Action

This action checks if the given image (`image-repo:image-tag`) exists in AWS ECR registry (either provided `aws-ecr-registry` value or the default registry for the provided AWS account).
If no image found, then it runs the pre-build commands, builds the docker image (with the provided `dockerfile` and `image-cache` to use cached layers if possible) and pushes to ECR registry.
Finally if `do-update-cache` is `true`, then it also updates the cache by pushing back the image.

### Configuration
See [action.yml](action.yml) for all options.

#### Example:
```yaml
  steps:
    ...
    - name: Sync image in ECR
      id: image-sync
      uses: headout/ecr-image-syncer-action@master
      with:
        aws-access-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1
        image-repo: ${{ env.IMAGE_REPOSITORY }}
        image-tag: ${{ steps.vars.outputs.version }}
        pre-build-command: make install-plugins
        dockerfile: Dockerfile
        image-cache: docker.pkg.github.com/${{ github.repository }}/ergo-airflow
        do-update-cache: false
        cache-registry: docker.pkg.github.com
        cache-registry-username: ${{ github.actor }}
        cache-registry-password: ${{ secrets.GITHUB_TOKEN }}
    ...
```
