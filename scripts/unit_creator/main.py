import os
from typing import List, Dict, Any

from utils import DataSource, ensure_dirs
from unit_cloner import UnitCloner
from ability_cloner import AbilityCloner
from tactic_cloner import TacticCloner
from sound_cloner import SoundCloner
from anim_cloner import AnimCloner
from action_cloner import ActionCloner
from string_cloner import StringCloner
from output_handler import OutputHandler

# Configure here per spec in scripts/unit_creator/unit_creator.md
CONFIG: Dict[str, Any] = {
    "units": {
        # Required
        "proto_name": "zpNewUnit",
        "proto_base": "Musketeer",
    },
    "params": {
        # Examples of optional overrides; leave None to use base values
        "new_name": "New Unit",
        "new_editor_name": "New Unit (Editor)",
        "new_rollover": "A test unit created by the Unit Creator.",
        "new_shortrollover": "Test unit.",
        "sound_unit": "zpSubmarine",
        "abilities": ["dePowerRallyArmy", "newAbility"],
        "HP": 200,
        "velocity": 10,
        "LOS": 10,
        "icon": "resources/art/units/naval/spc/submarine_icon.png",
        "animfile": "units/naval/submarine/subma.xml",
        "generate_anim_file": True,
        "anim_to_clone": "units/naval/submarine/submarine.xml",
        "portraiticon": "resources/art/units/naval/spc/submarine_portrait.png",
        "buildlimit": 11,
        "subciv": "Dragoon",
        "populationcount": 10,
        "bounty": 100.0,
        "buildbounty": 100.0,
        "costs": {"Food": 75, "Wood": 25, "Gold": 25, "Influence": 100},
        "allowedage": 3,
        "new_tactics": "submarin.tactics",
        "generate_tactics_file": True,
        "tactics_to_clone": "submarine.tactics",
        "sharedbuildlimit": True,
        "shared_main": True,
        "main_unit_name": "zpSubmarine",
        "shared_buildlimit_units": ["zpSubmarine", "zpSubmarineProxy", "zpSubmarineTransport"],
        "shared_selection_units": ["zpSubmarine", "zpSubmarineProxy", "zpSubmarineTransport"],
        "add_proto_actions": [("CannonAttackDived", "zpSubmarineTransport"), ("CannonAttackSurface", "zpSubmarineTransport")],
        "remove_proto_actions": [],
        "new_unittypes": ["AbstractCossack", "AbstractDiver"],
        "new_flags": ["HasDive"],
        "remove_unittypes": [],
        "remove_flags": [],
    },
    "sources": {
        "proto_sources": DataSource("scripts/source/protoy.xml", "data/protomods.xml").as_list(),
        "ability_sources": DataSource("scripts/source/abilities/abilities.xml", "data/abilities/abilitymods.xml").as_list(),
        "tactic_sources": ["scripts/source/tactics/", "data/tactics/"],
        "sound_sources": ["scripts/source/sound/", "sound/"],
        # The spec mentions using data/anim as source for anim cloning
        "anim_sources": ["data/anim/"],
    },
    # Starting string id for scripts/new_data/stringmods.xml
    "starting_string_id": 90000,
}


def main() -> None:
    # Ensure output directories exist
    ensure_dirs([
        "scripts/new_data/",
        "scripts/new_data/abilities/",
        "scripts/new_data/tactics/",
        "scripts/new_sounds/",
        "scripts/new_art/",
    ])

    OutputHandler.info("Starting Unit Creator pipeline")

    # Build strings first and expose IDs to downstream cloners
    string_ids = StringCloner(CONFIG).process()
    CONFIG["string_ids"] = string_ids
    if string_ids:
        OutputHandler.info("Generated string IDs and wrote scripts/new_data/stringmods.xml")

    unit_cloner = UnitCloner(CONFIG)
    unit_info = unit_cloner.clone()
    OutputHandler.info("Wrote unit to scripts/new_data/protomods.xml")

    try:
        AbilityCloner(CONFIG, unit_info).process()
    except Exception as e:
        OutputHandler.cloner_error("AbilityCloner", e)

    try:
        TacticCloner(CONFIG, unit_info).process()
    except Exception as e:
        OutputHandler.cloner_error("TacticCloner", e)

    try:
        SoundCloner(CONFIG, unit_info).process()
    except Exception as e:
        OutputHandler.cloner_error("SoundCloner", e)

    try:
        AnimCloner(CONFIG, unit_info).process()
    except Exception as e:
        OutputHandler.cloner_error("AnimCloner", e)

    try:
        ActionCloner(CONFIG, unit_info).process()
    except Exception as e:
        OutputHandler.cloner_error("ActionCloner", e)

    OutputHandler.summary()


if __name__ == "__main__":
    main()
