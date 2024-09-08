# Check if the device is not paired
if ! blueutil --paired | grep -q "78-15-2d-18-9d-3b"; then
    blueutil --pair "78-15-2d-18-9d-3b"
fi

# Check if the device is not connected
if blueutil --is-connected "78-15-2d-18-9d-3b" -eq 0; then
    blueutil --connect "78-15-2d-18-9d-3b"
fi