/**
 * Helper enum to define Geometry types, mapping to their Event ID.
 * * @readonly
 * @enum {number}
 */
const GeomType = Object.freeze({
  POINT: 50, // Events.GEOM_ADD_POINT
  LINE: 51, // Events.GEOM_ADD_LINE
  RECT: 52, // Events.GEOM_ADD_RECT
  FILL_RECT: 53, // Events.GEOM_ADD_FILL_RECT
});

module.exports = GeomType;
