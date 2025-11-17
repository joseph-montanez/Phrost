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

    private function packEvent(Events $type, array $data): void
    {
        $typeValue = $type->value;
        $this->eventStream .= pack("VQ", $typeValue, 0); // 12 bytes header (type + timestamp)

        if ($type === Events::SPRITE_TEXTURE_LOAD) {
            if (count($data) !== 4) {
                error_log(
                    "CommandPacker (TEXTURE_LOAD): Incorrect data count, expected 4.",
                );
                return;
            }
            $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $data[3]; // Append filename string
        } elseif ($type === Events::PLUGIN_LOAD) {
            if (count($data) !== 2) {
                error_log(
                    "CommandPacker (PLUGIN_LOAD): Incorrect data count, expected 2.",
                );
                return;
            }
            $packedFixedPart = pack("V", $data[0]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $data[1]; // Append path string
        } elseif ($type === Events::AUDIO_LOAD) {
            if (count($data) !== 2) {
                error_log(
                    "CommandPacker (AUDIO_LOAD): Incorrect data count, expected 2.",
                );
                return;
            }
            $packedFixedPart = pack("V", $data[0]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $data[1]; // Append path string
        } elseif ($type === Events::TEXT_ADD) {
            if (count($data) !== 14) {
                error_log(
                    "CommandPacker (TEXT_ADD): Incorrect data count, expected 14.",
                );
                return;
            }
            // Corrected format: e = f64, g = f32
            $packedFixedPart = pack(
                "qqeeeCCCCx4gVVx4",
                $data[0],
                $data[1],
                $data[2],
                $data[3],
                $data[4], // id1, id2, posXYZ (e)
                $data[5],
                $data[6],
                $data[7],
                $data[8], // rgba (C)
                $data[9],
                $data[10],
                $data[11], // fontSize(g), fontPathLength(V), textLength(V)
            );
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $data[12]; // Append fontPath
            $this->eventStream .= $data[13]; // Append text
        } elseif ($type === Events::TEXT_SET_STRING) {
            if (count($data) !== 4) {
                error_log(
                    "CommandPacker (TEXT_SET_STRING): Incorrect data count, expected 4.",
                );
                return;
            }
            $packedFixedPart = pack("qqVx4", $data[0], $data[1], $data[2]);
            $this->eventStream .= $packedFixedPart;
            $this->eventStream .= $data[3]; // Append text string
        } else {
            // --- Fixed-Size Event Packing Logic ---
            $payloadInfo = PackFormat::getInfo($typeValue);
            if ($payloadInfo === null) {
                error_log(
                    "CommandPacker ({$type->name}): Could not get payload info.",
                );
                return;
            }

            $pureFormat = self::getPureFormat($payloadInfo["format"]);
            if (empty($pureFormat) && !empty($data)) {
                error_log(
                    "CommandPacker ({$type->name}): Format is empty but data was provided.",
                );
                return;
            }

            if (empty($pureFormat) && empty($data)) {
                // Correctly handle no-payload events like AUDIO_STOP_ALL
            } else {
                $numericData = array_values($data);
                try {
                    $packedPayload = pack($pureFormat, ...$numericData);
                    if ($packedPayload === false) {
                        error_log(
                            "CommandPacker ({$type->name}): pack() returned false. Format='{$pureFormat}'",
                        );
                    } else {
                        $this->eventStream .= $packedPayload;
                    }
                } catch (\ValueError $e) {
                    error_log(
                        "CommandPacker ({$type->name}): ValueError during pack()! Format='{$pureFormat}', Error: {$e->getMessage()}",
                    );
                } catch (\Exception $e) {
                    error_log(
                        "CommandPacker ({$type->name}): Exception during pack()! Format='{$pureFormat}', Error: {$e->getMessage()}",
                    );
                }
            }
        }
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
        return pack("V", $this->commandCount) . $this->eventStream;
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
                    break; // Stop at variable part
                }
                $pure .= $code . $count;
            }
        }
        return self::$pureFormatCache[$descriptiveFormat] = $pure;
    }
}
