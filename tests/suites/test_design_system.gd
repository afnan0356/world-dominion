extends TestCase
## Verifies the design system itself: token ordering, palette completeness,
## WCAG contrast, and that the generated theme exposes every style variation the
## interface relies on.

func test_spacing_scale_is_ordered() -> void:
	var scale := [DesignTokens.SPACE_2, DesignTokens.SPACE_4, DesignTokens.SPACE_8,
			DesignTokens.SPACE_12, DesignTokens.SPACE_16, DesignTokens.SPACE_24,
			DesignTokens.SPACE_32, DesignTokens.SPACE_48, DesignTokens.SPACE_64]
	for index in range(1, scale.size()):
		check_gt(float(scale[index]), float(scale[index - 1]), "spacing step %d must grow" % index)


func test_type_scale_is_ordered() -> void:
	var sizes := [DesignTokens.FS_CAPTION, DesignTokens.FS_MONO, DesignTokens.FS_SMALL,
			DesignTokens.FS_BODY, DesignTokens.FS_SUBHEADING, DesignTokens.FS_HEADING,
			DesignTokens.FS_TITLE, DesignTokens.FS_DISPLAY_COMPACT, DesignTokens.FS_DISPLAY]
	for index in range(1, sizes.size()):
		check_gt(float(sizes[index]), float(sizes[index - 1]), "type step %d must grow" % index)
	check_gte(DesignTokens.FS_CAPTION, 10.0, "captions must stay readable")


func test_motion_durations_are_ordered() -> void:
	check_gt(DesignTokens.DURATION_FAST, 0.0, "transitions must not be instant by default")
	check_lte(DesignTokens.DURATION_SLOW, 0.35, "transitions must stay quick")


func test_every_palette_defines_every_key() -> void:
	var reference: Dictionary = Palette.colors(Palette.MIDNIGHT)
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		check_eq(colors.size(), reference.size(), "%s defines a different number of colours" % palette_id)
		for key: String in reference:
			check_true(colors.has(key), "%s is missing colour '%s'" % [palette_id, key])
			var color: Color = colors[key]
			check_gte(color.a, 0.99, "%s/%s must be opaque" % [palette_id, key])


func test_palettes_meet_wcag_aa() -> void:
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		for requirement: Array in Palette.CONTRAST_REQUIREMENTS:
			var foreground_key: String = requirement[0]
			var background_key: String = requirement[1]
			var minimum: float = requirement[2]
			var ratio := contrast_ratio(colors[foreground_key], colors[background_key])
			check_gte(ratio, minimum, "%s: %s on %s is %.2f:1, needs %.1f:1" % [
				palette_id, foreground_key, background_key, ratio, minimum])


func test_focus_ring_is_visible() -> void:
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		for background_key: String in [Palette.KEY_BG_BASE, Palette.KEY_BG_PANEL,
				Palette.KEY_BG_SURFACE, Palette.KEY_BG_HOVER]:
			var ratio := contrast_ratio(colors[Palette.KEY_ACCENT], colors[background_key])
			check_gte(ratio, 3.0, "%s: focus ring on %s is %.2f:1, needs 3.0:1 for a non-text indicator" % [
				palette_id, background_key, ratio])


func test_map_colours_stay_legible() -> void:
	# The atlas is drawn, not themed, so its colour pairs are asserted here as
	# non-text contrasts: land against sea, a selection against land, labels as
	# text, and the selected outline against its own fill.
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		for requirement: Array in Palette.MAP_CONTRAST_REQUIREMENTS:
			var foreground_key: String = requirement[0]
			var background_key: String = requirement[1]
			var minimum: float = requirement[2]
			var ratio := contrast_ratio(colors[foreground_key], colors[background_key])
			check_gte(ratio, minimum, "%s: %s on %s is %.2f:1, needs %.1f:1" % [
				palette_id, foreground_key, background_key, ratio, minimum])


