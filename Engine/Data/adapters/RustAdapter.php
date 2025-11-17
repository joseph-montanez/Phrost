<?php

class RustAdapter extends BaseAdapter
{
    protected function doGeneration(): void
    {
        $outputFile = __DIR__ . "/../out/rust/events.rs";

        $output = $this->getFileHeader("RustAdapter.php");
        $output .=
            "// Add `byteorder = \"1.0\"` to your Cargo.toml dependencies\n\n";
        $output .= "#![allow(dead_code)]\n"; // Suppress warnings for unused structs/enums
        $output .= "#![allow(non_camel_case_types)]\n\n"; // Allow enum variants like `spriteAdd`

        $output .= "use std::io::{Cursor, Read, Seek, SeekFrom, Write};\n";
        $output .=
            "use byteorder::{LittleEndian, ReadBytesExt, WriteBytesExt};\n\n";

        // --- 1. Generate Events Enum ---
        $output .= $this->generateEnums();

        // --- 2. Generate Structs ---
        $output .= $this->generateStructs();

        // --- 3. Generate CommandPacker ---
        $output .= $this->generatePacker();

        // --- 4. Generate EventUnpacker ---
        $output .= $this->generateUnpacker();

        file_put_contents($outputFile, rtrim($output) . "\n");
        echo "Successfully generated {$outputFile}\n";
    }

    private function generateEnums(): string
    {
        $output = "// --- Events Enum ---\n";
        $output .= "#[repr(u32)]\n";
        $output .= "#[derive(Debug, Copy, Clone, PartialEq, Eq)]\n";
        $output .= "pub enum Events {\n";
        $lastCategory = null;
        foreach ($this->allEnums as $id => $enumName) {
            $category = getCategory($id);
            if ($lastCategory !== null && $category !== $lastCategory) {
                $output .= "\n";
            }
            $camelCaseName = $this->snakeToCamel($enumName);
            $output .= "    {$camelCaseName} = {$id},\n";
            $lastCategory = $category;
        }
        $output .= "}\n\n";

        // --- Generate From<u32> helper ---
        $output .= "impl Events {\n";
        $output .= "    pub fn from_u32(value: u32) -> Option<Self> {\n";
        $output .= "        match value {\n";
        foreach ($this->allEnums as $id => $enumName) {
            $camelCaseName = $this->snakeToCamel($enumName);
            $output .= "            {$id} => Some(Events::{$camelCaseName}),\n";
        }
        $output .= "            _ => None,\n";
        $output .= "        }\n";
        $output .= "    }\n";
        $output .= "}\n\n";

        return $output;
    }

    private function generateStructs(): string
    {
        $output = "// --- Packed Struct Definitions ---\n\n";
        foreach ($this->uniqueStructs as $structName => $struct) {
            $output .= "/// {$struct["comment"]}\n";
            $output .= "#[repr(C, packed)]\n";
            $output .= "#[derive(Debug, Copy, Clone)]\n";
            $output .= "pub struct {$structName} {\n";

            foreach ($struct["members"] as $member) {
                $rustType = $this->mapJsonTypeToRust($member["type"]);
                $memberName = $this->camelToSnake($member["name"]); // <-- FIX
                if ($memberName === "mod") {
                    $memberName = "r#mod";
                }
                $finalType = "";

                if (isset($member["count"])) {
                    $finalType = "[{$rustType}; {$member["count"]}]";
                }
                // Fallback for old array syntax
                elseif (preg_match("/\[(\d+)\]/", $member["type"], $matches)) {
                    $finalType = "[{$rustType}; {$matches[1]}]";
                } else {
                    $finalType = $rustType;
                }

                $output .= "    pub {$memberName}: {$finalType}, // {$member["comment"]}\n";
            }
            $output .= "}\n\n";
        }
        return $output;
    }

