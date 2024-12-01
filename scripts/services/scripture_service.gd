extends Node

## This is a service that provides access to the scripture data.
## It can fetch cross-references, verses, and books, as well as 
## other related info.
## Interacts with models to get data from the database and is 
## used by the controllers to provide data to the views.

signal verses_searched(verses:Dictionary)
signal verse_cross_references_searched(verses:Dictionary)
signal vx_verses_searched(verses:Dictionary)
signal books_installed

var translations = {}
var books = {}

func _ready():
	reload_data()
	books_installed.connect(reload_data)

func reload_data():
	load_translations()
	load_books()
	print("Scripture service data reloaded.")

func load_translations():
	translations.clear()
	var translation_model = BibleTranslationModel.new()
	var all_translations = translation_model.get_all_translations()
	for t in all_translations:
		translations[t["id"]] = t

func load_books():
	books.clear()
	var translation_model = BibleTranslationModel.new()
	var all_translations = translation_model.get_all_translations()
	for t in all_translations:
		var book_model = BookModel.new(t["translation_abbr"])
		var all_books = book_model.get_all_books()
		for b in all_books:
			b["translation"] = t["translation_abbr"]
			if t["id"] not in books:
				books[t["id"]] = {}
			books[t["id"]][b["id"]] = b
			
## Gets a single verse, one entry in an array.
func get_verse(translation: String, book: String, chapter: int, verse: int) -> Array:
	var verse_model: VerseModel = VerseModel.new(translation)
	var book_model: BookModel = BookModel.new(translation)
	book_model.get_book_by_name(book)
	var book_id: int = book_model.id
	var verse_data: Dictionary = verse_model.get_verse(book_id, chapter, verse)
	var translation_data: Dictionary = get_translation(translation)
	return [{
		"verse_id": verse_data["verse_id"],
		"book_id": verse_data["book_id"],
		"chapter": verse_data["chapter"],
		"verse": verse_data["verse"],
		"text": verse_data["text"],
		"book_name": book_model.book_name,
		"translation_id": verse_data["translation_id"],
		"translation_abbr": translation_data["translation_abbr"],
		"title": translation_data["title"],
		"license": translation_data["license"],
	}]

## Get verses by book, chapter, or specific verse
func get_verses(translation: String, book: String, chapter: int = -1, verse: int = -1) -> Array:
	var verse_model: VerseModel = VerseModel.new(translation)
	var verses: Array = verse_model.get_verses(book, chapter, verse)
	var result: Array = []
	for v in verses:
		result.append({
			"id": v["id"],
			"book_id": v["book_id"],
			"chapter": v["chapter"],
			"verse": v["verse"],
			"text": v["text"],
			"translation": translation
		})
	return result

## Get verses by range
func get_verses_by_range(translation: String, start_book: String, start_chapter: int, start_verse: int, end_book: String, end_chapter: int, end_verse: int) -> Array:
	var verse_model = VerseModel.new(translation)
	var verses = verse_model.get_verses_by_range(start_book, start_chapter, start_verse, end_book, end_chapter, end_verse)
	var result = []
	for v in verses:
		result.append(v)
	return result

## Get cross references for a verse
func get_cross_references_for_verse(translation: String, book: String, chapter: int, verse: int) -> Array:
	var cross_reference_model = CrossReferenceModel.new(translation)
	var cross_references = cross_reference_model.get_cross_references_for_verse(book, chapter, verse)
	var result = []
	for cr in cross_references:
		result.append(cr)
	return result

## Requests a cross reference list.
func request_cross_references(translation: String, book: String, chapter: int, verse: int) -> void:
	var cross_references = get_cross_references_for_verse(translation, book, chapter, verse)
	propagate_cross_reference_search(translation, cross_references)

## Request a verse for the vx system.
func request_vx_verse(translation: String, book: String, chapter: int, verse: int) -> void:
	var results = get_verse(translation, book, chapter, verse)
	propogate_vx_search(translation, results)

## Get information about a book
func get_book(translation: String, book_name: String) -> Dictionary:
	var book_model = BookModel.new(translation)
	book_model.get_book_by_name(book_name)
	return {
		"id": book_model.id,
		"book_name": book_model.book_name,
		"translation": book_model.translation
	}

## Get all chapter numbers in a book
func get_all_chapter_numbers_in_book(translation: String, book_name: String) -> Dictionary:
	var verse_model = VerseModel.new(translation)
	var chapters = verse_model.get_all_chapter_numbers(book_name)
	
	var results:Dictionary = {
		"chapters": []
	}
	for c in chapters:
		results["chapters"].append(c["chapter"])
	return results	

