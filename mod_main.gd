# mod_main.gd — Arenas mod entry point.
#
# Registers all script extensions that override base game systems, loads user
# config from the mod loader, and injects translation strings for the arena
# shape names and descriptions in 11 languages.
#
# Script extensions registered (in load order):
#   1. zone_service.gd     — shape-aware positioning and zone setup
#   2. my_tile_map_limits   — custom collision walls for non-rect shapes
#   3. my_tile_map.gd      — tile fill, visuals, damage, and navigation
#   4. entity_spawner.gd   — shape-aware enemy/item spawning
#   5. run_options_panel    — arena shape dropdown in run options UI
#   6. entity_birth.gd     — Curse Run spawn cancellation bypass

extends Node

const MOD_DIR = "PapiLeem-Arenas"
const MOD_LOG = "PapiLeem-Arenas"

var mod_dir_path := ""
var ext_dir := ""


func _init():
	ModLoaderLog.info("Init", MOD_LOG)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	ext_dir = mod_dir_path.plus_file("extensions")

	# Install script extensions — order matters: zone_service must be first
	# so arena_shape is set up before tile map and spawner init
	ModLoaderMod.install_script_extension(ext_dir + "/singletons/zone_service.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/my_tile_map_limits.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/my_tile_map.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/entity_spawner.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/ui/menus/run/run_options_panel.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/entities/birth/entity_birth.gd")


func _ready():
	_add_translations()
	_migrate_shape_ids()
	_load_config()
	ModLoaderLog.info("Ready", MOD_LOG)


# One-time migration: Random moved from id 8 to its new id (SHAPE_RANDOM) when new
# concrete shapes (ids 8+) were added. A pre-update save storing 8 meant "Random"
# but now means a concrete shape, so remap it to the current Random id. Guarded by
# a schema version so it only runs once.
const ArenaShapeClass = preload("res://mods-unpacked/PapiLeem-Arenas/arena_shapes/arena_shape.gd")
const SHAPE_ID_SCHEMA = 2
const OLD_RANDOM_ID = 8

func _migrate_shape_ids():
	var schema = 0
	if ProgressData.settings.has("arena_shape_id_schema"):
		schema = int(ProgressData.settings.arena_shape_id_schema)
	if schema >= SHAPE_ID_SCHEMA:
		return

	# Old Random (8) → new Random (15) for the persisted selection
	if ProgressData.settings.has("arena_shape_selected") \
			and int(ProgressData.settings.arena_shape_selected) == OLD_RANDOM_ID:
		ProgressData.settings["arena_shape_selected"] = ArenaShapeClass.SHAPE_RANDOM

	# Clear a stale per-run cache that pointed at old Random so it re-rolls cleanly
	if ProgressData.settings.has("arena_random_run_resolved") \
			and int(ProgressData.settings.arena_random_run_resolved) == OLD_RANDOM_ID:
		ProgressData.settings["arena_random_run_resolved"] = -1

	ProgressData.settings["arena_shape_id_schema"] = SHAPE_ID_SCHEMA
	ModLoaderLog.info("Migrated arena shape ids to schema " + str(SHAPE_ID_SCHEMA), MOD_LOG)


# Load user-configurable settings from the mod's config_schema in manifest.json.
# Supported keys:
#   default_arena_shape (int 0-7)  — pre-selected shape in the dropdown
#   shrinking_min_scale (float)    — how small Closing Storm arena gets
#   shrinking_speed (float)        — how fast it shrinks
#   default_random_per_run (bool)  — Random rerolls per run (true) or per wave (false)
func _load_config():
	var config = ModLoaderConfig.get_current_config(MOD_DIR)
	if config and config.data:
		var default_shape = int(config.data.get("default_arena_shape", 0))
		ZoneService.arena_shape_id = default_shape
		ZoneService.arena_shrinking_min_scale = config.data.get("shrinking_min_scale", 0.4)
		ZoneService.arena_shrinking_speed = config.data.get("shrinking_speed", 1.0)
		ZoneService.arena_meteor_interval = config.data.get("meteor_interval", 1.6)
		ZoneService.arena_meteor_max_active = int(config.data.get("meteor_max_active", 3))

		# Random reroll mode default (true = once per run, false = each wave).
		# Only sets the ZoneService fallback — the resolver and UI both fall back
		# to this when ProgressData has no saved value yet, so no seeding needed.
		ZoneService.arena_random_per_run = bool(config.data.get("default_random_per_run", true))

		ModLoaderLog.info("Config loaded - default shape: " + str(default_shape), MOD_LOG)