    private function generatePacker(): string
    {
        // Get all dynamic structs to generate pack helpers for
        $dynamicStructs = [];
        foreach ($this->allStructs as $struct) {
            if ($struct["isDynamic"]) {
                $dynamicStructs[] = $struct;
            }
        }

        $output = "// --- Command Packer ---\n\n";
        $output .= "pub struct CommandPacker {\n";
        $output .= "    buffer: Vec<u8>,\n";
        $output .= "    command_count: u32,\n";
        $output .= "}\n\n";
        $output .= "impl CommandPacker {\n";
        $output .= "    pub fn new() -> Self {\n";
        $output .= "        Self { buffer: Vec::new(), command_count: 0 }\n";
        $output .= "    }\n\n";

        $output .=
            "    /// Finalizes the buffer by prepending the command count.\n";
        $output .= "    pub fn finalize(self) -> Vec<u8> {\n";
        $output .=
            "        let mut final_buffer = Vec::with_capacity(4 + self.buffer.len());\n";
        $output .=
            "        final_buffer.write_u32::<LittleEndian>(self.command_count).unwrap();\n";
        $output .= "        final_buffer.extend(self.buffer);\n";
        $output .= "        final_buffer\n";
        $output .= "    }\n\n";

        $output .= "    pub fn command_count(&self) -> u32 {\n";
        $output .= "        self.command_count\n";
        $output .= "    }\n\n";

        $output .= "    /// Writes the event type and a 0 timestamp.\n";
        $output .=
            "    fn write_header(&mut self, event_type: Events) -> std::io::Result<()> {\n";
        $output .=
            "        self.buffer.write_u32::<LittleEndian>(event_type as u32)?;\n";
        $output .=
            "        self.buffer.write_u64::<LittleEndian>(0)?; // 8-byte timestamp\n";
        $output .= "        Ok(())\n";
        $output .= "    }\n\n";

        $output .= "    /// Packs a fixed-size payload.\n";
        $output .=
            "    pub fn pack<T: Copy>(&mut self, event_type: Events, payload: &T) -> std::io::Result<()> {\n";
        $output .= "        self.write_header(event_type)?;\n";
        $output .= "        let bytes: &[u8] = unsafe {\n";
        $output .=
            "            // SAFETY: Assumes T is #[repr(C, packed)] and valid for any byte pattern.\n";
        $output .= "            std::slice::from_raw_parts(\n";
        $output .= "                (payload as *const T) as *const u8,\n";
        $output .= "                std::mem::size_of::<T>(),\n";
        $output .= "            )\n";
        $output .= "        };\n";
        $output .= "        self.buffer.write_all(bytes)?;\n";
        $output .= "        self.command_count += 1;\n";
        $output .= "        Ok(())\n";
        $output .= "    }\n\n";

        // --- Generate dynamic packing functions ---
        foreach ($dynamicStructs as $struct) {
            $funcName = "pack_" . strtolower($struct["enumName"]); // <-- FIX: force to lowercase
            $args = [];
            $header_fields = [];
            $variable_fields = [];

            foreach ($struct["members"] as $member) {
                $varName = $member["name"]; // camelCase name from JSON
                $snakeVarName = $this->camelToSnake($varName); // snake_case version
                $varType = $this->mapJsonTypeToRust($member["type"]);

                if (str_ends_with($varName, "Length")) {
                    // This is a length field, derive the real field name
                    $realName = str_replace("Length", "", $varName); // e.g., fontPath
                    $snakeRealName = $this->camelToSnake($realName); // e.g., font_path

                    $args[] = "{$snakeRealName}: &[u8]";
                    $header_fields[] = "{$snakeVarName}: {$snakeRealName}.len() as u32";
                    $variable_fields[] = $snakeRealName;
                } elseif (
                    $member["type"] !== "u32" &&
                    $member["type"] !== "u16"
                ) {
                    // Assume other fields are part of the header args
                    $args[] = "{$snakeVarName}: {$varType}";
                    $header_fields[] = "{$snakeVarName}: {$snakeVarName}";
                } else {
                    // This is padding, like _padding1, _padding2
                    $header_fields[] = "{$snakeVarName}: 0";
                }
            }

            $output .=
                "    pub fn {$funcName}(&mut self, " .
                implode(", ", $args) .
                ") -> std::io::Result<()> {\n";
            $output .=
                "        self.write_header(Events::" .
                $this->snakeToCamel($struct["enumName"]) .
                ")?;\n";
            $output .= "        let header = {$struct["name"]} {\n";
            $output .=
                "            " .
                implode(",\n            ", $header_fields) .
                "\n";
            $output .= "        };\n";
            $output .= "        let header_bytes: &[u8] = unsafe {\n";
            $output .= "            std::slice::from_raw_parts(\n";
            $output .= "                (&header as *const {$struct["name"]}) as *const u8,\n";
            $output .= "                std::mem::size_of::<{$struct["name"]}>(),\n";
            $output .= "            )\n";
            $output .= "        };\n";
            $output .= "        self.buffer.write_all(header_bytes)?;\n";

            foreach ($variable_fields as $varField) {
                $output .= "        self.buffer.write_all({$varField})?;\n";
            }

            $output .= "        self.command_count += 1;\n";
            $output .= "        Ok(())\n";
            $output .= "    }\n\n";
        }

        $output .= "}\n\n";
        return $output;
    }

