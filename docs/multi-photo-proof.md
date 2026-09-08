# Multi-photo task proof

A completed task can contain one to four edited photos. The mobile client selects a layout, edits every source photo locally, renders a square cover composition, and sends both the cover and the ordered edited photos.

## Layout codes

- `single`: one photo
- `two-vertical`: two side-by-side photos
- `two-horizontal`: two stacked photos
- `three-grid`: one large and two small photos
- `four-grid`: four equal photos

The API verifies that the number of uploaded source photos exactly matches the selected layout. Every photo is limited to 5 MB, the combined upload is limited to 20 MB, and JPEG, PNG, and WebP are validated by magic bytes.

## Storage model

`TaskProofMedia` remains the protected cover/thumbnail used by existing feed and profile flows. `TaskProofItem` stores the ordered edited source photos for the completion. `TaskCompletion.ProofLayoutCode` records the selected layout.

The original unique index on `TaskProofMedia.TaskCompletionId` is removed so the data model no longer enforces the one-proof-record assumption. Existing single-photo records continue to use the `single` layout.

## Client editing

Editing is performed before upload and supports:

- 90-degree rotation
- square center crop
- optional text overlay
- reset and final preview

The server never trusts the file extension or client MIME value; it validates the final bytes again.

## Authorization

Gallery metadata and each individual photo require authentication. Access is allowed to the owner or to a currently accepted friend while the related task/post remains shared and visible. Removing a friendship, hiding a post, deleting a task, or deactivating the owner removes social access.

## Compatibility

The legacy `ProofImage` multipart field remains supported. A modern client sends:

- `ProofImage`: rendered layout cover
- `ProofImages`: repeated ordered edited source photos
- `ProofLayoutCode`: selected layout

Existing single-photo clients therefore continue working while new clients gain the multi-photo workflow.

## Document-aligned mobile flow

The mobile flow follows the approved mockup as two clear stages instead of placing every control in one long form:

1. A pale layout-selection screen presents orange layout cards with purple photo areas.
2. A dark story-style composer lets the user select a slot and choose Gallery or Camera.
3. The selected photo opens a full-screen editor with Rotate, Crop, Text, and Reset actions.
4. The completed composition returns to the task form as a single preview before submission.

The lower-left composer action is explicitly a Gallery action. The former camera-switch symbol was removed because it looked like a rotation control while actually meaning replace-photo.

## Edited-image validation

Edited images are re-encoded as PNG and their MIME type and file extension are derived from the actual magic bytes. Unedited images retain their original JPEG/PNG/WebP metadata. The exact `ByteData` view is copied instead of the entire backing buffer, and edited images are constrained to a maximum dimension of 1024 pixels so that lossless PNG output remains within the existing 5 MB per-image server limit.
