<?php

namespace Phrost;

/**
 * Helper enum to define Geometry types, mapping to their Event ID.
 */
enum GeomType: int
{
    case POINT = 50; // Events::GEOM_ADD_POINT->value;
    case LINE = 51; // Events::GEOM_ADD_LINE->value;
    case RECT = 52; // Events::GEOM_ADD_RECT->value;
    case FILL_RECT = 53; // Events::GEOM_ADD_FILL_RECT->value;
}