## Get all verse numbers in a chapter
func get_all_verse_numbers_in_chapter(translation: String, book_name: String, chapter: int) -> Dictionary:
	var verse_model = VerseModel.new(translation)
	var verses = verse_model.get_all_verse_numbers(book_name, chapter)
	
	var results:Dictionary = {
		"verses": []
	}
	for v in verses:
		results["verses"].append(v["verse"])
	return results

## Get all books for a specific translation
func get_all_books(translation: String) -> Array:
	var book_model = BookModel.new(translation)
	var all_books = book_model.get_all_books()
	var result = []
	for b in all_books:
		result.append({
			"id": b["id"],
			"book_name": b["book_name"],
			"translation": translation
		})
	return result

## Get information about a book by its ID
func get_book_by_id(translation_id:int, book_id: int) -> Dictionary:
	if books.has(translation_id):
		if books[translation_id].has(book_id):
			return books[translation_id][book_id]
	return {}

## Get information about a translation
func get_translation(translation_abbr: String) -> Dictionary:
	var translation_model = BibleTranslationModel.new()
	var translation_data = translation_model.get_translation(translation_abbr)
	if translation_data.is_empty():
		return {}
	return {
		"id": translation_data["id"],
		"translation_abbr": translation_data["translation_abbr"],
		"title": translation_data["title"],
		"license": translation_data["license"]
	}

## Get all translations
func get_all_translations() -> Array:
	var translation_model = BibleTranslationModel.new()
	var all_translations = translation_model.get_all_translations()
	var result = []
	for t in all_translations:
		result.append({
			"id": t["id"],
			"translation_abbr": t["translation_abbr"],
			"title": t["title"],
			"license": t["license"]
		})
	return result

## Get information about a translation by its ID
func get_translation_by_id(translation_id: int) -> Dictionary:
	if translation_id in translations:
		return translations[translation_id]
	return {}


## Initiate a text search based on the provided criteria
func initiate_text_search(scope: Types.SearchScope, translation: String, text: String, book: String = "", chapter: int = -1) -> void:
	var verse_model = VerseModel.new(translation)
	var verse_model_scrollmapper = VerseModel.new("scrollmapper")
	var verses = []
	match scope:
		Types.SearchScope.ALL_SCRIPTURE:
			var verse_set_1 = verse_model.search_text(text, book, chapter)
			for v in verse_set_1:
				verses.append(v)
			var verse_set_2 = verse_model_scrollmapper.search_text(text, book, chapter)
			for v in verse_set_2:
				verses.append(v)
		Types.SearchScope.COMMON_CANNONICAL:
			verses = verse_model.search_text(text, book, chapter)
		Types.SearchScope.EXTRA_CANNONICAL:
			verses = verse_model_scrollmapper.search_text(text, book, chapter)
		_:
			verses = verse_model.search_text(text, book, chapter)
	propogate_search(translation, verses)

func initiate_range_search(translation: String, start_book: String, start_chapter: int, start_verse: int, end_book: String, end_chapter: int, end_verse: int):
	var verses = get_verses_by_range(translation, start_book, start_chapter, start_verse, end_book, end_chapter, end_verse)
	propogate_search(translation, verses)

## This *important* function handles search propagation to subscribed objects. It converts the array of verse results 
## from the database into a JSON string formatted for the API. This JSON string is then emitted via a signal 
## to be received by the subscribed objects.
func propogate_search(translation_abbr:String, verse_results:Array):
	if verse_results.is_empty():
		return
	var results:Array = []
	for verse_result in verse_results:
		verse_result["translation"] = get_translation_by_id(verse_result["translation_id"])
		if books.has(verse_result["translation_id"]):
			verse_result["book"] = get_book_by_id(verse_result["translation_id"], verse_result["book_id"])
		results.append(verse_result)
	verses_searched.emit(results)

## Derived from propagate_search, this tailors verse output to cross-reference data.
func propagate_cross_reference_search(translation_abbr:String, verse_results:Array):
	if verse_results.is_empty():
		return
	var results:Array = []
	for verse_result in verse_results:
		verse_result["translation"] = get_translation_by_id(verse_result["translation_id"])
		if books.has(verse_result["translation_id"]):
			verse_result["book"] = get_book_by_id(verse_result["translation_id"], verse_result["book_id"])
		results.append(verse_result)
	verse_cross_references_searched.emit(results)

## Derived from propagate_search, this tailors verse output to vx_verse system.
func propogate_vx_search(translation_abbr:String, verse_results:Array):

	if verse_results.is_empty():
		return
	var results:Array = []
	for verse_result in verse_results:
		verse_result["translation"] = get_translation_by_id(verse_result["translation_id"])
		if books.has(verse_result["translation_id"]):
			verse_result["book"] = get_book_by_id(verse_result["translation_id"], verse_result["book_id"])
		results.append(verse_result)
	vx_verses_searched.emit(results)

func emit_books_installed():
	books_installed.emit()