func test_map_region_tints_are_separated() -> void:
	# Six tints, one per source region. They are subtle on purpose, so the check is
	# that none of them collapses into another *and* that each stays clear of the
	# sea. Region is a hint; names, coastlines and selection cues carry the
	# information, so a player who cannot tell two tints apart loses nothing.
	for palette_id: String in Palette.ids():
		var colors := Palette.colors(palette_id)
		var luminances: Array[float] = []
		for key: String in Palette.KEY_MAP_REGIONS:
			var colour: Color = colors[key]
			luminances.append(relative_luminance(colour))
			check_gte(contrast_ratio(colour, colors[Palette.KEY_MAP_WATER]),
					Palette.MAP_REGION_MIN_WATER_CONTRAST,
					"%s: %s must stay clear of the sea" % [palette_id, key])
		luminances.sort()
		for index in range(1, luminances.size()):
			check_gte(luminances[index] - luminances[index - 1],
					Palette.MAP_REGION_MIN_LUMINANCE_STEP,
					"%s: region tints %d and %d are the same tone" % [palette_id,
						index - 1, index])


func test_theme_exposes_required_variations() -> void:
	for palette_id: String in Palette.ids():
		var theme := ThemeFactory.build(Palette.colors(palette_id))
		var required := ThemeFactory.required_variations()
		for base_type: String in required:
			for variation: String in required[base_type]:
				check_eq(theme.get_type_variation_base(variation), base_type,
						"%s: '%s' must be a variation of %s" % [palette_id, variation, base_type])
				if base_type == "Label":
					check_true(theme.has_font("font", variation),
							"%s: label variation '%s' has no font" % [palette_id, variation])
					check_true(theme.has_font_size("font_size", variation),
							"%s: label variation '%s' has no font size" % [palette_id, variation])
				else:
					check_true(theme.has_stylebox("normal", variation) or theme.has_stylebox("panel", variation),
							"%s: '%s' has no default stylebox" % [palette_id, variation])


func test_theme_type_sizes_follow_tokens() -> void:
	var theme := ThemeFactory.build(Palette.colors(Palette.DEFAULT_ID))
	check_eq(theme.get_font_size("font_size", "DisplayTitle"), DesignTokens.FS_DISPLAY,
			"display size must come from the token")
	check_eq(theme.get_font_size("font_size", "Body"), DesignTokens.FS_BODY,
			"body size must come from the token")
	check_not_null(theme.default_font, "theme must set a default font")


func test_focus_styleboxes_do_not_cover_content() -> void:
	var theme := ThemeFactory.build(Palette.colors(Palette.DEFAULT_ID))
	for variation: String in ["Button", "NavRow", "GhostButton", "SegmentButton"]:
		var focus := theme.get_stylebox("focus", variation) as StyleBoxFlat
		check_not_null(focus, "%s must define a focus stylebox" % variation)
		if focus != null:
			check_false(focus.draw_center, "%s focus box must be an outline, not a fill" % variation)
			check_gte(focus.border_width_left, 1.0, "%s focus outline must be at least 1px" % variation)


func test_theme_manager_matches_the_active_palette() -> void:
	var active := ThemeManager.palette_id()
	var expected := Palette.colors(active)
	var actual := ThemeManager.colors()
	check_eq(actual.size(), expected.size(), "ThemeManager must expose the whole palette")
	for key: String in expected:
		check_eq(actual[key], expected[key], "ThemeManager colour '%s' must match the palette" % key)
	check_not_null(ThemeManager.current_theme(), "an active theme must exist at runtime")
	check_eq(tree.root.theme, ThemeManager.current_theme(),
			"the active theme must be applied to the root window")


func test_settings_schema_rejects_bad_values() -> void:
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_THEME, "neon"), Palette.DEFAULT_ID,
			"unknown palette must fall back to the default")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_UI_SCALE, 4.5), 1.0,
			"unsupported interface scale must fall back to 1.0")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_MOTION, "spoiler"), SettingsSchema.MOTION_FULL,
			"unknown motion mode must fall back to full")
	check_eq(SettingsSchema.sanitize(SettingsSchema.KEY_THEME, Palette.PARCHMENT), Palette.PARCHMENT,
			"valid values must survive sanitizing")


func test_motion_helper_honours_reduced_motion() -> void:
	check_eq(Motion.duration(0.2, false), 0.2, "normal motion keeps the duration")
	check_eq(Motion.duration(0.2, true), 0.0, "reduced motion removes the duration")
	check_eq(Motion.stagger(3, true), 0.0, "reduced motion removes stagger")
	check_gt(Motion.stagger(3, false), Motion.stagger(1, false), "stagger grows with index")
