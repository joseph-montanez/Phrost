import enum

# Imports from your existing adapter file
# (Assuming it's saved as phrost_adapter.py)
try:
    from Phrost import Events
except ImportError:
    print(
        "Could not import Events. Please ensure phrost_adapter.py is in the same directory."
    )


class GeomType(enum.IntEnum):
    """Helper enum to define Geometry types, mapping to their Event ID."""

    POINT = Events.GEOM_ADD_POINT.value
    LINE = Events.GEOM_ADD_LINE.value
    RECT = Events.GEOM_ADD_RECT.value
    FILL_RECT = Events.GEOM_ADD_FILL_RECT.value
