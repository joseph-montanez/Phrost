<?php
/**
 * Debug script to verify UI_BUTTON packing is correct
 * Run this to check the binary output
 */

// Simulate the button packing
$id = 101;
$w = 200.0;
$h = 30.0;
$label = "Player Attack";
$labelLen = strlen($label);

echo "=== Button Parameters ===\n";
echo "id: $id\n";
echo "w: $w\n";
echo "h: $h\n";
echo "label: '$label'\n";
echo "labelLen: $labelLen\n\n";

// Pack the header (event header + payload header)
// Event header: VQx4 (type, timestamp, padding) = 16 bytes
// Payload header: VggV (id, w, h, labelLen) = 16 bytes

// Simulate event type for UI_BUTTON = 4003
$eventType = 4003;
$timestamp = 0;

// Event header
$eventHeader = pack("VQx4", $eventType, $timestamp);

// Payload header
$payloadHeader = pack("VggV", $id, $w, $h, $labelLen);

// String with padding to 8-byte boundary
$strPadding = (8 - ($labelLen % 8)) % 8;
$paddedString = $label . str_repeat("\0", $strPadding);

echo "=== Packed Sizes ===\n";
echo "Event header size: " . strlen($eventHeader) . " bytes\n";
echo "Payload header size: " . strlen($payloadHeader) . " bytes\n";
echo "Label + padding size: " .
    strlen($paddedString) .
    " bytes (label=$labelLen + padding=$strPadding)\n";
echo "Total event size: " .
    (strlen($eventHeader) + strlen($payloadHeader) + strlen($paddedString)) .
    " bytes\n\n";

// Combine
$fullEvent = $eventHeader . $payloadHeader . $paddedString;

// Check if we need final padding
$totalLen = strlen($fullEvent);
$finalPadding = (8 - ($totalLen % 8)) % 8;
if ($finalPadding > 0) {
    $fullEvent .= str_repeat("\0", $finalPadding);
    echo "Final padding added: $finalPadding bytes\n";
} else {
    echo "No final padding needed\n";
}

echo "=== Hex Dump ===\n";
// Hex dump
for ($i = 0; $i < strlen($fullEvent); $i++) {
    if ($i % 16 == 0) {
        if ($i > 0) {
            echo "\n";
        }
        echo sprintf("%04X: ", $i);
    }
    if ($i % 8 == 0 && $i % 16 != 0) {
        echo " ";
    }
    echo sprintf("%02X ", ord($fullEvent[$i]));
}
echo "\n\n";

// Decode to verify
echo "=== Decoded Values ===\n";
$offset = 0;

// Event header
$decoded = unpack("VeventType/Qtimestamp", substr($fullEvent, $offset, 12));
echo "Event type: " . $decoded["eventType"] . " (expected: 4003)\n";
echo "Timestamp: " . $decoded["timestamp"] . "\n";
$offset += 16; // 12 bytes + 4 padding

// Payload header - use 'V' for uint32 and 'g' for float
$decoded = unpack("Vid/gw/gh/VlabelLen", substr($fullEvent, $offset, 16));
echo "id: " . $decoded["id"] . " (expected: 101)\n";
echo "w: " . $decoded["w"] . " (expected: 200.0)\n";
echo "h: " . $decoded["h"] . " (expected: 30.0)\n";
echo "labelLen: " . $decoded["labelLen"] . " (expected: 13)\n";
$offset += 16;

// String
$labelDecoded = substr($fullEvent, $offset, $decoded["labelLen"]);
echo "label: '$labelDecoded' (expected: 'Player Attack')\n";

echo "\n=== Validation ===\n";
if ($decoded["id"] == $id) {
    echo "✓ id matches\n";
} else {
    echo "✗ id MISMATCH!\n";
}
if (abs($decoded["w"] - $w) < 0.01) {
    echo "✓ w matches\n";
} else {
    echo "✗ w MISMATCH! Got " . $decoded["w"] . "\n";
}
if (abs($decoded["h"] - $h) < 0.01) {
    echo "✓ h matches\n";
} else {
    echo "✗ h MISMATCH! Got " . $decoded["h"] . "\n";
}
if ($decoded["labelLen"] == $labelLen) {
    echo "✓ labelLen matches\n";
} else {
    echo "✗ labelLen MISMATCH!\n";
}
if ($labelDecoded == $label) {
    echo "✓ label matches\n";
} else {
    echo "✗ label MISMATCH!\n";
}

echo "\nIf all checks pass, the PHP packing is correct.\n";
echo "Run this script with: php debug_button_packing.php\n";
