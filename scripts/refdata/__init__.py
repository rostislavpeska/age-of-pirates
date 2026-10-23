"""Reference-data package: layered mod->vanilla catalogs (plan Part G1).

    from scripts.refdata import catalog
    catalog("proto").has("Musketeer")          # -> True (vanilla)
    catalog("grouping").resolve("pirate_village0")  # -> variant entries

Water depth semantics stay in scripts.mapsim.waterdata (re-exported here so
non-mapsim tools have one import root).
"""

from scripts.mapsim import waterdata
from scripts.refdata.catalogs import KINDS, Catalog, Entry, GroupingCatalog, catalog

__all__ = ["catalog", "Catalog", "Entry", "GroupingCatalog", "KINDS",
           "waterdata"]