    private function generateUnpacker(): string
    {
        $output = "// --- Event Unpacker ---\n\n";
        $output .= "pub struct EventUnpacker<'a> {\n";
        $output .= "    cursor: Cursor<&'a [u8]>,";
        $output .= "}\n\n";
        $output .= "impl<'a> EventUnpacker<'a> {\n";
        $output .= "    pub fn new(blob: &'a [u8]) -> Self {\n";
        $output .= "        Self { cursor: Cursor::new(blob) }\n";
        $output .= "    }\n\n";

        $output .=
            "    /// Reads the total event count from the start of the blob.\n";
        $output .=
            "    pub fn read_count(&mut self) -> std::io::Result<u32> {\n";
        $output .= "        self.cursor.read_u32::<LittleEndian>()\n";
        $output .= "    }\n\n";

        $output .= "    /// Reads the event type (u32) and timestamp (u64).\n";
        $output .=
            "    pub fn read_event_header(&mut self) -> std::io::Result<(Events, u64)> {\n";
        $output .=
            "        let event_type_id = self.cursor.read_u32::<LittleEndian>()?;\n";
        $output .=
            "        let timestamp = self.cursor.read_u64::<LittleEndian>()?;\n";
        $output .=
            "        let event_type = Events::from_u32(event_type_id).ok_or_else(||\n";
        $output .=
            "            std::io::Error::new(std::io::ErrorKind::InvalidData, \"Unknown event type ID\")\n";
        $output .= "        )?;\n";
        $output .= "        Ok((event_type, timestamp))\n";
        $output .= "    }\n\n";

        $output .= "    /// Reads a fixed-size payload struct.\n";
        $output .=
            "    pub fn read_payload<T: Copy>(&mut self) -> std::io::Result<T> {\n";
        $output .= "        // Create a zeroed instance of T.\n";
        $output .=
            "        let mut payload: T = unsafe { std::mem::zeroed() };\n";
        $output .=
            "        // Create a mutable byte slice that points to the payload.\n";
        $output .= "        let buffer: &mut [u8] = unsafe {\n";
        $output .= "            std::slice::from_raw_parts_mut(\n";
        $output .= "                (&mut payload as *mut T) as *mut u8,\n";
        $output .= "                std::mem::size_of::<T>(),\n";
        $output .= "            )\n";
        $output .= "        };\n";
        $output .=
            "        // Read directly from the cursor into the payload's byte slice.\n";
        $output .= "        self.cursor.read_exact(buffer)?;\n";
        $output .= "        Ok(payload)\n";
        $output .= "    }\n\n";

        $output .= "    /// Reads a variable-length byte vector.\n";
        $output .=
            "    pub fn read_variable(&mut self, len: u32) -> std::io::Result<Vec<u8>> {\n";
        $output .= "        let mut buffer = vec![0u8; len as usize];\n";
        $output .= "        self.cursor.read_exact(&mut buffer)?;\n";
        $output .= "        Ok(buffer)\n";
        $output .= "    }\n\n";

        $output .= "    /// Skips N bytes in the stream.\n";
        $output .=
            "    pub fn skip(&mut self, n: u32) -> std::io::Result<()> {\n";
        $output .= "        self.cursor.seek(SeekFrom::Current(n as i64))?;\n";
        $output .= "        Ok(())\n";
        $output .= "    }\n";

        $output .= "\n    pub fn position(&self) -> u64 {\n";
        $output .= "        self.cursor.position()\n";
        $output .= "    }\n";

        $output .= "}\n\n";

        return $output;
    }

    /**
     * Maps JSON type strings to Rust native types.
     */
    private function mapJsonTypeToRust(string $jsonType): string
    {
        switch ($jsonType) {
            case "i64":
                return "i64";
            case "u64":
                return "u64";
            case "i32":
                return "i32";
            case "u32":
                return "u32";
            case "i16":
                return "i16";
            case "u16":
                return "u16";
            case "i8":
                return "i8";
            case "u8":
                return "u8";
            case "f32":
                return "f32";
            case "f64":
                return "f64";
            case "char[256]":
                return "u8"; // Base type is u8
            default:
                if (preg_match("/^u8\[\d+\]$/", $jsonType)) {
                    return "u8";
                }
                return "UnknownType";
        }
    }

    /**
     * Converts a camelCase or mixedCase string to snake_case.
     */
    private function camelToSnake(string $input): string
    {
        if (empty($input)) {
            return $input;
        }
        // Handles cases like 'id1_A' -> 'id1_a' and 'pathLength' -> 'path_length'
        $str = preg_replace(
            "/(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])/",
            '_$0',
            $input,
        );
        return strtolower($str);
    }
}
