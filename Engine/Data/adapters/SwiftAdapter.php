<?php

class SwiftAdapter extends BaseAdapter
{
    protected function doGeneration(): void
    {
        $eventsFile = __DIR__ . "/../out/swift/Events.swift";
        $structsFile = __DIR__ . "/../out/swift/Structs.swift";

        // --- 1. Generate Events.swift ---
        $this->generateEventsFile($eventsFile);
        echo "Successfully generated {$eventsFile}\n";

        // --- 2. Generate Structs.swift ---
        $this->generateStructsFile($structsFile);
        echo "Successfully generated {$structsFile}\n";
    }

    private function generateEventsFile(string $outputFile): void
    {
        $output = $this->getFileHeader("SwiftAdapter.php");
        $output .= "import Foundation\n\n";
        $output .= "public enum Events: UInt32 {\n";

        $lastCategory = null;
        foreach ($this->allEnums as $id => $enumName) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n";
            }
            $output .=
                "    case " . $this->snakeToCamel($enumName) . " = {$id}\n";
            $lastCategory = $category;
        }
        $output .= "}\n";
        file_put_contents($outputFile, $output);
    }

    private function generateStructsFile(string $outputFile): void
    {
        $output = $this->getFileHeader("SwiftAdapter.php");
        $output .= "import Foundation\n\n";
        $output .= "// --- Platform-Specific Imports (Required for plugin loading in PhrostEngine+Plugin.swift) ---
#if os(Windows)
    import WinSDK
#elseif os(Linux)
    import Glibc
#else
    import Darwin
#endif
// --- End Platform-Specific Imports ---\n\n";

        foreach ($this->uniqueStructs as $structName => $struct) {
            if ($structName === "PackedWindowTitleEvent") {
                $output .= $this->getHardcodedWindowTitleStruct();
                continue;
            }

            $category = getCategory($struct["eventId"]);
            $isSendable = !in_array($category, ["window", "input"]);
            $sendableString = $isSendable ? ": Sendable" : "";

            $output .= "@frozen public struct {$structName}{$sendableString} {\n";

            // --- FIXED: Replaced broken grouping logic ---
            foreach ($struct["members"] as $member) {
                $swiftType = $this->mapJsonTypeToSwift($member);
                $output .= "    public var {$member["name"]}: {$swiftType}\n";
            }
            // --- END FIX ---

            $output .= "}\n\n";
        }
        file_put_contents($outputFile, rtrim($output) . "\n");
    }

    /**
     * Maps JSON member definition to a Swift type.
     *
     * @param array $member The member definition from structs.json
     * @return string The corresponding Swift type
     */
    private function mapJsonTypeToSwift(array $member): string
    {
        $jsonType = $member["type"];

        // Handle "count" property for padding
        if (isset($member["count"]) && $jsonType === "u8") {
            $count = (int) $member["count"];
            if ($count <= 0) {
                return "Void"; // Or handle as error
            }
            if ($count === 1) {
                return "UInt8";
            }
            // Generate the tuple
            $tupleParts = array_fill(0, $count, "UInt8");
            return "(" . implode(", ", $tupleParts) . ")";
        }

        // Handle old array syntax as a fallback
        if (preg_match("/^u8\[(\d+)\]$/", $jsonType, $matches)) {
            $count = (int) $matches[1];
            if ($count <= 0) {
                return "Void";
            }
            if ($count === 1) {
                return "UInt8";
            }
            $tupleParts = array_fill(0, $count, "UInt8");
            return "(" . implode(", ", $tupleParts) . ")";
        }

        switch ($jsonType) {
            case "i64":
                return "Int64";
            case "u64":
                return "UInt64";
            case "i32":
                return "Int32";
            case "u32":
                return "UInt32";
            case "i16":
                return "Int16";
            case "u16":
                return "UInt16";
            case "i8":
                return "Int8";
            case "u8":
                return "UInt8";
            case "f32":
                return "Float";
            case "f64":
                return "Double";
            case "char[256]":
                // This case is handled by the hard-coded struct function
                return "CChar256Tuple"; // Placeholder, should be handled
            default:
                return "UnknownType";
        }
    }

    private function getHardcodedWindowTitleStruct(): string
    {
        return <<<'SWIFT'
        @frozen public struct PackedWindowTitleEvent {
            public var title:
                (
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar,
                    CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar
                )

            public init(title newTitle: String) {
                self.title = (
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
                )

                withUnsafeMutableBytes(of: &self.title) { buffer in
                    newTitle.withCString { cString in
                        guard let dest = buffer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
                            return
                        }

                        #if os(Windows)
                            strcpy_s(dest, buffer.count, cString)
                        #else
                            strlcpy(dest, cString, buffer.count)
                        #endif
                    }
                }
            }
        }
        SWIFT;
    }
}
