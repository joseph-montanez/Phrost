<?php

namespace Phrost;

class Tiled
{
    /**
     * Loads and parses the Tiled XML map and creates all necessary tile sprites.
     * @throws \Exception
     */
    public static function loadMap(
        array &$world,
        ChannelPacker $packer,
        string $mapPath,
    ): void {
        echo "Loading map...\n";
        if (!is_file($mapPath)) {
            error_log("Map file not found: {$mapPath}");
            return;
        }

        // Load the Map XML (.tmx)
        $mapXml = new \SimpleXMLElement(file_get_contents($mapPath));

        $mapTileWidth = (int) $mapXml["tilewidth"];
        $mapTileHeight = (int) $mapXml["tileheight"];
        $mapWidth = (int) $mapXml["width"];
        $mapHeight = (int) $mapXml["height"];

        // Load the Tileset XML (.tsx)
        $tilesetSource = (string) $mapXml->tileset["source"];
        $firstGid = (int) $mapXml->tileset["firstgid"];

        // The 'source' is relative to the map's directory, not the script's
        $mapDir = dirname($mapPath);
        // Build the path and normalize it (handles ../, ./, and / vs \)
        $tilesetPath = realpath($mapDir . DIRECTORY_SEPARATOR . $tilesetSource);

        if (!$tilesetPath || !is_file($tilesetPath)) {
            error_log(
                "Tileset file not found. Looked for: " .
                    $mapDir .
                    DIRECTORY_SEPARATOR .
                    $tilesetSource,
            );
            return;
        }

        $tilesetXml = new \SimpleXMLElement(file_get_contents($tilesetPath));

        $tilesetTileWidth = (int) $tilesetXml["tilewidth"];
        $tilesetTileHeight = (int) $tilesetXml["tileheight"];
        $tilesetColumns = (int) $tilesetXml["columns"];
        $textureSource = (string) $tilesetXml->image["source"];
        $tilesetDir = dirname($tilesetPath);
        $texturePath = realpath(
            $tilesetDir . DIRECTORY_SEPARATOR . $textureSource,
        );

        if (!$texturePath || !is_file($texturePath)) {
            error_log(
                "Texture file not found. Looked for: " .
                    $tilesetDir .
                    DIRECTORY_SEPARATOR .
                    $textureSource,
            );
            // You might want to return or throw here
        }

        $textureWidth = (int) $tilesetXml->image["width"];
        $textureHeight = (int) $tilesetXml->image["height"];

        $world["mapInfo"] = [
            "mapWidth" => $mapWidth,
            "mapHeight" => $mapHeight,
            "mapTileWidth" => $mapTileWidth,
            "mapTileHeight" => $mapTileHeight,
            "texturePath" => $texturePath,
            "tilesetColumns" => $tilesetColumns,
            "firstGid" => $firstGid,
        ];

        // Iterate through each layer and create sprites
        $zIndex = 0.0;
        foreach ($mapXml->layer as $layer) {
            $layerName = (string) $layer["name"];
            $csvData = (string) $layer->data;
            $tileGids = explode(",", preg_replace("/\s+/", "", $csvData));

            $isCollisionLayer = false;
            if (isset($layer->properties)) {
                foreach ($layer->properties->property as $property) {
                    if (
                        (string) $property["name"] === "collision" &&
                        (string) $property["value"] === "true"
                    ) {
                        $isCollisionLayer = true;
                        break;
                    }
                }
            }

            // Skip collision layers or other non-visible layers
            if ($isCollisionLayer) {
                // Setup static collision data
            }

            echo "Processing layer: {$layerName} at z={$zIndex}\n";

            $i = 0; // Index for the flat $tileGids array
            for ($y = 0; $y < $mapHeight; $y++) {
                for ($x = 0; $x < $mapWidth; $x++) {
                    $gid = (int) $tileGids[$i];
                    $i++;

                    // gid 0 is an empty tile, skip it
                    if ($gid === 0) {
                        continue;
                    }

                    // --- Create the Tile Sprite ---
                    $id = Id::Generate();
                    $tileSprite = new Sprite($id[0], $id[1]);

                    // 1. Set Texture (all tiles use the same sheet)
                    $tileSprite->setTexturePath($texturePath);

                    // 2. Set World Position
                    $worldX = $x * $mapTileWidth;
                    $worldY = $y * $mapTileHeight;
                    $tileSprite->setPosition($worldX, $worldY, $zIndex);

                    // 3. Set Size
                    $tileSprite->setSize($mapTileWidth, $mapTileHeight);

                    // 4. Calculate and Set Source Rect (the tile's location on the spritesheet)
                    $localTileId = $gid - $firstGid; // Convert GID to local tileset index (0-based)

                    // Calculate the (x, y) pixel coordinate of the tile on the spritesheet
                    $tileX =
                        ($localTileId % $tilesetColumns) * $tilesetTileWidth;
                    $tileY =
                        floor($localTileId / $tilesetColumns) *
                        $tilesetTileHeight;

                    $tileSprite->setSourceRect(
                        $tileX,
                        $tileY,
                        $tilesetTileWidth,
                        $tilesetTileHeight,
                    );

                    // 5. Store and Pack for engine
                    $key = Id::toHex([$tileSprite->id0, $tileSprite->id1]);
                    $world["sprites"][$key] = $tileSprite;
                    $tileSprite->packDirtyEvents($packer);

                    //-- Collision
                    if ($isCollisionLayer) {
                        // Use the *same ID* as the sprite to link them
                        $physBody = new PhysicsBody($id[0], $id[1]);

                        // Configure as a static (immovable) box
                        $physBody->setConfig(
                            1, // bodyType: 1=static
                            0, // shapeType: 0=box
                            0.0, // mass (ignored for static)
                            1.0, // friction
                            0.2, // elasticity (bounciness)
                        );

                        // Set shape to match the tile
                        $physBody->setShape($mapTileWidth, $mapTileHeight);

                        // Set position (don't notify, `isNew` handles it)
                        $physBody->setPosition($worldX, $worldY, false);

                        // Store and pack
                        $world["physicsBodies"][$key] = $physBody;
                        $physBody->packDirtyEvents($packer);
                    }
                }
            }

            $zIndex++;
        }
        echo "Map loading complete.\n";
    }
}
