const fs = require("fs");
const path = require("path");
const Sprite = require("./Sprite");
const PhysicsBody = require("./PhysicsBody");
const Id = require("./Id");
const { Events, Channels } = require("./Events");

/**
 * Tiled Loader Class
 * * Loads and parses Tiled XML maps (.tmx) and creates tile sprites.
 * * Note: This includes a basic XML regex parser to avoid external dependencies like 'xml2js'.
 * For production use with complex maps, consider using a robust XML library.
 */
class Tiled {
  /**
   * Loads map and populates the world.
   * * @param {Object} world
   * @param {Object} packer
   * @param {string} mapPath
   */
  static loadMap(world, packer, mapPath) {
    console.log("Loading map...");
    if (!fs.existsSync(mapPath)) {
      console.error(`Map file not found: ${mapPath}`);
      return;
    }

    const mapContent = fs.readFileSync(mapPath, "utf8");
    const mapAttrs = this.parseAttributes(mapContent, "map");

    const mapTileWidth = parseInt(mapAttrs.tilewidth);
    const mapTileHeight = parseInt(mapAttrs.tileheight);
    const mapWidth = parseInt(mapAttrs.width);
    const mapHeight = parseInt(mapAttrs.height);

    // Find tileset source
    const tilesetTag = this.findTag(mapContent, "tileset");
    const tilesetAttrs = this.parseTagAttributes(tilesetTag);
    const tilesetSource = tilesetAttrs.source;
    const firstGid = parseInt(tilesetAttrs.firstgid);

    const mapDir = path.dirname(mapPath);
    const tilesetPath = path.resolve(mapDir, tilesetSource);

    if (!fs.existsSync(tilesetPath)) {
      console.error(`Tileset file not found: ${tilesetPath}`);
      return;
    }

    const tilesetContent = fs.readFileSync(tilesetPath, "utf8");
    const tilesetRootAttrs = this.parseAttributes(tilesetContent, "tileset");

    const tilesetTileWidth = parseInt(tilesetRootAttrs.tilewidth);
    const tilesetTileHeight = parseInt(tilesetRootAttrs.tileheight);
    const tilesetColumns = parseInt(tilesetRootAttrs.columns);

    // Parse image tag inside tileset
    const imageTag = this.findTag(tilesetContent, "image");
    const imageAttrs = this.parseTagAttributes(imageTag);
    const textureSource = imageAttrs.source;

    const tilesetDir = path.dirname(tilesetPath);
    const texturePath = path.resolve(tilesetDir, textureSource);

    if (!fs.existsSync(texturePath)) {
      console.error(`Texture file not found: ${texturePath}`);
    }

    // Store map info
    world.mapInfo = {
      mapWidth,
      mapHeight,
      mapTileWidth,
      mapTileHeight,
      texturePath,
      tilesetColumns,
      firstGid,
    };

    // Parse layers
    // Regex to find all <layer> blocks
    const layerRegex = /<layer([\s\S]*?)<\/layer>/g;
    let match;
    let zIndex = 0.0;

    while ((match = layerRegex.exec(mapContent)) !== null) {
      const layerBlock = match[0]; // Full <layer>...</layer> string
      const layerAttrs = this.parseTagAttributes(match[1]); // attributes only
      const layerName = layerAttrs.name;

      // Extract data (CSV)
      const dataTagMatch = /<data[^>]*>([\s\S]*?)<\/data>/.exec(layerBlock);
      if (!dataTagMatch) continue;

      const csvData = dataTagMatch[1].trim();
      const tileGids = csvData.split(",").map((s) => parseInt(s.trim()));

      // Check properties for collision
      let isCollisionLayer = false;
      const propsMatch = /<properties>([\s\S]*?)<\/properties>/.exec(
        layerBlock,
      );
      if (propsMatch) {
        const propRegex =
          /<property[^>]*name="collision"[^>]*value="true"[^>]*\/?>/g;
        if (propRegex.test(propsMatch[1])) {
          isCollisionLayer = true;
        }
      }

      console.log(`Processing layer: ${layerName} at z=${zIndex}`);

      let i = 0;
      for (let y = 0; y < mapHeight; y++) {
        for (let x = 0; x < mapWidth; x++) {
          const gid = tileGids[i++];

          if (gid === 0) continue; // Empty tile

          const id = Id.generate(); // returns [BigInt, BigInt]
          const tileSprite = new Sprite(id[0], id[1]);

          tileSprite.setTexturePath(texturePath);

          const worldX = x * mapTileWidth;
          const worldY = y * mapTileHeight;

          tileSprite.setPosition(worldX, worldY, zIndex);
          tileSprite.setSize(mapTileWidth, mapTileHeight);

          // Calculate source rect
          const localTileId = gid - firstGid;
          const tileX = (localTileId % tilesetColumns) * tilesetTileWidth;
          const tileY =
            Math.floor(localTileId / tilesetColumns) * tilesetTileHeight;

          tileSprite.setSourceRect(
            tileX,
            tileY,
            tilesetTileWidth,
            tilesetTileHeight,
          );

          const key = Id.toHex(id);
          if (!world.sprites) world.sprites = {};
          world.sprites[key] = tileSprite;
          tileSprite.packDirtyEvents(packer);

          if (isCollisionLayer) {
            const physBody = new PhysicsBody(id[0], id[1]);

            // Static box
            physBody.setConfig(1, 0, 0.0, 1.0, 0.2);
            physBody.setShape(mapTileWidth, mapTileHeight);
            physBody.setPosition(worldX, worldY, false);

            if (!world.physicsBodies) world.physicsBodies = {};
            world.physicsBodies[key] = physBody;
            physBody.packDirtyEvents(packer);
          }
        }
      }
      zIndex++;
    }
    console.log("Map loading complete.");
  }

  // --- Simple XML Helpers ---

  /**
   * Helper to find a specific tag content.
   * @private
   */
  static findTag(xml, tagName) {
    const regex = new RegExp(`<${tagName}[^>]*>`, "i");
    const match = regex.exec(xml);
    return match ? match[0] : null;
  }

  /**
   * Parses attributes from a tag string (e.g. <map width="10" ...>)
   * @private
   */
  static parseTagAttributes(tagString) {
    const attrs = {};
    if (!tagString) return attrs;

    // Regex for name="value"
    const regex = /([a-zA-Z0-9_:-]+)="([^"]*)"/g;
    let match;
    while ((match = regex.exec(tagString)) !== null) {
      attrs[match[1]] = match[2];
    }
    return attrs;
  }

  /**
   * Finds a tag by name and returns its attributes.
   * @private
   */
  static parseAttributes(xml, tagName) {
    const tag = this.findTag(xml, tagName);
    return this.parseTagAttributes(tag);
  }
}

module.exports = Tiled;
