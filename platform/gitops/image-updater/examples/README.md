# Image Updater Examples

These files show the public app image automation convention:

- `sample-app-kustomization.yaml` keeps deployable image tags in Kustomize
  `images:` entries.
- `image-updater.yaml` updates only short Git SHA tags that match
  `^[0-9a-f]{7}$`.
- `image-workflow.yml` shows the image build loop guard: ignore the Kustomize
  path that Image Updater writes back to Git.

The workflow example is intentionally outside `.github/workflows/`; copy it
into an application repository only after replacing the sample image and paths.
