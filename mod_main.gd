extends Node

const MOD_DIR = "PapiLeem-Arenas"
const MOD_LOG = "PapiLeem-Arenas"

var mod_dir_path := ""
var ext_dir := ""


func _init():
	ModLoaderLog.info("Init", MOD_LOG)
	mod_dir_path = ModLoaderMod.get_unpacked_dir().plus_file(MOD_DIR)
	ext_dir = mod_dir_path.plus_file("extensions")

	ModLoaderMod.install_script_extension(ext_dir + "/singletons/zone_service.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/my_tile_map_limits.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/my_tile_map.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/global/entity_spawner.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/ui/menus/run/run_options_panel.gd")
	ModLoaderMod.install_script_extension(ext_dir + "/entities/birth/entity_birth.gd")


func _ready():
	_add_translations()
	_load_config()
	ModLoaderLog.info("Ready", MOD_LOG)


func _load_config():
	var config = ModLoaderConfig.get_current_config(MOD_DIR)
	if config and config.data:
		var default_shape = int(config.data.get("default_arena_shape", 0))
		ZoneService.arena_shape_id = default_shape
		ZoneService.arena_shrinking_min_scale = config.data.get("shrinking_min_scale", 0.4)
		ZoneService.arena_shrinking_speed = config.data.get("shrinking_speed", 1.0)
		ModLoaderLog.info("Config loaded - default shape: " + str(default_shape), MOD_LOG)


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
			"ARENA_MULTIROOM": "Multi-Room",
			"ARENA_HAZARD": "Hazard Zones",
			"ARENA_SHAPE_DESC_RECTANGLE": "Standard arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Circular arena - no corners to hide in",
			"ARENA_SHAPE_DESC_HEXAGON": "Six-sided arena with flat edges",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Run right or die - curse wall chases you",
			"ARENA_SHAPE_DESC_SHRINKING": "A deadly storm closes in - battle royale style",
			"ARENA_SHAPE_DESC_MAZE": "Procedural maze - different layout every wave",
			"ARENA_SHAPE_DESC_MULTIROOM": "Rooms connected by doorways",
			"ARENA_SHAPE_DESC_HAZARD": "Curse clouds that damage you on contact",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Arene standard",
			"ARENA_SHAPE_DESC_CIRCLE": "Arene circulaire - pas de coins pour se cacher",
			"ARENA_SHAPE_DESC_HEXAGON": "Arene a six cotes avec des bords plats",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Courez a droite ou mourez - le mur de mort vous poursuit",
			"ARENA_SHAPE_DESC_SHRINKING": "Une tempete mortelle se referme - style battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labyrinthe procedural - disposition differente a chaque vague",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salles reliees par des passages",
			"ARENA_SHAPE_DESC_HAZARD": "Nuages maudits qui vous blessent au contact",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena estandar",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circular - sin esquinas donde esconderse",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena de seis lados con bordes planos",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corre a la derecha o muere - el muro mortal te persigue",
			"ARENA_SHAPE_DESC_SHRINKING": "Una tormenta mortal se cierra - estilo battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Laberinto procedural - diseno diferente en cada oleada",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salas conectadas por puertas",
			"ARENA_SHAPE_DESC_HAZARD": "Nubes malditas que te danan al contacto",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Standard-Arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Runde Arena - keine Ecken zum Verstecken",
			"ARENA_SHAPE_DESC_HEXAGON": "Sechseckige Arena mit flachen Kanten",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Renne nach rechts oder stirb - die Todeswand verfolgt dich",
			"ARENA_SHAPE_DESC_SHRINKING": "Ein todlicher Sturm schliesst sich - Battle-Royale-Stil",
			"ARENA_SHAPE_DESC_MAZE": "Prozedurales Labyrinth - anderes Layout jede Welle",
			"ARENA_SHAPE_DESC_MULTIROOM": "Raume verbunden durch Durchgange",
			"ARENA_SHAPE_DESC_HAZARD": "Fluchwolken die bei Kontakt Schaden verursachen",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "\u0421\u0442\u0430\u043d\u0434\u0430\u0440\u0442\u043d\u0430\u044f \u0430\u0440\u0435\u043d\u0430",
			"ARENA_SHAPE_DESC_CIRCLE": "\u041a\u0440\u0443\u0433\u043b\u0430\u044f \u0430\u0440\u0435\u043d\u0430 - \u043d\u0435\u0433\u0434\u0435 \u0441\u043f\u0440\u044f\u0442\u0430\u0442\u044c\u0441\u044f \u0432 \u0443\u0433\u043b\u0430\u0445",
			"ARENA_SHAPE_DESC_HEXAGON": "\u0428\u0435\u0441\u0442\u0438\u0433\u0440\u0430\u043d\u043d\u0430\u044f \u0430\u0440\u0435\u043d\u0430 \u0441 \u043f\u043b\u043e\u0441\u043a\u0438\u043c\u0438 \u043a\u0440\u0430\u044f\u043c\u0438",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u0411\u0435\u0433\u0438 \u0432\u043f\u0440\u0430\u0432\u043e \u0438\u043b\u0438 \u0443\u043c\u0440\u0438 - \u0441\u0442\u0435\u043d\u0430 \u0441\u043c\u0435\u0440\u0442\u0438 \u043f\u0440\u0435\u0441\u043b\u0435\u0434\u0443\u0435\u0442 \u0442\u0435\u0431\u044f",
			"ARENA_SHAPE_DESC_SHRINKING": "\u0421\u043c\u0435\u0440\u0442\u0435\u043b\u044c\u043d\u044b\u0439 \u0448\u0442\u043e\u0440\u043c \u043d\u0430\u0434\u0432\u0438\u0433\u0430\u0435\u0442\u0441\u044f - \u0441\u0442\u0438\u043b\u044c \u0431\u0430\u0442\u043b \u0440\u043e\u044f\u043b\u044c",
			"ARENA_SHAPE_DESC_MAZE": "\u041f\u0440\u043e\u0446\u0435\u0434\u0443\u0440\u043d\u044b\u0439 \u043b\u0430\u0431\u0438\u0440\u0438\u043d\u0442 - \u043d\u043e\u0432\u0430\u044f \u043f\u043b\u0430\u043d\u0438\u0440\u043e\u0432\u043a\u0430 \u043a\u0430\u0436\u0434\u0443\u044e \u0432\u043e\u043b\u043d\u0443",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u041a\u043e\u043c\u043d\u0430\u0442\u044b \u0441\u043e\u0435\u0434\u0438\u043d\u0435\u043d\u043d\u044b\u0435 \u043f\u0440\u043e\u0445\u043e\u0434\u0430\u043c\u0438",
			"ARENA_SHAPE_DESC_HAZARD": "\u041f\u0440\u043e\u043a\u043b\u044f\u0442\u044b\u0435 \u043e\u0431\u043b\u0430\u043a\u0430 \u043d\u0430\u043d\u043e\u0441\u044f\u0449\u0438\u0435 \u0443\u0440\u043e\u043d \u043f\u0440\u0438 \u043a\u043e\u043d\u0442\u0430\u043a\u0442\u0435",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena padrao",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circular - sem cantos para se esconder",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena de seis lados com bordas planas",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corra para a direita ou morra - o muro mortal te persegue",
			"ARENA_SHAPE_DESC_SHRINKING": "Uma tempestade mortal se fecha - estilo battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labirinto procedural - layout diferente a cada onda",
			"ARENA_SHAPE_DESC_MULTIROOM": "Salas conectadas por passagens",
			"ARENA_SHAPE_DESC_HAZARD": "Nuvens amaldicoadas que causam dano ao contato",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Standardowa arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Okragla arena - bez katow do ukrycia",
			"ARENA_SHAPE_DESC_HEXAGON": "Szesciokotna arena z plaskimi krawedziami",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Biegnij w prawo lub zgin - sciana smierci cie sciga",
			"ARENA_SHAPE_DESC_SHRINKING": "Smiercionosna burza nadciaga - styl battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Proceduralny labirynt - inny uklad w kazdej fali",
			"ARENA_SHAPE_DESC_MULTIROOM": "Pokoje polaczone przejsciami",
			"ARENA_SHAPE_DESC_HAZARD": "Przeklete chmury zadajace obrazenia przy kontakcie",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Arena standard",
			"ARENA_SHAPE_DESC_CIRCLE": "Arena circolare - nessun angolo dove nascondersi",
			"ARENA_SHAPE_DESC_HEXAGON": "Arena a sei lati con bordi piatti",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Corri a destra o muori - il muro mortale ti insegue",
			"ARENA_SHAPE_DESC_SHRINKING": "Una tempesta mortale si chiude - stile battle royale",
			"ARENA_SHAPE_DESC_MAZE": "Labirinto procedurale - layout diverso ogni ondata",
			"ARENA_SHAPE_DESC_MULTIROOM": "Stanze collegate da passaggi",
			"ARENA_SHAPE_DESC_HAZARD": "Nubi maledette che danneggiano al contatto",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "Standart arena",
			"ARENA_SHAPE_DESC_CIRCLE": "Dairesel arena - saklanacak kose yok",
			"ARENA_SHAPE_DESC_HEXAGON": "Duz kenarlari olan alti koseli arena",
			"ARENA_SHAPE_DESC_CURSE_RUN": "Saga kos ya da ol - olum duvari seni kovalıyor",
			"ARENA_SHAPE_DESC_SHRINKING": "Olumcul bir firtina kapaniyor - battle royale tarzi",
			"ARENA_SHAPE_DESC_MAZE": "Prosedural labirent - her dalgada farkli duzenleme",
			"ARENA_SHAPE_DESC_MULTIROOM": "Gecitlerle baglanan odalar",
			"ARENA_SHAPE_DESC_HAZARD": "Temasta hasar veren lanet bulutlari",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6807\u51c6\u7ade\u6280\u573a",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5706\u5f62\u7ade\u6280\u573a - \u65e0\u5904\u85cf\u8eab",
			"ARENA_SHAPE_DESC_HEXAGON": "\u516d\u8fb9\u5f62\u7ade\u6280\u573a\uff0c\u8fb9\u7f18\u5e73\u5766",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u5411\u53f3\u8dd1\u6216\u8005\u6b7b - \u6b7b\u4ea1\u4e4b\u5899\u8ffd\u9010\u4f60",
			"ARENA_SHAPE_DESC_SHRINKING": "\u81f4\u547d\u98ce\u66b4\u6b63\u5728\u903c\u8fd1 - \u5927\u9003\u6740\u98ce\u683c",
			"ARENA_SHAPE_DESC_MAZE": "\u7a0b\u5e8f\u751f\u6210\u8ff7\u5bab - \u6bcf\u6ce2\u5e03\u5c40\u4e0d\u540c",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u8fc7\u95e8\u9053\u8fde\u63a5\u7684\u623f\u95f4",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89e6\u9020\u6210\u4f24\u5bb3\u7684\u8bc5\u5492\u4e91",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6a19\u6e96\u7af6\u6280\u5834",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5713\u5f62\u7af6\u6280\u5834 - \u7121\u8655\u85cf\u8eab",
			"ARENA_SHAPE_DESC_HEXAGON": "\u516d\u908a\u5f62\u7af6\u6280\u5834\uff0c\u908a\u7de3\u5e73\u5766",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u5411\u53f3\u8dd1\u6216\u8005\u6b7b - \u6b7b\u4ea1\u4e4b\u7246\u8ffd\u9010\u4f60",
			"ARENA_SHAPE_DESC_SHRINKING": "\u81f4\u547d\u98a8\u66b4\u6b63\u5728\u903c\u8fd1 - \u5927\u9003\u6bba\u98a8\u683c",
			"ARENA_SHAPE_DESC_MAZE": "\u7a0b\u5e8f\u751f\u6210\u8ff7\u5bae - \u6bcf\u6ce2\u4f48\u5c40\u4e0d\u540c",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u904e\u9580\u9053\u9023\u63a5\u7684\u623f\u9593",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89f8\u9020\u6210\u50b7\u5bb3\u7684\u8a5b\u5492\u96f2",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "\u6a19\u6e96\u30a2\u30ea\u30fc\u30ca",
			"ARENA_SHAPE_DESC_CIRCLE": "\u5186\u5f62\u30a2\u30ea\u30fc\u30ca - \u96a0\u308c\u308b\u89d2\u306a\u3057",
			"ARENA_SHAPE_DESC_HEXAGON": "\u5e73\u3089\u306a\u7e01\u306e\u516d\u89d2\u5f62\u30a2\u30ea\u30fc\u30ca",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\u53f3\u306b\u8d70\u308c\u3001\u3055\u3082\u306a\u304f\u3070\u6b7b\u306c - \u6b7b\u306e\u58c1\u304c\u8ffd\u3063\u3066\u304f\u308b",
			"ARENA_SHAPE_DESC_SHRINKING": "\u6b7b\u306e\u5d50\u304c\u8feb\u308b - \u30d0\u30c8\u30ed\u30ef\u30a4\u30e4\u30eb\u30b9\u30bf\u30a4\u30eb",
			"ARENA_SHAPE_DESC_MAZE": "\u30d7\u30ed\u30b7\u30fc\u30b8\u30e3\u30eb\u8ff7\u8def - \u6bce\u30a6\u30a7\u30fc\u30d6\u7570\u306a\u308b\u30ec\u30a4\u30a2\u30a6\u30c8",
			"ARENA_SHAPE_DESC_MULTIROOM": "\u901a\u8def\u3067\u3064\u306a\u304c\u3063\u305f\u90e8\u5c4b",
			"ARENA_SHAPE_DESC_HAZARD": "\u63a5\u89e6\u3059\u308b\u3068\u30c0\u30e1\u30fc\u30b8\u3092\u53d7\u3051\u308b\u546a\u3044\u306e\u96f2",
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
			"ARENA_SHAPE_DESC_RECTANGLE": "\ud45c\uc900 \uc544\ub808\ub098",
			"ARENA_SHAPE_DESC_CIRCLE": "\uc6d0\ud615 \uc544\ub808\ub098 - \uc228\uc744 \uad6c\uc11d\uc774 \uc5c6\uc74c",
			"ARENA_SHAPE_DESC_HEXAGON": "\ud3c9\ud3c9\ud55c \ubaa8\uc11c\ub9ac\uc758 \uc721\uac01\ud615 \uc544\ub808\ub098",
			"ARENA_SHAPE_DESC_CURSE_RUN": "\uc624\ub978\ucabd\uc73c\ub85c \ub2ec\ub9ac\uac70\ub098 \uc8fd\uac70\ub098 - \uc8fd\uc74c\uc758 \ubcbd\uc774 \ucad3\uc544\uc628\ub2e4",
			"ARENA_SHAPE_DESC_SHRINKING": "\uce58\uba85\uc801\uc778 \ud3ed\ud48d\uc774 \ub2e4\uac00\uc628\ub2e4 - \ubc30\ud2c0\ub85c\uc58c \uc2a4\ud0c0\uc77c",
			"ARENA_SHAPE_DESC_MAZE": "\uc808\ucc28\uc801 \ubbf8\ub85c - \ub9e4 \uc6e8\uc774\ube0c\ub9c8\ub2e4 \ub2e4\ub978 \ub808\uc774\uc544\uc6c3",
			"ARENA_SHAPE_DESC_MULTIROOM": "\ud1b5\ub85c\ub85c \uc5f0\uacb0\ub41c \ubc29\ub4e4",
			"ARENA_SHAPE_DESC_HAZARD": "\uc811\ucd09 \uc2dc \ud53c\ud574\ub97c \uc8fc\ub294 \uc800\uc8fc \uad6c\ub984",
		},
	}
	for locale in translations:
		var t = Translation.new()
		t.locale = locale
		for key in translations[locale]:
			t.add_message(key, translations[locale][key])
		TranslationServer.add_translation(t)
