# Unit Creator

The unit creator is a script which allows to create a new protounit based on a combination of existing units.

## Usage

To use the unit creator, you need to run the main.py script with the following values:

### Values defined in main.py

#### Units
- proto_name (str): The name of the new unit
- ptroto_base (str): The base unit of the new unit

#### Parameters
- new parameters: 
    - new_name (str): The name of the new unit, automatically creates a string in scripts/new_data/stringmods.xml and gets it's id as <displaynameid>
    - new_editor_name (str): automatically creates a string in scripts/new_data/stringmods.xml and gets it's id as <editornameid>
    - new_rollover (str): automatically creates a string in scripts/new_data/stringmods.xml and gets it's id as <rollovertextid>
    - new_shortrollover (str): automatically creates a string in scripts/new_data/stringmods.xml and gets it's id as <shortrollovertextid>
    - sound_unit (str): Unit used for creating a new sound file in 
    - abilities (list[str]): list of unit abilities
    - HP (int): new unit max <maxhitpoints> and <initialhitpoints>
    - velocity (int): new unit <maxvelocity> and <maxrunvelocity> = <maxvelocity> * 1.25
    - LOS (int): new unit <los>
    - icon (str): new unit <icon>
    - animfile (str): new unit <animfile>
    - generate_anim_file (bool): if true, a new anim file is created in scripts/new_art/... (then uses a file path defined in animfile)
    - anim_to_clone: anim file used as a base for generating new anim file. Uses data/anim as source. Works only if generate_anim_file is true
    - portraiticon (str): new unit <portraiticon>
    - buildlimit (int): new unit <buildlimit>
    - subciv (str): new unit <subciv>
    - new_tactics (str): new unit <tactics>
    - generate_tactics_file (bool): if true, a new tactics file is created in scripts/new_data/tactics
    - tactics_to_clone: tactics file used as a base for generating new tactics file. Uses data/tactics as source. Works only if generate_tactics_file is true
    - sharedbuildlimit (bool): if true, the new unit will use <flag>UseSharedBuildLimit</flag>
    - shared_main (bool): if false, the new unit needs a main_unit_name parameter
    - main_unit_name (str): name of the main unit for shared build limit, only if shared_main is false. defines <sharedbuildlimitunit>{main_unit_name}</sharedbuildlimitunit>
    - shared_buildlimit_units (list[str]): list of units to be used for shared build limit, only if sharedbuildlimit is true. defines <sharedbuildlimitunittypes>
    - shared_selection_units (list[str]): list of units to be used for shared selection, defines <sharedselectionunittypes>
    - add_proto_actions (list[dict]): list of actions to be added to the new unit, defines <protoaction> it's defined as:
        - name (str): name of the action
        - clonefrom (int): protounit to get the action from
    - remove_proto_actions (list[str]): list of actions to be removed from the new unit, defines <protoaction> it's defined as:
        - name (str): name of the action
    - new_unittypes (list[str]): list of unit types to be used for the new unit, defines <unittype>
    - new_flags (list[str]): list of flags to be used for the new unit, defines <flag>
    - remove_unittypes (list[str]): list of unit types to be removed from the new unit, defines <unittype>
    - remove_flags (list[str]): list of flags to be removed from the new unit, defines <flag>

#### Sources
- proto_sources (list[str]): source files to check for units. 
    - Source files are always two and by default are set up as scripts/source/protoy.xml and data/protomods.xml
    - primary source file is always scripts/source/protoy.xml (read as first)
    - secondary source file is always data/protomods.xml (read as second)
- ability_sources (list[str]): source files to check for abilities. 
    - Source files are always two and by default are set up as scripts/source/abilities/abilities.xml and data/abilities/abilitymods.xml
    - primary source file is always scripts/source/abilities/abilities.xml (read as first)
    - secondary source file is always data/abilities/abilitymods.xml (read as second)
