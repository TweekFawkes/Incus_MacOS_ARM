#!/bin/bash
# incus.sh - Setup Incus with Colima and Rosetta
# This script installs and configures Incus to run on macOS via Colima

set -e

echo "=== Incus + Colima Setup Script ==="
echo ""

# Step 1: Check and install Incus
echo "Step 1: Checking Incus..."
if command -v incus &> /dev/null; then
    echo "✓ Incus is already installed ($(incus --version))"
else
    echo "Incus not found. Installing via Homebrew..."
    brew install incus
    
    if command -v incus &> /dev/null; then
        echo "✓ Incus installed successfully ($(incus --version))"
    else
        echo "✗ Failed to install Incus"
        exit 1
    fi
fi
echo ""

# Step 2: Check and install Colima
echo "Step 2: Checking Colima..."
if command -v colima &> /dev/null; then
    echo "✓ Colima is already installed ($(colima --version | head -1))"
else
    echo "Colima not found. Installing via Homebrew..."
    brew install colima
    
    if command -v colima &> /dev/null; then
        echo "✓ Colima installed successfully ($(colima --version | head -1))"
    else
        echo "✗ Failed to install Colima"
        exit 1
    fi
fi
echo ""

# Step 2.5: Check and install QEMU (required for x86_64 emulation on ARM)
echo "Step 2.5: Checking QEMU..."
if command -v qemu-img &> /dev/null; then
    echo "✓ QEMU is already installed ($(qemu-img --version | head -1))"
else
    echo "QEMU not found. Installing via Homebrew (required for x86_64 emulation)..."
    brew install qemu
    
    if command -v qemu-img &> /dev/null; then
        echo "✓ QEMU installed successfully ($(qemu-img --version | head -1))"
    else
        echo "✗ Failed to install QEMU"
        exit 1
    fi
fi
echo ""

# Step 2.6: Check and install lima-additional-guestagents (required for x86_64 guest agents)
echo "Step 2.6: Checking lima-additional-guestagents..."
if brew list lima-additional-guestagents &>/dev/null; then
    echo "✓ lima-additional-guestagents is already installed"
else
    echo "lima-additional-guestagents not found. Installing via Homebrew (required for x86_64 guest agents)..."
    brew install lima-additional-guestagents
    
    if brew list lima-additional-guestagents &>/dev/null; then
        echo "✓ lima-additional-guestagents installed successfully"
    else
        echo "✗ Failed to install lima-additional-guestagents"
        exit 1
    fi
fi
echo ""

# Step 3: Start Colima with Rosetta and Incus runtime
echo "Step 3: Starting Colima with Rosetta and Incus runtime..."

# Check current Colima state (use || true to prevent set -e from exiting on non-zero)
COLIMA_STATUS=$(colima status 2>&1) || true
if echo "$COLIMA_STATUS" | grep -q "colima is running"; then
    CURRENT_ARCH=$(echo "$COLIMA_STATUS" | grep 'msg="arch:' | sed -E 's/.*msg="arch: ([^"]+)".*/\1/' || echo "")
    if [ "$CURRENT_ARCH" = "x86_64" ]; then
        echo "✓ Colima is already running with correct architecture (x86_64)"
    else
        echo "Colima is running with architecture '$CURRENT_ARCH', but we need x86_64."
        echo "Architecture cannot be changed after initial setup. Deleting existing instance..."
        colima stop -f 2>/dev/null || true
        sleep 2
        colima delete -f 2>/dev/null || true
        rm -rf "$HOME/.colima/default" 2>/dev/null || true
        echo "✓ Existing Colima instance deleted"
        
        echo "Starting Colima fresh with --runtime=incus --vz-rosetta --arch x86_64..."
        colima start --runtime=incus --vz-rosetta --arch x86_64
        echo "✓ Colima started successfully"
    fi
elif echo "$COLIMA_STATUS" | grep -q "colima is not running"; then
    # Colima exists but is stopped - just start it
    echo "Colima is not running. Starting..."
    colima start --runtime=incus --vz-rosetta --arch x86_64 || {
        # If that fails, try cleaning up and starting fresh
        echo "Start failed, cleaning up and retrying..."
        colima stop -f 2>/dev/null || true
        sleep 2
        colima delete -f 2>/dev/null || true
        rm -rf "$HOME/.colima/default" 2>/dev/null || true
        rm -rf "$HOME/.colima/_lima/colima" 2>/dev/null || true
        colima start --runtime=incus --vz-rosetta --arch x86_64
    }
    echo "✓ Colima started successfully"
elif echo "$COLIMA_STATUS" | grep -qE "(error|fatal)"; then
    # Colima is in a bad/unknown state, clean up completely
    echo "Colima is in an error state. Cleaning up completely..."
    colima stop -f 2>/dev/null || true
    sleep 2
    colima delete -f 2>/dev/null || true
    rm -rf "$HOME/.colima/default" 2>/dev/null || true
    rm -rf "$HOME/.colima/_lima/colima" 2>/dev/null || true
    echo "✓ Cleaned up Colima"
    
    echo "Starting Colima fresh with --runtime=incus --vz-rosetta --arch x86_64..."
    colima start --runtime=incus --vz-rosetta --arch x86_64
    echo "✓ Colima started successfully"
else
    # Colima not installed or other state, try to start it
    echo "Starting Colima with --runtime=incus --vz-rosetta --arch x86_64..."
    colima start --runtime=incus --vz-rosetta --arch x86_64 || {
        # If that fails, try cleaning up and starting fresh
        echo "Start failed, cleaning up and retrying..."
        colima stop -f 2>/dev/null || true
        sleep 2
        colima delete -f 2>/dev/null || true
        rm -rf "$HOME/.colima/default" 2>/dev/null || true
        rm -rf "$HOME/.colima/_lima/colima" 2>/dev/null || true
        colima start --runtime=incus --vz-rosetta --arch x86_64
    }
    echo "✓ Colima started successfully"
