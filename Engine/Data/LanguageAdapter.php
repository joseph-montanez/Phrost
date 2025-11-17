<?php

interface LanguageAdapter
{
    /**
     * Generates all necessary code files for this language.
     *
     * @param string $jsonFile The path to the source JSON file (for header comments)
     * @param array $allEnums [id => enumName]
     * @param array $uniqueStructs [structName => structObject]
     * @param array $groupedStructs [category => [structObject, ...]]
     * @param array $allStructs The raw array of all structs from JSON
     */
    public function generate(
        string $jsonFile,
        array $allEnums,
        array $uniqueStructs,
        array $groupedStructs,
        array $allStructs,
    ): void;
}