- tactic_sources (list[str]): source folders to check for tactics. 
    - Source folders are always two and by default are set up as scripts/source/tactics/ and data/tactics/
    - primary source folder is always scripts/source/tactics/ (read as first)
    - secondary source folder is always data/tactics/ (read as second)
- sound_sources (list[str]): source folders to check for sounds. 
    - Source folders are always two and by default are set up as scripts/source/sound/ and sounds/
    - primary source folder is always scripts/source/sound/ (read as first)
    - secondary source folder is always sound/ (read as second)

## Behaviour

### Default values
- when no or only some new parameters are defined, then the unit uses the base unit's parameters

### Abimities
- when the unit has abilities (either newly defined or taken from base unit), then the unit uses the abilities from the base unit
- Process:
    - while creating a new unit, check ability_sources if the given ptroto_base has abilities or not. If so, then clone these abilities into a new file in scripts/new_data/abilities/abilitymods.xml with the given new proto_name using snakecase
    - if the unit has some newly defined abilities, then add these new abilities bellow the cloned abilities as <ability>AbilityName<rof>60</rof></ability>. Before you do so, please check ability_sources if the given AbilityName is already used or not. If not, you can clone it but raise an exception: "Ability not found in abilities.xml. Please define a new ability."

### Tactics
- when the unit uses new_tactics then check generate_tactics_file, if it's true then create a new file in scripts/new_data/tactics/ using new_tactics as a name and tactics_to_clone as a source (source to clone should be found in one of the tactic_sources). If the source is not found, then raise an exception: "Not able to find source for tactics_to_clone"

### Sounds
- when the unit doesn't use sound_unit parameter, then clone sounds from the base unit. You can do it by checking sound_sources to find a propper sound file defined as: unitname_snds.xml.
- if sound_unit has a value, then clone sounds from the sound_unit.
- cloned sounds should:
    - contain <protounit name="{NewUnitName}">
    - be placed in scripts/new_sounds/

### Animations
- when the unit doesn't use animfile parameter, then clone animations from the base unit. 
- if generate_anim_file is true, then create a new anim file into scripts/new_art/... using anim_to_clone as a source (source to clone should be found in one of the anim_sources). If the source is not found, then raise an exception: "Not able to find source for anim_to_clone"
- anim_to_clone contains the whole relative path, so whole cloning, please respect the given folder structure

### Actions
- when the unit uses add_proto_actions, then clone actions from clonefrom unit defined in proto_sources
- when clonefrom unit is not defines then raise an exception: "clonefrom unit is not defined"
- when the proto_action name is not defined within the clonefrom protounit then raise an exception: "Not able to find action defined for the clonefrom unit"
- remove_proto_actions: remove actions from the new unit

### Unit types and flags
- when the unit uses new_unittypes, then add these unit types to the new unit
- when the unit uses remove_unittypes, then remove these unit types from the new unit
- when the unit uses new_flags, then add these flags to the new unit
- when the unit uses remove_flags, then remove these flags from the new unit

### data Sources
- primary data source is always scanned as first, secondary data source is always scanned as second
- when there are duplicities in primary and secondary data sources and some protounit is defined twice, then create two protounits with the same name and raise an exception: "Duplicity found in data sources"
- every new parameters should be then applied just for the first protounit

### Code structure
- scripts/unit_creator/main.py - main wrapper containing the parameters to be changed
- scripts/unit_creator/unit_cloner.py - main cloner file containing logic about the unit and it's cloning
- scripts/unit_creator/ability_cloner.py - specific cloner file containing logic about the abilities and it's cloning
- scripts/unit_creator/tactic_cloner.py - specific cloner file containing logic about the tactics and it's cloning
- scripts/unit_creator/sound_cloner.py - specific cloner file containing logic about the sounds and it's cloning
- scripts/unit_creator/anim_cloner.py - specific cloner file containing logic about the animations and it's cloning
- scripts/unit_creator/action_cloner.py - specific cloner file containing logic about the actions and it's cloning






