<?php

class CAdapter extends BaseAdapter
{
    protected function doGeneration(): void
    {
        $outputFile = __DIR__ . "/../out/c/events.h";

        $output = $this->getFileHeader("CAdapter.php");

        // --- 1. Generate Header Guards ---
        $output .= "#ifndef PHROST_EVENTS_H\n";
        $output .= "#define PHROST_EVENTS_H\n\n";
        $output .=
            "#include <stdint.h> // For fixed-width types like uint32_t\n";
        $output .= "#include <stdbool.h> // For bool type\n\n";

        // --- 2. Add C++ compatibility guard ---
        $output .= "#ifdef __cplusplus\nextern \"C\" {\n#endif\n\n";

        // --- 3. Generate Events Enum ---
        $output .= "// --- Events Enum ---\n";
        $output .= "typedef enum {\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $name) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n"; // Add spacing between categories
            }
            $output .= "    EVENT_{$name} = {$id},\n";
            $lastCategory = $category;
        }
        $output .= "} PhrostEventID;\n\n";

        // --- 4. Generate Structs ---
        $output .= "// --- Packed Struct Definitions ---\n\n";
        // Enforce 1-byte packing to match Zig's 'extern struct' and PHP's pack formats
        $output .= "#pragma pack(push, 1)\n\n";

        foreach ($this->uniqueStructs as $structName => $struct) {
            $output .= "// {$struct["comment"]}\n";
            $output .= "typedef struct {\n";
            foreach ($struct["members"] as $member) {
                $cType = $this->mapJsonTypeToC($member["type"]);
                $memberName = $member["name"];
                $arrayDef = "";

                if (isset($member["count"])) {
                    $arrayDef = "[{$member["count"]}]";
                } elseif (
                    preg_match("/\[(\d+)\]/", $member["type"], $matches)
                ) {
                    $arrayDef = "[$matches[1]]";
                }

                $output .= "    {$cType} {$memberName}{$arrayDef}; // {$member["comment"]}\n";
            }
            $output .= "} {$structName};\n\n";
        }

        // Restore default packing
        $output .= "#pragma pack(pop)\n\n";

        // --- 5. Close C++ guard and Header guard ---
        $output .= "#ifdef __cplusplus\n}\n#endif\n\n";
        $output .= "#endif // PHROST_EVENTS_H\n";

        file_put_contents($outputFile, $output);
        echo "Successfully generated {$outputFile}\n";
    }

    /**
     * Maps JSON type strings to C99 standard types.
     */
    private function mapJsonTypeToC(string $jsonType): string
    {
        switch ($jsonType) {
            case "i64":
                return "int64_t";
            case "u64":
                return "uint64_t";
            case "i32":
                return "int32_t";
            case "u32":
                return "uint32_t";
            case "i16":
                return "int16_t";
            case "u16":
                return "uint16_t";
            case "i8":
                return "int8_t";
            case "u8":
                return "uint8_t";
            case "f32":
                return "float";
            case "f64":
                return "double";
            case "char[256]":
                return "char"; // Array part is handled in the loop
            default:
                // Handle generic u8[N]
                if (preg_match("/^u8\[\d+\]$/", $jsonType)) {
                    return "uint8_t";
                }
                return "void"; // Should not happen
        }
    }
}