fi
echo ""

# Step 4: Configure Incus to use Colima
echo "Step 4: Configuring Incus to use Colima..."
COLIMA_SOCKET="unix://$HOME/.colima/default/incus.sock"

# Wait for the socket to be ready
echo "Waiting for Incus socket to be ready..."
for i in {1..30}; do
    if [ -S "$HOME/.colima/default/incus.sock" ]; then
        echo "✓ Incus socket is ready"
        break
    fi
    sleep 1
done

if [ ! -S "$HOME/.colima/default/incus.sock" ]; then
    echo "✗ Incus socket not found after 30 seconds"
    exit 1
fi

# Add Colima remote (ignore error if it already exists)
incus remote add colima "$COLIMA_SOCKET" 2>/dev/null || true

# Switch to Colima remote
echo "Switching to Colima remote..."
incus remote switch colima

# Verify connection
if incus list >/dev/null 2>&1; then
    echo "✓ Successfully connected to Colima Incus instance"
else
    echo "✗ Failed to connect to Incus. Current remotes:"
    incus remote list
    exit 1
fi
echo ""

# Step 5: Create Ubuntu 24.04 LTS x64 system container
CONTAINER_NAME="ubuntu-24-lts-base"
echo "Step 5: Creating Ubuntu 24.04 LTS x64 system container..."
if incus list --format json 2>/dev/null | grep -q "\"name\":\"${CONTAINER_NAME}\"" || incus info "${CONTAINER_NAME}" 2>/dev/null >/dev/null; then
    echo "✓ Container '${CONTAINER_NAME}' already exists"
    # Check if it's stopped, start it if needed
    CONTAINER_STATUS=$(incus list "${CONTAINER_NAME}" --format json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [ "$CONTAINER_STATUS" = "Stopped" ]; then
        echo "Starting existing container..."
        incus start "${CONTAINER_NAME}"
    else
        echo "Container is already running"
    fi
else
    echo "Launching Ubuntu 24.04 LTS x64 container..."
    incus launch images:ubuntu/24.04 "${CONTAINER_NAME}"
    echo "✓ Container '${CONTAINER_NAME}' created and started"
fi
echo ""

# Step 6: Wait for container to be ready
echo "Step 6: Waiting for container to be ready..."
sleep 5
echo "✓ Container is ready"
echo ""

# Step 7: Copy and execute bootscript
BOOTSCRIPT_PATH="$(dirname "$0")/incus_bootscript.sh"
SNAPSHOT_NAME="initial-setup"
echo "Step 7: Setting up container with bootscript..."

# Skip bootscript if snapshot already exists (means setup was already done)
if incus snapshot list "${CONTAINER_NAME}" 2>/dev/null | grep -q "${SNAPSHOT_NAME}"; then
    echo "✓ Setup already complete (snapshot '${SNAPSHOT_NAME}' exists), skipping bootscript"
else
    if [ ! -f "${BOOTSCRIPT_PATH}" ]; then
        echo "✗ Error: Bootscript not found at ${BOOTSCRIPT_PATH}"
        exit 1
    fi

    echo "Copying bootscript to container..."
    # Retry file push up to 3 times
    for i in 1 2 3; do
        if incus file push "${BOOTSCRIPT_PATH}" "${CONTAINER_NAME}/tmp/bootscript.sh" 2>/dev/null; then
            break
        fi
        echo "Retry $i/3..."
        sleep 2
    done

    echo "Making bootscript executable and running it..."
    incus exec "${CONTAINER_NAME}" -- bash -c "chmod +x /tmp/bootscript.sh && /tmp/bootscript.sh"

    echo "✓ Bootscript executed successfully"
fi
echo ""

# Step 8: Take a snapshot
SNAPSHOT_NAME="initial-setup"
echo "Step 8: Creating snapshot '${SNAPSHOT_NAME}'..."
if incus snapshot list "${CONTAINER_NAME}" 2>/dev/null | grep -q "${SNAPSHOT_NAME}"; then
    echo "✓ Snapshot '${SNAPSHOT_NAME}' already exists"
else
    incus snapshot create "${CONTAINER_NAME}" "${SNAPSHOT_NAME}"
    echo "✓ Snapshot '${SNAPSHOT_NAME}' created"
fi
echo ""

# Step 9: Create an image from the container
IMAGE_NAME="ubuntu-24-lts-setup"
echo "Step 9: Creating image '${IMAGE_NAME}' from container..."
if incus image list --format json 2>/dev/null | grep -q "\"${IMAGE_NAME}\""; then
    echo "✓ Image '${IMAGE_NAME}' already exists"
else
    # Use --force to stop/restart the container if it's running
    incus publish "${CONTAINER_NAME}" --alias "${IMAGE_NAME}" --force
    echo "✓ Image '${IMAGE_NAME}' created successfully"
fi
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Container: ${CONTAINER_NAME}"
echo "Snapshot: ${SNAPSHOT_NAME}"
echo "Image: ${IMAGE_NAME}"
echo ""
echo "Useful commands:"
echo "  colima status                    - Check Colima status"
echo "  colima stop                      - Stop Colima"
echo "  incus list                       - List Incus containers"
echo "  incus exec ${CONTAINER_NAME} -- bash  - Execute bash in container"
echo "  incus launch ${IMAGE_NAME} <name>     - Launch new container from image"
echo "  incus snapshot list ${CONTAINER_NAME}  - List snapshots"
