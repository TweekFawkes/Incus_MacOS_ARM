#!/bin/bash
# incus_destroy.sh - Destroy Incus resources created by incus.sh
# This script removes the container, snapshot, and image

set -e

echo "=== Incus Destroy Script ==="
echo ""

# Resource names (must match incus.sh)
CONTAINER_NAME="ubuntu-24-lts-base"
SNAPSHOT_NAME="initial-setup"
IMAGE_NAME="ubuntu-24-lts-setup"

# Ensure we're using the Colima remote
if command -v incus &> /dev/null; then
    incus remote switch colima 2>/dev/null || true
fi

# Step 1: Delete the image
echo "Step 1: Deleting image '${IMAGE_NAME}'..."
if incus image list --format json 2>/dev/null | grep -q "\"${IMAGE_NAME}\""; then
    incus image delete "${IMAGE_NAME}"
    echo "✓ Image '${IMAGE_NAME}' deleted"
else
    echo "✓ Image '${IMAGE_NAME}' does not exist, skipping"
fi
echo ""

# Step 2: Stop the container (if running)
echo "Step 2: Stopping container '${CONTAINER_NAME}'..."
if incus info "${CONTAINER_NAME}" 2>/dev/null | grep -q "Status: RUNNING"; then
    incus stop "${CONTAINER_NAME}" --force
    echo "✓ Container '${CONTAINER_NAME}' stopped"
else
    echo "✓ Container '${CONTAINER_NAME}' is not running, skipping"
fi
echo ""

# Step 3: Delete the snapshot
echo "Step 3: Deleting snapshot '${SNAPSHOT_NAME}'..."
if incus snapshot list "${CONTAINER_NAME}" 2>/dev/null | grep -q "${SNAPSHOT_NAME}"; then
    incus snapshot delete "${CONTAINER_NAME}" "${SNAPSHOT_NAME}"
    echo "✓ Snapshot '${SNAPSHOT_NAME}' deleted"
else
    echo "✓ Snapshot '${SNAPSHOT_NAME}' does not exist, skipping"
fi
echo ""

# Step 4: Delete the container
echo "Step 4: Deleting container '${CONTAINER_NAME}'..."
if incus info "${CONTAINER_NAME}" 2>/dev/null >/dev/null; then
    incus delete "${CONTAINER_NAME}" --force
    echo "✓ Container '${CONTAINER_NAME}' deleted"
else
    echo "✓ Container '${CONTAINER_NAME}' does not exist, skipping"
fi
echo ""

# Step 5: Optionally stop Colima
echo "Step 5: Colima status..."
if command -v colima &> /dev/null; then
    if colima status 2>&1 | grep -q "colima is running"; then
        read -p "Do you want to stop Colima? (y/N) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            colima stop
            echo "✓ Colima stopped"
        else
            echo "✓ Colima left running"
        fi
    else
        echo "✓ Colima is not running"
    fi
fi
echo ""

echo "=== Destroy Complete ==="
echo ""
echo "Resources removed:"
echo "  - Image: ${IMAGE_NAME}"
echo "  - Snapshot: ${SNAPSHOT_NAME}"
echo "  - Container: ${CONTAINER_NAME}"
echo ""
echo "To recreate, run: ./incus.sh"