# Register translation strings for all arena shape names and descriptions.
# Each locale gets a Translation resource added to TranslationServer.
# Keys follow the pattern ARENA_<SHAPE> for names and ARENA_SHAPE_DESC_<SHAPE>
# for descriptions — these are looked up by run_options_panel.gd via tr().
func _add_translations():
	var translations = {
		"en": {
			"ARENA_SHAPE": "Arena Shape",
			"ARENA_RECTANGLE": "Default",
			"ARENA_CIRCLE": "Circle",
			"ARENA_HEXAGON": "Hexagon",
			"ARENA_CURSE_RUN": "Curse Run",
			"ARENA_SHRINKING": "Closing Storm",
			"ARENA_MAZE": "Maze",
			"ARENA_MULTIROOM": "Caves",
			"ARENA_HAZARD": "Hazard Zones",
			"ARENA_ROAMING_HAZARD": "Roaming Hazards",
			"ARENA_METEOR": "Meteor Shower",
			"ARENA_SAFE_ZONE": "Safe Zone",
			"ARENA_RANDOM": "Random",
			"ARENA_SHAPE_DESC_RECTANGLE": "Standard arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Circular arena - no corners to hide in",
			"ARENA_SHAPE_DESC_HEXAGON": "Six-sided arena with flat edges",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Run right or die - curse wall chases you",
			"ARENA_SHAPE_DESC_SHRINKING": "A deadly storm closes in - battle royale style",
			"ARENA_SHAPE_DESC_MAZE": "Procedural maze - different layout every wave",
			"ARENA_SHAPE_DESC_MULTIROOM": "Caves connected by tunnels",
			"ARENA_SHAPE_DESC_HAZARD": "Curse clouds that damage you on contact",
			"ARENA_SHAPE_DESC_ROAMING_HAZARD": "Roaming curse clouds drift around the arena",
			"ARENA_SHAPE_DESC_METEOR": "Meteors rain down - get off the marked spot",
			"ARENA_SHAPE_DESC_SAFE_ZONE": "Stay in the moving safe zone or take damage",
			"ARENA_SHAPE_DESC_RANDOM": "Random arena shape each wave",
			"ARENA_RANDOM_POOL": "Random Pool",
			"ARENA_REROLL_PER_WAVE": "Re-roll each wave",
			"ARENA_REROLL_PER_RUN": "Once per run",
			"ARENA_RANDOM_SETTINGS": "Random Settings",
			"ARENA_SELECT_ALL": "Select All",
			"ARENA_SELECT_NONE": "Clear",
			"ARENA_DONE": "Done",
			"ARENA_REROLL_HEADING": "New arena each:",
			"ARENA_REROLL_OPT_WAVE": "Wave",
			"ARENA_REROLL_OPT_RUN": "Run",
			"ARENA_REROLL_DESC": "Wave = fresh arena every wave. Run = one random arena for the whole run.",
		},
		"fr": {
			"ARENA_SHAPE": "Forme de l'arene",
			"ARENA_RECTANGLE": "Defaut",
			"ARENA_CIRCLE": "Cercle",
			"ARENA_HEXAGON": "Hexagone",
			"ARENA_CURSE_RUN": "Course Maudite",
			"ARENA_SHRINKING": "Tempete Imminente",
			"ARENA_MAZE": "Labyrinthe",
			"ARENA_MULTIROOM": "Multi-Salles",
			"ARENA_HAZARD": "Zones Danger",
			"ARENA_RANDOM": "Aleatoire",
			"ARENA_SHAPE_DESC_RECTANGLE": "Arene standard",
			"ARENA_SHAPE_DESC_CIRCLE": "Arene circulaire - pas de coins pour se cacher",
			"ARENA_SHAPE_DESC_HEXAGON": "Arene a six cotes avec des bords plats",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Courez a droite ou mourez - le mur de mort vous poursuit",
			"ARENA_SHAPE_DESC_SHRINKING": "Une tempete mortelle se referme - style battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labyrinthe procedural - disposition differente a chaque vague",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salles reliees par des passages",
			"ARENA_SHAPE_DESC_HAZARD": "Nuages maudits qui vous blessent au contact",
			"ARENA_SHAPE_DESC_RANDOM": "Forme d'arene aleatoire a chaque vague",
			"ARENA_RANDOM_POOL": "Pool aleatoire",
			"ARENA_REROLL_PER_WAVE": "Relancer chaque vague",
			"ARENA_REROLL_PER_RUN": "Une fois par partie",
			"ARENA_RANDOM_SETTINGS": "Reglages aleatoires",
			"ARENA_SELECT_ALL": "Tout selectionner",
			"ARENA_SELECT_NONE": "Effacer",
			"ARENA_DONE": "Termine",
			"ARENA_REROLL_HEADING": "Nouvelle arene :",
			"ARENA_REROLL_OPT_WAVE": "Vague",
			"ARENA_REROLL_OPT_RUN": "Partie",
			"ARENA_REROLL_DESC": "Vague = nouvelle arene a chaque vague. Partie = une arene pour toute la partie.",
		},
		"es": {
			"ARENA_SHAPE": "Forma de la arena",
			"ARENA_RECTANGLE": "Predeterminado",
			"ARENA_CIRCLE": "Circulo",
			"ARENA_HEXAGON": "Hexagono",
			"ARENA_CURSE_RUN": "Carrera Maldita",
			"ARENA_SHRINKING": "Tormenta Inminente",
			"ARENA_MAZE": "Laberinto",
			"ARENA_MULTIROOM": "Multi-Sala",
			"ARENA_HAZARD": "Zonas Peligro",
			"ARENA_RANDOM": "Aleatorio",
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena estandar",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circular - sin esquinas donde esconderse",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena de seis lados con bordes planos",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corre a la derecha o muere - el muro mortal te persigue",
			"ARENA_SHAPE_DESC_SHRINKING": "Una tormenta mortal se cierra - estilo battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Laberinto procedural - diseno diferente en cada oleada",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salas conectadas por puertas",
			"ARENA_SHAPE_DESC_HAZARD": "Nubes malditas que te danan al contacto",
			"ARENA_SHAPE_DESC_RANDOM": "Forma de arena aleatoria en cada oleada",
			"ARENA_RANDOM_POOL": "Grupo aleatorio",
			"ARENA_REROLL_PER_WAVE": "Re-tirar cada oleada",
			"ARENA_REROLL_PER_RUN": "Una vez por partida",
			"ARENA_RANDOM_SETTINGS": "Ajustes aleatorios",
			"ARENA_SELECT_ALL": "Seleccionar todo",
			"ARENA_SELECT_NONE": "Borrar",
			"ARENA_DONE": "Listo",
			"ARENA_REROLL_HEADING": "Nueva arena:",
			"ARENA_REROLL_OPT_WAVE": "Oleada",
			"ARENA_REROLL_OPT_RUN": "Partida",
			"ARENA_REROLL_DESC": "Oleada = nueva arena cada oleada. Partida = una arena para toda la partida.",
		},
		"de": {
			"ARENA_SHAPE": "Arena-Form",
			"ARENA_RECTANGLE": "Standard",
			"ARENA_CIRCLE": "Kreis",
			"ARENA_HEXAGON": "Sechseck",
			"ARENA_CURSE_RUN": "Fluchlauf",
			"ARENA_SHRINKING": "Nahender Sturm",
			"ARENA_MAZE": "Labyrinth",
			"ARENA_MULTIROOM": "Mehrraumig",
			"ARENA_HAZARD": "Gefahrenzonen",
			"ARENA_RANDOM": "Zufallig",
			"ARENA_SHAPE_DESC_RECTANGLE": "Standard-Arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Runde Arena - keine Ecken zum Verstecken",
			"ARENA_SHAPE_DESC_HEXAGON": "Sechseckige Arena mit flachen Kanten",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Renne nach rechts oder stirb - die Todeswand verfolgt dich",
			"ARENA_SHAPE_DESC_SHRINKING": "Ein todlicher Sturm schliesst sich - Battle-Royale-Stil",
			"ARENA_SHAPE_DESC_MAZE": "Prozedurales Labyrinth - anderes Layout jede Welle",
			"ARENA_SHAPE_DESC_MULTIROOM": "Raume verbunden durch Durchgange",
			"ARENA_SHAPE_DESC_HAZARD": "Fluchwolken die bei Kontakt Schaden verursachen",
			"ARENA_SHAPE_DESC_RANDOM": "Zufallige Arena-Form jede Welle",
			"ARENA_RANDOM_POOL": "Zufalls-Pool",
			"ARENA_REROLL_PER_WAVE": "Jede Welle neu wurfeln",
			"ARENA_REROLL_PER_RUN": "Einmal pro Durchlauf",
			"ARENA_RANDOM_SETTINGS": "Zufalls-Einstellungen",
			"ARENA_SELECT_ALL": "Alle auswahlen",
			"ARENA_SELECT_NONE": "Loschen",
			"ARENA_DONE": "Fertig",
			"ARENA_REROLL_HEADING": "Neue Arena:",
			"ARENA_REROLL_OPT_WAVE": "Welle",
			"ARENA_REROLL_OPT_RUN": "Lauf",
			"ARENA_REROLL_DESC": "Welle = neue Arena jede Welle. Lauf = eine Arena fur den ganzen Lauf.",
		},
		"ru": {
			"ARENA_SHAPE": "\u0424\u043e\u0440\u043c\u0430 \u0430\u0440\u0435\u043d\u044b",
			"ARENA_RECTANGLE": "\u0421\u0442\u0430\u043d\u0434\u0430\u0440\u0442",
			"ARENA_CIRCLE": "\u041a\u0440\u0443\u0433",
			"ARENA_HEXAGON": "\u0428\u0435\u0441\u0442\u0438\u0443\u0433\u043e\u043b\u044c\u043d\u0438\u043a",
			"ARENA_CURSE_RUN": "\u041f\u0440\u043e\u043a\u043b\u044f\u0442\u044b\u0439 \u0431\u0435\u0433",
			"ARENA_SHRINKING": "\u041d\u0430\u0434\u0432\u0438\u0433\u0430\u044e\u0449\u0438\u0439\u0441\u044f \u0448\u0442\u043e\u0440\u043c",
			"ARENA_MAZE": "\u041b\u0430\u0431\u0438\u0440\u0438\u043d\u0442",
			"ARENA_MULTIROOM": "\u041c\u043d\u043e\u0433\u043e\u043a\u043e\u043c\u043d\u0430\u0442\u043d\u0430\u044f",
			"ARENA_HAZARD": "\u041e\u043f\u0430\u0441\u043d\u044b\u0435 \u0437\u043e\u043d\u044b",
			"ARENA_RANDOM": "\u0421\u043b\u0443\u0447\u0430\u0439\u043d\u043e",
			"ARENA_SHAPE_DESC_RECTANGLE": "\u0421\u0442\u0430\u043d\u0434\u0430\u0440\u0442\u043d\u0430\u044f \u0430\u0440\u0435\u043d\u0430",
			"ARENA_SHAPE_DESC_CIRCLE": "\u041a\u0440\u0443\u0433\u043b\u0430\u044f \u0430\u0440\u0435\u043d\u0430 - \u043d\u0435\u0433\u0434\u0435 \u0441\u043f\u0440\u044f\u0442\u0430\u0442\u044c\u0441\u044f \u0432 \u0443\u0433\u043b\u0430\u0445",
			"ARENA_SHAPE_DESC_HEXAGON": "\u0428\u0435\u0441\u0442\u0438\u0433\u0440\u0430\u043d\u043d\u0430\u044f \u0430\u0440\u0435\u043d\u0430 \u0441 \u043f\u043b\u043e\u0441\u043a\u0438\u043c\u0438 \u043a\u0440\u0430\u044f\u043c\u0438",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u0411\u0435\u0433\u0438 \u0432\u043f\u0440\u0430\u0432\u043e \u0438\u043b\u0438 \u0443\u043c\u0440\u0438 - \u0441\u0442\u0435\u043d\u0430 \u0441\u043c\u0435\u0440\u0442\u0438 \u043f\u0440\u0435\u0441\u043b\u0435\u0434\u0443\u0435\u0442 \u0442\u0435\u0431\u044f",
			"ARENA_SHAPE_DESC_SHRINKING": "\u0421\u043c\u0435\u0440\u0442\u0435\u043b\u044c\u043d\u044b\u0439 \u0448\u0442\u043e\u0440\u043c \u043d\u0430\u0434\u0432\u0438\u0433\u0430\u0435\u0442\u0441\u044f - \u0441\u0442\u0438\u043b\u044c \u0431\u0430\u0442\u043b \u0440\u043e\u044f\u043b\u044c",
			"ARENA_SHAPE_DESC_MAZE": "\u041f\u0440\u043e\u0446\u0435\u0434\u0443\u0440\u043d\u044b\u0439 \u043b\u0430\u0431\u0438\u0440\u0438\u043d\u0442 - \u043d\u043e\u0432\u0430\u044f \u043f\u043b\u0430\u043d\u0438\u0440\u043e\u0432\u043a\u0430 \u043a\u0430\u0436\u0434\u0443\u044e \u0432\u043e\u043b\u043d\u0443",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u041a\u043e\u043c\u043d\u0430\u0442\u044b \u0441\u043e\u0435\u0434\u0438\u043d\u0435\u043d\u043d\u044b\u0435 \u043f\u0440\u043e\u0445\u043e\u0434\u0430\u043c\u0438",
			"ARENA_SHAPE_DESC_HAZARD": "\u041f\u0440\u043e\u043a\u043b\u044f\u0442\u044b\u0435 \u043e\u0431\u043b\u0430\u043a\u0430 \u043d\u0430\u043d\u043e\u0441\u044f\u0449\u0438\u0435 \u0443\u0440\u043e\u043d \u043f\u0440\u0438 \u043a\u043e\u043d\u0442\u0430\u043a\u0442\u0435",
			"ARENA_SHAPE_DESC_RANDOM": "\u0421\u043b\u0443\u0447\u0430\u0439\u043d\u0430\u044f \u0444\u043e\u0440\u043c\u0430 \u0430\u0440\u0435\u043d\u044b \u043a\u0430\u0436\u0434\u0443\u044e \u0432\u043e\u043b\u043d\u0443",
			"ARENA_RANDOM_POOL": "\u0421\u043b\u0443\u0447\u0430\u0439\u043d\u044b\u0439 \u043f\u0443\u043b",
			"ARENA_REROLL_PER_WAVE": "\u041c\u0435\u043d\u044f\u0442\u044c \u043a\u0430\u0436\u0434\u0443\u044e \u0432\u043e\u043b\u043d\u0443",
			"ARENA_REROLL_PER_RUN": "\u041e\u0434\u0438\u043d \u0440\u0430\u0437 \u0437\u0430 \u0437\u0430\u0431\u0435\u0433",
			"ARENA_RANDOM_SETTINGS": "\u0421\u043b\u0443\u0447\u0430\u0439\u043d\u044b\u0435 \u043d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438",
			"ARENA_SELECT_ALL": "\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u0432\u0441\u0435",
			"ARENA_SELECT_NONE": "\u041e\u0447\u0438\u0441\u0442\u0438\u0442\u044c",
			"ARENA_DONE": "\u0413\u043e\u0442\u043e\u0432\u043e",
			"ARENA_REROLL_HEADING": "\u041d\u043e\u0432\u0430\u044f \u0430\u0440\u0435\u043d\u0430:",
			"ARENA_REROLL_OPT_WAVE": "\u0412\u043e\u043b\u043d\u0430",
			"ARENA_REROLL_OPT_RUN": "\u0417\u0430\u0431\u0435\u0433",
			"ARENA_REROLL_DESC": "\u0412\u043e\u043b\u043d\u0430 = \u043d\u043e\u0432\u0430\u044f \u0430\u0440\u0435\u043d\u0430 \u043a\u0430\u0436\u0434\u0443\u044e \u0432\u043e\u043b\u043d\u0443. \u0417\u0430\u0431\u0435\u0433 = \u043e\u0434\u043d\u0430 \u0430\u0440\u0435\u043d\u0430 \u043d\u0430 \u0432\u0435\u0441\u044c \u0437\u0430\u0431\u0435\u0433.",
		},
		"pt": {
			"ARENA_SHAPE": "Forma da arena",
			"ARENA_RECTANGLE": "Padrao",
			"ARENA_CIRCLE": "Circulo",
			"ARENA_HEXAGON": "Hexagono",
			"ARENA_CURSE_RUN": "Corrida Maldita",
			"ARENA_SHRINKING": "Tempestade Iminente",
			"ARENA_MAZE": "Labirinto",
			"ARENA_MULTIROOM": "Multi-Sala",
			"ARENA_HAZARD": "Zonas Perigo",
			"ARENA_RANDOM": "Aleatorio",
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena padrao",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circular - sem cantos para se esconder",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena de seis lados com bordas planas",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corra para a direita ou morra - o muro mortal te persegue",
			"ARENA_SHAPE_DESC_SHRINKING": "Uma tempestade mortal se fecha - estilo battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labirinto procedural - layout diferente a cada onda",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salas conectadas por passagens",
			"ARENA_SHAPE_DESC_HAZARD": "Nuvens amaldicoadas que causam dano ao contato",
			"ARENA_SHAPE_DESC_RANDOM": "Forma de arena aleatoria a cada onda",
			"ARENA_RANDOM_POOL": "Pool aleatorio",
			"ARENA_REROLL_PER_WAVE": "Re-sortear a cada onda",
			"ARENA_REROLL_PER_RUN": "Uma vez por partida",
			"ARENA_RANDOM_SETTINGS": "Config. aleatorias",
			"ARENA_SELECT_ALL": "Selecionar tudo",
			"ARENA_SELECT_NONE": "Limpar",
			"ARENA_DONE": "Concluido",
			"ARENA_REROLL_HEADING": "Nova arena:",
			"ARENA_REROLL_OPT_WAVE": "Onda",
			"ARENA_REROLL_OPT_RUN": "Partida",
			"ARENA_REROLL_DESC": "Onda = nova arena a cada onda. Partida = uma arena para toda a partida.",
		},
		"pl": {
			"ARENA_SHAPE": "Ksztalt areny",
			"ARENA_RECTANGLE": "Domyslny",
			"ARENA_CIRCLE": "Kolo",
			"ARENA_HEXAGON": "Szesciokat",
			"ARENA_CURSE_RUN": "Przeklety Bieg",
			"ARENA_SHRINKING": "Nadciagajaca Burza",
			"ARENA_MAZE": "Labirynt",
			"ARENA_MULTIROOM": "Wielopokoj",
			"ARENA_HAZARD": "Strefy Zagrozenia",
			"ARENA_RANDOM": "Losowy",
			"ARENA_SHAPE_DESC_RECTANGLE": "Standardowa arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Okragla arena - bez katow do ukrycia",
			"ARENA_SHAPE_DESC_HEXAGON": "Szesciokotna arena z plaskimi krawedziami",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Biegnij w prawo lub zgin - sciana smierci cie sciga",
			"ARENA_SHAPE_DESC_SHRINKING": "Smiercionosna burza nadciaga - styl battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Proceduralny labirynt - inny uklad w kazdej fali",
			"ARENA_SHAPE_DESC_MULTIROOM": "Pokoje polaczone przejsciami",
			"ARENA_SHAPE_DESC_HAZARD": "Przeklete chmury zadajace obrazenia przy kontakcie",
			"ARENA_SHAPE_DESC_RANDOM": "Losowy ksztalt areny w kazdej fali",
			"ARENA_RANDOM_POOL": "Pula losowa",
			"ARENA_REROLL_PER_WAVE": "Losuj co fale",
			"ARENA_REROLL_PER_RUN": "Raz na rozgrywke",
			"ARENA_RANDOM_SETTINGS": "Ustawienia losowe",
			"ARENA_SELECT_ALL": "Zaznacz wszystko",
			"ARENA_SELECT_NONE": "Wyczysc",
			"ARENA_DONE": "Gotowe",
			"ARENA_REROLL_HEADING": "Nowa arena:",
			"ARENA_REROLL_OPT_WAVE": "Fala",
			"ARENA_REROLL_OPT_RUN": "Gra",
			"ARENA_REROLL_DESC": "Fala = nowa arena co fale. Gra = jedna arena na cala gre.",
		},
		"it": {
			"ARENA_SHAPE": "Forma dell'arena",
			"ARENA_RECTANGLE": "Predefinito",
			"ARENA_CIRCLE": "Cerchio",
			"ARENA_HEXAGON": "Esagono",
			"ARENA_CURSE_RUN": "Corsa Maledetta",
			"ARENA_SHRINKING": "Tempesta Imminente",
			"ARENA_MAZE": "Labirinto",
			"ARENA_MULTIROOM": "Multi-Stanza",
			"ARENA_HAZARD": "Zone Pericolo",
			"ARENA_RANDOM": "Casuale",
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena standard",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circolare - nessun angolo dove nascondersi",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena a sei lati con bordi piatti",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corri a destra o muori - il muro mortale ti insegue",
			"ARENA_SHAPE_DESC_SHRINKING": "Una tempesta mortale si chiude - stile battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labirinto procedurale - layout diverso ogni ondata",
			"ARENA_SHAPE_DESC_MULTIROOM": "Stanze collegate da passaggi",
			"ARENA_SHAPE_DESC_HAZARD": "Nubi maledette che danneggiano al contatto",
			"ARENA_SHAPE_DESC_RANDOM": "Forma arena casuale ogni ondata",
			"ARENA_RANDOM_POOL": "Pool casuale",
			"ARENA_REROLL_PER_WAVE": "Ri-estrai ogni ondata",
			"ARENA_REROLL_PER_RUN": "Una volta per partita",
			"ARENA_RANDOM_SETTINGS": "Impostazioni casuali",
			"ARENA_SELECT_ALL": "Seleziona tutto",
			"ARENA_SELECT_NONE": "Cancella",
			"ARENA_DONE": "Fatto",
			"ARENA_REROLL_HEADING": "Nuova arena:",
			"ARENA_REROLL_OPT_WAVE": "Ondata",
			"ARENA_REROLL_OPT_RUN": "Partita",
			"ARENA_REROLL_DESC": "Ondata = nuova arena ogni ondata. Partita = una arena per tutta la partita.",
		},
		"tr": {
			"ARENA_SHAPE": "Arena Sekli",
			"ARENA_RECTANGLE": "Varsayilan",
			"ARENA_CIRCLE": "Daire",
			"ARENA_HEXAGON": "Altigen",
			"ARENA_CURSE_RUN": "Lanet Kosusu",
			"ARENA_SHRINKING": "Yaklasan Firtina",
			"ARENA_MAZE": "Labirent",
			"ARENA_MULTIROOM": "Cok Odali",
			"ARENA_HAZARD": "Tehlike Bolgeleri",
			"ARENA_RANDOM": "Rastgele",
			"ARENA_SHAPE_DESC_RECTANGLE": "Standart arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Dairesel arena - saklanacak kose yok",
			"ARENA_SHAPE_DESC_HEXAGON": "Duz kenarlari olan alti koseli arena",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Saga kos ya da ol - olum duvari seni kovalıyor",
			"ARENA_SHAPE_DESC_SHRINKING": "Olumcul bir firtina kapaniyor - battle royale tarzi",
			"ARENA_SHAPE_DESC_MAZE": "Prosedural labirent - her dalgada farkli duzenleme",
			"ARENA_SHAPE_DESC_MULTIROOM": "Gecitlerle baglanan odalar",
			"ARENA_SHAPE_DESC_HAZARD": "Temasta hasar veren lanet bulutlari",
			"ARENA_SHAPE_DESC_RANDOM": "Her dalgada rastgele arena sekli",
			"ARENA_RANDOM_POOL": "Rastgele Havuz",
			"ARENA_REROLL_PER_WAVE": "Her dalgada yeniden sec",
			"ARENA_REROLL_PER_RUN": "Tur basina bir kez",
			"ARENA_RANDOM_SETTINGS": "Rastgele Ayarlar",
			"ARENA_SELECT_ALL": "Tumunu sec",
			"ARENA_SELECT_NONE": "Temizle",
			"ARENA_DONE": "Tamam",
			"ARENA_REROLL_HEADING": "Yeni arena:",
			"ARENA_REROLL_OPT_WAVE": "Dalga",
			"ARENA_REROLL_OPT_RUN": "Tur",
			"ARENA_REROLL_DESC": "Dalga = her dalga yeni arena. Tur = tum tur boyunca tek arena.",
		},
		"zh": {
			"ARENA_SHAPE": "\u7ade\u6280\u573a\u5f62\u72b6",
			"ARENA_RECTANGLE": "\u9ed8\u8ba4",
			"ARENA_CIRCLE": "\u5706\u5f62",
			"ARENA_HEXAGON": "\u516d\u8fb9\u5f62",
			"ARENA_CURSE_RUN": "\u8bc5\u5492\u4e4b\u8dd1",
			"ARENA_SHRINKING": "\u98ce\u66b4\u6765\u88ad",
			"ARENA_MAZE": "\u8ff7\u5bab",
			"ARENA_MULTIROOM": "\u591a\u623f\u95f4",
			"ARENA_HAZARD": "\u5371\u9669\u533a",
			"ARENA_RANDOM": "\u968f\u673a",
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6807\u51c6\u7ade\u6280\u573a",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5706\u5f62\u7ade\u6280\u573a - \u65e0\u5904\u85cf\u8eab",
			"ARENA_SHAPE_DESC_HEXAGON": "\u516d\u8fb9\u5f62\u7ade\u6280\u573a\uff0c\u8fb9\u7f18\u5e73\u5766",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u5411\u53f3\u8dd1\u6216\u8005\u6b7b - \u6b7b\u4ea1\u4e4b\u5899\u8ffd\u9010\u4f60",
			"ARENA_SHAPE_DESC_SHRINKING": "\u81f4\u547d\u98ce\u66b4\u6b63\u5728\u903c\u8fd1 - \u5927\u9003\u6740\u98ce\u683c",
			"ARENA_SHAPE_DESC_MAZE": "\u7a0b\u5e8f\u751f\u6210\u8ff7\u5bab - \u6bcf\u6ce2\u5e03\u5c40\u4e0d\u540c",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u8fc7\u95e8\u9053\u8fde\u63a5\u7684\u623f\u95f4",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89e6\u9020\u6210\u4f24\u5bb3\u7684\u8bc5\u5492\u4e91",
			"ARENA_SHAPE_DESC_RANDOM": "\u6bcf\u6ce2\u968f\u673a\u7ade\u6280\u573a\u5f62\u72b6",
			"ARENA_RANDOM_POOL": "\u968f\u673a\u6c60",
			"ARENA_REROLL_PER_WAVE": "\u6bcf\u6ce2\u91cd\u65b0\u968f\u673a",
			"ARENA_REROLL_PER_RUN": "\u6bcf\u5c40\u4e00\u6b21",
			"ARENA_RANDOM_SETTINGS": "\u968f\u673a\u8bbe\u7f6e",
			"ARENA_SELECT_ALL": "\u5168\u9009",
			"ARENA_SELECT_NONE": "\u6e05\u9664",
			"ARENA_DONE": "\u5b8c\u6210",
			"ARENA_REROLL_HEADING": "\u65b0\u7ade\u6280\u573a\uff1a",
			"ARENA_REROLL_OPT_WAVE": "\u6bcf\u6ce2",
			"ARENA_REROLL_OPT_RUN": "\u6bcf\u5c40",
			"ARENA_REROLL_DESC": "\u6bcf\u6ce2 = \u6bcf\u6ce2\u5237\u65b0\u7ade\u6280\u573a\u3002\u6bcf\u5c40 = \u6574\u5c40\u4f7f\u7528\u4e00\u4e2a\u968f\u673a\u7ade\u6280\u573a\u3002",
		},
		"zh_TW": {
			"ARENA_SHAPE": "\u7af6\u6280\u5834\u5f62\u72c0",
			"ARENA_RECTANGLE": "\u9810\u8a2d",
			"ARENA_CIRCLE": "\u5713\u5f62",
			"ARENA_HEXAGON": "\u516d\u908a\u5f62",
			"ARENA_CURSE_RUN": "\u8a5b\u5492\u4e4b\u8dd1",
			"ARENA_SHRINKING": "\u98a8\u66b4\u4f86\u8972",
			"ARENA_MAZE": "\u8ff7\u5bae",
			"ARENA_MULTIROOM": "\u591a\u623f\u9593",
			"ARENA_HAZARD": "\u5371\u96aa\u5340",
			"ARENA_RANDOM": "\u96a8\u6a5f",
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6a19\u6e96\u7af6\u6280\u5834",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5713\u5f62\u7af6\u6280\u5834 - \u7121\u8655\u85cf\u8eab",
			"ARENA_SHAPE_DESC_HEXAGON": "\u516d\u908a\u5f62\u7af6\u6280\u5834\uff0c\u908a\u7de3\u5e73\u5766",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u5411\u53f3\u8dd1\u6216\u8005\u6b7b - \u6b7b\u4ea1\u4e4b\u7246\u8ffd\u9010\u4f60",
			"ARENA_SHAPE_DESC_SHRINKING": "\u81f4\u547d\u98a8\u66b4\u6b63\u5728\u903c\u8fd1 - \u5927\u9003\u6bba\u98a8\u683c",
			"ARENA_SHAPE_DESC_MAZE": "\u7a0b\u5e8f\u751f\u6210\u8ff7\u5bae - \u6bcf\u6ce2\u4f48\u5c40\u4e0d\u540c",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u904e\u9580\u9053\u9023\u63a5\u7684\u623f\u9593",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89f8\u9020\u6210\u50b7\u5bb3\u7684\u8a5b\u5492\u96f2",
			"ARENA_SHAPE_DESC_RANDOM": "\u6bcf\u6ce2\u96a8\u6a5f\u7af6\u6280\u5834\u5f62\u72c0",
			"ARENA_RANDOM_POOL": "\u96a8\u6a5f\u6c60",
			"ARENA_REROLL_PER_WAVE": "\u6bcf\u6ce2\u91cd\u65b0\u96a8\u6a5f",
			"ARENA_REROLL_PER_RUN": "\u6bcf\u5c40\u4e00\u6b21",
			"ARENA_RANDOM_SETTINGS": "\u96a8\u6a5f\u8a2d\u5b9a",
			"ARENA_SELECT_ALL": "\u5168\u9078",
			"ARENA_SELECT_NONE": "\u6e05\u9664",
			"ARENA_DONE": "\u5b8c\u6210",
			"ARENA_REROLL_HEADING": "\u65b0\u7af6\u6280\u5834\uff1a",
			"ARENA_REROLL_OPT_WAVE": "\u6bcf\u6ce2",
			"ARENA_REROLL_OPT_RUN": "\u6bcf\u5c40",
			"ARENA_REROLL_DESC": "\u6bcf\u6ce2 = \u6bcf\u6ce2\u5237\u65b0\u7af6\u6280\u5834\u3002\u6bcf\u5c40 = \u6574\u5c40\u4f7f\u7528\u4e00\u500b\u96a8\u6a5f\u7af6\u6280\u5834\u3002",
		},
		"ja": {
			"ARENA_SHAPE": "\u30a2\u30ea\u30fc\u30ca\u306e\u5f62",
			"ARENA_RECTANGLE": "\u30c7\u30d5\u30a9\u30eb\u30c8",
			"ARENA_CIRCLE": "\u5186\u5f62",
			"ARENA_HEXAGON": "\u516d\u89d2\u5f62",
			"ARENA_CURSE_RUN": "\u546a\u3044\u306e\u30e9\u30f3",
			"ARENA_SHRINKING": "\u8feb\u308a\u304f\u308b\u5d50",
			"ARENA_MAZE": "\u8ff7\u8def",
			"ARENA_MULTIROOM": "\u30de\u30eb\u30c1\u30eb\u30fc\u30e0",
			"ARENA_HAZARD": "\u5371\u967a\u30be\u30fc\u30f3",
			"ARENA_RANDOM": "\u30e9\u30f3\u30c0\u30e0",
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6a19\u6e96\u30a2\u30ea\u30fc\u30ca",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5186\u5f62\u30a2\u30ea\u30fc\u30ca - \u96a0\u308c\u308b\u89d2\u306a\u3057",
			"ARENA_SHAPE_DESC_HEXAGON": "\u5e73\u3089\u306a\u7e01\u306e\u516d\u89d2\u5f62\u30a2\u30ea\u30fc\u30ca",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u53f3\u306b\u8d70\u308c\u3001\u3055\u3082\u306a\u304f\u3070\u6b7b\u306c - \u6b7b\u306e\u58c1\u304c\u8ffd\u3063\u3066\u304f\u308b",
			"ARENA_SHAPE_DESC_SHRINKING": "\u6b7b\u306e\u5d50\u304c\u8feb\u308b - \u30d0\u30c8\u30ed\u30ef\u30a4\u30e4\u30eb\u30b9\u30bf\u30a4\u30eb",
			"ARENA_SHAPE_DESC_MAZE": "\u30d7\u30ed\u30b7\u30fc\u30b8\u30e3\u30eb\u8ff7\u8def - \u6bce\u30a6\u30a7\u30fc\u30d6\u7570\u306a\u308b\u30ec\u30a4\u30a2\u30a6\u30c8",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u8def\u3067\u3064\u306a\u304c\u3063\u305f\u90e8\u5c4b",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89e6\u3059\u308b\u3068\u30c0\u30e1\u30fc\u30b8\u3092\u53d7\u3051\u308b\u546a\u3044\u306e\u96f2",
			"ARENA_SHAPE_DESC_RANDOM": "\u6bce\u30a6\u30a7\u30fc\u30d6\u30e9\u30f3\u30c0\u30e0\u306a\u30a2\u30ea\u30fc\u30ca\u5f62\u72b6",
			"ARENA_RANDOM_POOL": "\u30e9\u30f3\u30c0\u30e0\u30d7\u30fc\u30eb",
			"ARENA_REROLL_PER_WAVE": "\u6bce\u30a6\u30a7\u30fc\u30d6\u518d\u62bd\u9078",
			"ARENA_REROLL_PER_RUN": "\u30e9\u30f3\u3054\u3068\u306b1\u56de",
			"ARENA_RANDOM_SETTINGS": "\u30e9\u30f3\u30c0\u30e0\u8a2d\u5b9a",
			"ARENA_SELECT_ALL": "\u3059\u3079\u3066\u9078\u629e",
			"ARENA_SELECT_NONE": "\u30af\u30ea\u30a2",
			"ARENA_DONE": "\u5b8c\u4e86",
			"ARENA_REROLL_HEADING": "\u65b0\u3057\u3044\u30a2\u30ea\u30fc\u30ca\uff1a",
			"ARENA_REROLL_OPT_WAVE": "\u30a6\u30a7\u30fc\u30d6",
			"ARENA_REROLL_OPT_RUN": "\u30e9\u30f3",
			"ARENA_REROLL_DESC": "\u30a6\u30a7\u30fc\u30d6 = \u6bce\u30a6\u30a7\u30fc\u30d6\u66f4\u65b0\u3002\u30e9\u30f3 = \u30e9\u30f3\u5168\u4f53\u30671\u3064\u306e\u30e9\u30f3\u30c0\u30e0\u30a2\u30ea\u30fc\u30ca\u3002",
		},
		"ko": {
			"ARENA_SHAPE": "\uc544\ub808\ub098 \ubaa8\uc591",
			"ARENA_RECTANGLE": "\uae30\ubcf8",
			"ARENA_CIRCLE": "\uc6d0\ud615",
			"ARENA_HEXAGON": "\uc721\uac01\ud615",
			"ARENA_CURSE_RUN": "\uc800\uc8fc \ub2ec\ub9ac\uae30",
			"ARENA_SHRINKING": "\ub2e4\uac00\uc624\ub294 \ud3ed\ud48d",
			"ARENA_MAZE": "\ubbf8\ub85c",
			"ARENA_MULTIROOM": "\ub2e4\uc911 \ubc29",
			"ARENA_HAZARD": "\uc704\ud5d8 \uad6c\uc5ed",
			"ARENA_RANDOM": "\ubb34\uc791\uc704",
			"ARENA_SHAPE_DESC_RECTANGLE": "\ud45c\uc900 \uc544\ub808\ub098",
			"ARENA_SHAPE_DESC_CIRCLE": "\uc6d0\ud615 \uc544\ub808\ub098 - \uc228\uc744 \uad6c\uc11d\uc774 \uc5c6\uc74c",
			"ARENA_SHAPE_DESC_HEXAGON": "\ud3c9\ud3c9\ud55c \ubaa8\uc11c\ub9ac\uc758 \uc721\uac01\ud615 \uc544\ub808\ub098",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\uc624\ub978\ucabd\uc73c\ub85c \ub2ec\ub9ac\uac70\ub098 \uc8fd\uac70\ub098 - \uc8fd\uc74c\uc758 \ubcbd\uc774 \ucad3\uc544\uc628\ub2e4",
			"ARENA_SHAPE_DESC_SHRINKING": "\uce58\uba85\uc801\uc778 \ud3ed\ud48d\uc774 \ub2e4\uac00\uc628\ub2e4 - \ubc30\ud2c0\ub85c\uc58c \uc2a4\ud0c0\uc77c",
			"ARENA_SHAPE_DESC_MAZE": "\uc808\ucc28\uc801 \ubbf8\ub85c - \ub9e4 \uc6e8\uc774\ube0c\ub9c8\ub2e4 \ub2e4\ub978 \ub808\uc774\uc544\uc6c3",
			"ARENA_SHAPE_DESC_MULTIROOM": "\ud1b5\ub85c\ub85c \uc5f0\uacb0\ub41c \ubc29\ub4e4",
			"ARENA_SHAPE_DESC_HAZARD": "\uc811\ucd09 \uc2dc \ud53c\ud574\ub97c \uc8fc\ub294 \uc800\uc8fc \uad6c\ub984",
			"ARENA_SHAPE_DESC_RANDOM": "\ub9e4 \uc6e8\uc774\ube0c\ub9c8\ub2e4 \ubb34\uc791\uc704 \uc544\ub808\ub098 \ubaa8\uc591",
			"ARENA_RANDOM_POOL": "\ubb34\uc791\uc704 \ud480",
			"ARENA_REROLL_PER_WAVE": "\ub9e4 \uc6e8\uc774\ube0c \uc7ac\ucd94\ucca8",
			"ARENA_REROLL_PER_RUN": "\ud310\ub2f9 \ud55c \ubc88",
			"ARENA_RANDOM_SETTINGS": "\ubb34\uc791\uc704 \uc124\uc815",
			"ARENA_SELECT_ALL": "\ubaa8\ub450 \uc120\ud0dd",
			"ARENA_SELECT_NONE": "\uc9c0\uc6b0\uae30",
			"ARENA_DONE": "\uc644\ub8cc",
			"ARENA_REROLL_HEADING": "\uc0c8 \uc544\ub808\ub098:",
			"ARENA_REROLL_OPT_WAVE": "\uc6e8\uc774\ube0c",
			"ARENA_REROLL_OPT_RUN": "\ud310",
			"ARENA_REROLL_DESC": "\uc6e8\uc774\ube0c = \ub9e4 \uc6e8\uc774\ube0c\ub9c8\ub2e4 \uac31\uc2e0. \ud310 = \ud55c \ud310 \ub0b4\ub0b4 \ubb34\uc791\uc704 \uc544\ub808\ub098 \ud558\ub098.",
		},
	}
	for locale in translations:
		var t = Translation.new()
		t.locale = locale
		for key in translations[locale]:
			t.add_message(key, translations[locale][key])
		TranslationServer.add_translation(t)
