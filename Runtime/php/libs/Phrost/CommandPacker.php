<?php

namespace Phrost;

class CommandPacker
{
    private string $eventStream = "";
    private int $commandCount = 0;
    private static array $pureFormatCache = [];
    private array $eventBuffer = [];
    private int $chunkSize = 0;
    private $chunkCallback = null;

    public function __construct(int $chunkSize = 0, $chunkCallback = null)
    {
        $this->chunkSize = $chunkSize;
        $this->chunkCallback = $chunkCallback;
    }

    public function add(Events $type, array $data): void
    {
        if ($this->chunkSize > 0) {
            $this->eventBuffer[] = ["type" => $type, "data" => $data];
            if (count($this->eventBuffer) >= $this->chunkSize) {
                $this->packBufferedEvents();
            }
        } else {
            $this->packEvent($type, $data);
        }
    }

    // --- Pack string and pad to 8 bytes ---
    private function packStringAligned(string $str): string
    {
        $len = strlen($str);
        $padding = (8 - ($len % 8)) % 8;
        return $str . str_repeat("\0", $padding);
    }

    // --- Pad stream to 8-byte boundary ---
    private function padToBoundary(): void
    {
        $currentLen = strlen($this->eventStream);
        $padding = (8 - ($currentLen % 8)) % 8;
        if ($padding > 0) {
            $this->eventStream .= str_repeat("\0", $padding);
        }
    }

    private function packEvent(Events $type, array $data): void
    {
        $typeValue = $type->value;

        // ALIGNMENT FIX: Header is now 16 bytes (4 + 8 + 4 padding)
        $this->eventStream .= pack("VQx4", $typeValue, 0);

        if ($type === Events::SPRITE_TEXTURE_LOAD) {
            // Fixed part is 24 bytes (Aligned)
            $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
            $this->eventStream .= $packedFixedPart;
            // String must be aligned
            $this->eventStream .= $this->packStringAligned($data[3]);
        } elseif ($type === Events::PLUGIN_LOAD) {
            $packedFixedPart = pack("V", $data[0]); // 4 bytes
            $this->eventStream .= $packedFixedPart;
            // Pad the gap between fixed (4) and string?
            // No, packStringAligned handles its own tail padding,
            // but we need the START of the string to be aligned relative to struct?
            // Ideally, the struct before it should end on boundary.
            // V (4) is not 8-aligned.
            // Let's pad the fixed part to 8 bytes first.
            $this->eventStream .= str_repeat("\0", 4);

            $this->eventStream .= $this->packStringAligned($data[1]);
        } elseif ($type === Events::AUDIO_LOAD) {
            // Fixed part: Length(4) + Padding(4) = 8 bytes
            // This remains correct, but Swift needs to skip the 'x4'.
            if (count($data) !== 2) {
                error_log(
                    "CommandPacker (AUDIO_LOAD): Incorrect data count, expected 2.",
                );
                return;
            }
            $packedFixedPart = pack("Vx4", $data[0]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $this->packStringAligned($data[1]);
        } elseif ($type === Events::TEXT_ADD) {
            // Fixed part is 64 bytes (Aligned)
            $packedFixedPart = pack(
                "qqeeeCCCCx4gVVx4",
                $data[0],
                $data[1],
                $data[2],
                $data[3],
                $data[4],
                $data[5],
                $data[6],
                $data[7],
                $data[8],
                $data[9],
                $data[10],
                $data[11],
            );
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $this->packStringAligned($data[12]); // fontPath
            $this->eventStream .= $this->packStringAligned($data[13]); // text
        } elseif ($type === Events::TEXT_SET_STRING) {
            // Fixed part is 24 bytes (Aligned)
            $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $this->packStringAligned($data[3]);
        } elseif ($type === Events::UI_BEGIN_WINDOW) {
            // Header: ggggVV (24 bytes)
            // Data: x, y, w, h, flags, titleLen, title
            $packedFixedPart = pack(
                "ggggVV",
                $data[0],
                $data[1],
                $data[2],
                $data[3],
                $data[4],
                $data[5],
            );
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $this->packStringAligned($data[6]);
        } elseif ($type === Events::UI_TEXT) {
            // Header: Vx4 (8 bytes)
            // Data: textLen, text
            $packedFixedPart = pack("Vx4", $data[0]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $this->packStringAligned($data[1]);
        } elseif ($type === Events::UI_BUTTON) {
            // Header: VggV (16 bytes)
            // Data: id, w, h, labelLen, label
            // We MUST only pass the first 4 elements to pack.
            // Passing $data[4] (the label) here causes "unused argument" warning and data corruption.
            $packedFixedPart = pack(
                "VggV",
                $data[0],
                $data[1],
                $data[2],
                $data[3],
            );

            $this->eventStream .= $packedFixedPart;

            // The label ($data[4]) is packed separately here
            $this->eventStream .= $this->packStringAligned($data[4]);
        } else {
            // --- Fixed-Size Event Packing ---
            $payloadInfo = PackFormat::getInfo($typeValue);
            if ($payloadInfo !== null) {
                $pureFormat = self::getPureFormat($payloadInfo["format"]);
                if (!empty($pureFormat) || !empty($data)) {
                    $numericData = array_values($data);
                    $this->eventStream .= pack($pureFormat, ...$numericData);
                }
            }
        }

        // ALIGNMENT FIX: Ensure the ENTIRE event ends on an 8-byte boundary
        // This handles cases where a fixed struct (like INPUT_KEYUP, 12 bytes)
        // would cause the *next* event to start unaligned.
        $this->padToBoundary();

        $this->commandCount++;
    }

    private function packBufferedEvents(): void
    {
        if (empty($this->eventBuffer)) {
            return;
        }
        foreach ($this->eventBuffer as $event) {
            $this->packEvent($event["type"], $event["data"]);
        }
        if ($this->chunkCallback !== null) {
            ($this->chunkCallback)(
                count($this->eventBuffer),
                $this->commandCount,
            );
        }
        $this->eventBuffer = [];
    }

    public function flush(): void
    {
        if (!empty($this->eventBuffer)) {
            $this->packBufferedEvents();
        }
    }

    public function finalize(): string
    {
        $this->flush();
        if ($this->commandCount === 0) {
            return "";
        }
        // ALIGNMENT FIX: Pad the Command Count to 8 bytes (Vx4)
        // This ensures the first event starts at offset 8
        return pack("Vx4", $this->commandCount) . $this->eventStream;
    }

    public function getBufferCount(): int
    {
        return count($this->eventBuffer);
    }
    public function getTotalEventCount(): int
    {
        return $this->commandCount + count($this->eventBuffer);
    }

    private static function getPureFormat(string $descriptiveFormat): string
    {
        if (isset(self::$pureFormatCache[$descriptiveFormat])) {
            return self::$pureFormatCache[$descriptiveFormat];
        }
        $pure = "";
        foreach (explode("/", $descriptiveFormat) as $part) {
            if (preg_match("/^([a-zA-Z])(\*|\d*)/", $part, $matches)) {
                $code = $matches[1];
                $count = $matches[2];
                if ($count === "*") {
                    break;
                }
                $pure .= $code . $count;
            }
        }
        return self::$pureFormatCache[$descriptiveFormat] = $pure;
    }
}
