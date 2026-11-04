class_name Typography
extends RefCounted
## Font loading for the design system.
##
## Three families, all SIL Open Font License 1.1 (see assets/fonts/*/OFL.txt):
##   Spectral    — display and editorial headings, gives the interface a
##                 documentary, statecraft tone instead of a generic UI sans.
##   IBM Plex Sans — interface text; a slightly engineered humanist sans with
##                 excellent legibility at small sizes.
##   IBM Plex Mono — figures, versions and identifiers, so numbers align.
##
## Only latin subsets of the exact weights we use are shipped (~200 KB total).

const PATH_SERIF_LIGHT := "res://assets/fonts/spectral/spectral-latin-300-normal.woff2"
const PATH_SERIF_REGULAR := "res://assets/fonts/spectral/spectral-latin-400-normal.woff2"
const PATH_SANS_REGULAR := "res://assets/fonts/ibm_plex_sans/ibm-plex-sans-latin-400-normal.woff2"
const PATH_SANS_MEDIUM := "res://assets/fonts/ibm_plex_sans/ibm-plex-sans-latin-500-normal.woff2"
const PATH_SANS_SEMIBOLD := "res://assets/fonts/ibm_plex_sans/ibm-plex-sans-latin-600-normal.woff2"
const PATH_MONO_REGULAR := "res://assets/fonts/ibm_plex_mono/ibm-plex-mono-latin-400-normal.woff2"
const PATH_MONO_MEDIUM := "res://assets/fonts/ibm_plex_mono/ibm-plex-mono-latin-500-normal.woff2"

const _SERIF_LIGHT: FontFile = preload(PATH_SERIF_LIGHT)
const _SERIF_REGULAR: FontFile = preload(PATH_SERIF_REGULAR)
const _SANS_REGULAR: FontFile = preload(PATH_SANS_REGULAR)
const _SANS_MEDIUM: FontFile = preload(PATH_SANS_MEDIUM)
const _SANS_SEMIBOLD: FontFile = preload(PATH_SANS_SEMIBOLD)
const _MONO_REGULAR: FontFile = preload(PATH_MONO_REGULAR)
const _MONO_MEDIUM: FontFile = preload(PATH_MONO_MEDIUM)

static var _tracked_cache: Dictionary = {}


static func serif_light() -> Font:
	return _SERIF_LIGHT


static func serif_regular() -> Font:
	return _SERIF_REGULAR


static func sans_regular() -> Font:
	return _SANS_REGULAR


static func sans_medium() -> Font:
	return _SANS_MEDIUM


static func sans_semibold() -> Font:
	return _SANS_SEMIBOLD


static func mono_regular() -> Font:
	return _MONO_REGULAR


static func mono_medium() -> Font:
	return _MONO_MEDIUM


## A copy of `base` with extra letter-spacing between glyphs. Used for tracked,
## capitalised labels (wordmark, eyebrows, badges) where the open spacing is part
## of the visual identity.
static func tracked(base: Font, glyph_spacing: int) -> FontVariation:
	var key := "%d:%d" % [base.get_instance_id(), glyph_spacing]
	var cached: FontVariation = _tracked_cache.get(key)
	if cached != null:
		return cached
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = glyph_spacing
	_tracked_cache[key] = variation
	return variation
