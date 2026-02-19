// imgui_settings_ios.h — Ported from MENTALITY V2 imgui_settings.h
// Removed Windows dependencies, adapted for iOS/Metal backend

#pragma once
#include "../IMGUI/imgui.h"
#include "ios_compat.h"

namespace font
{
	inline ImFont* icomoon_logo = nullptr;
	inline ImFont* description_font = nullptr;
	inline ImFont* esp_font = nullptr;
	inline ImFont* regular_m = nullptr;

	inline ImFont* default_r = nullptr;
	inline ImFont* default_m = nullptr;
	inline ImFont* default_s = nullptr;

	inline ImFont* regular_l = nullptr;
	inline ImFont* icomoon_page = nullptr;
	inline ImFont* small_font = nullptr;
	inline ImFont* inter_bold = nullptr;
	inline ImFont* inter_semibold = nullptr;
	inline ImFont* s_inter_semibold = nullptr;
	inline ImFont* inter_medium = nullptr;
	inline ImFont* icon_notify = nullptr;
}

inline static float current_scroll = 0.f;

namespace utils
{
	inline float CalculateTextWidthWithoutColorCodes(const ImFont* font, const char* text_begin, const char* text_end = nullptr) {
		if (!text_end)
			text_end = text_begin + strlen(text_begin);

		float text_width = 0.0f;
		const char* s = text_begin;

		while (s < text_end) {
			if (*s == '^' && (s + 1) < text_end && *(s + 1) >= '0' && *(s + 1) <= '9') {
				s += 2;
				continue;
			}

			unsigned int c = (unsigned int)*s;
			if (c < 0x80) {
				s += 1;
			}
			else {
				s += ImTextCharFromUtf8(&c, s, text_end);
				if (c == 0)
					break;
			}

			const ImFontGlyph* glyph = font->FindGlyph((ImWchar)c);
			if (glyph) {
				text_width += glyph->AdvanceX;
			}
		}

		return text_width;
	}

	inline ImColor GetColorWithAlpha(ImColor color, float alpha)
	{
		return ImColor(color.Value.x, color.Value.y, color.Value.z, alpha);
	}

	inline ImVec2 center_text(ImVec2 min, ImVec2 max, const char* text)
	{
		return min + (max - min) / 2 - ImGui::CalcTextSize(text) / 2;
	}

	inline ImColor GetDarkColor(const ImColor& color)
	{
		float r, g, b, a;
		r = color.Value.x;
		g = color.Value.y;
		b = color.Value.z;
		a = 255;

		float darkPercentage = 0.2f;
		float darkR = r * darkPercentage;
		float darkG = g * darkPercentage;
		float darkB = b * darkPercentage;

		return ImColor(darkR, darkG, darkB, a);
	}
	inline ImVec4 ImColorToImVec4(const ImColor& color)
	{
		return ImVec4(color.Value.x, color.Value.y, color.Value.z, color.Value.w);
	}
}

static ImColor ImLerpColor(const ImColor& a, const ImColor& b, float t)
{
	t = ImClamp(t, 0.0f, 1.0f);
	float inv = 1.0f - t;
	return ImColor(
		a.Value.x * inv + b.Value.x * t,
		a.Value.y * inv + b.Value.y * t,
		a.Value.z * inv + b.Value.z * t,
		a.Value.w * inv + b.Value.w * t
	);
}

inline static bool bTheme = true;

inline namespace c
{
	inline int selected_font = 0;
	inline int anim_offset_side = 0;
	inline static bool lang = false;
	// Initial values = light mode targets (bTheme=true)
	inline ImColor dark_color = ImColor(200, 50, 50, 255);
	inline ImColor second_color = ImColor(240, 240, 240, 200);
	inline ImColor background_color = ImColor(250, 250, 250, 180);
	inline ImColor stroke_color = ImColor(220, 220, 220, 180);
	inline ImColor window_bg_color = ImColor(255, 255, 255, 180);

	inline ImVec4 separator = ImColor(200, 200, 200, 180);

	inline namespace anim
	{
		inline float   speed = 1.0f;
		inline ImColor active = ImColor(230, 131, 90, 255);
		// 'default' is a keyword in Objective-C++, using default_color instead
		inline ImColor default_color = ImColor(215, 215, 215, 200);
	}

	inline namespace bg
	{
		inline ImVec4 background = ImColor(245, 245, 245, 200);
		inline ImVec2 size = ImVec2(735, 700);
		inline float   rounding = 9.f;
		inline ImRect menu_bb;
	}

	inline namespace child
	{
		inline ImVec4 top_bg = ImColor(28, 30, 36, 200);
		inline ImVec4 background = ImColor(255, 255, 255, 120);
		inline ImVec4 stroke = ImColor(230, 230, 240, 180);
		inline float   rounding = 4.f;
	}

	namespace page
	{
		inline ImVec4 background_active = ImColor(255, 255, 255, 200);
		inline ImVec4 background = ImColor(240, 240, 240, 200);
		inline ImVec4 text_hov = ImColor(70, 100, 255, 255);
		inline ImVec4 text = ImColor(60, 90, 255, 255);
		inline float   rounding = 6.f;
	}

	inline namespace elements
	{
		inline ImVec4 background_hovered = ImColor(220, 220, 220, 200);
		inline ImVec4 background = ImColor(210, 210, 210, 200);
		inline float   rounding = 3.f;
	}

	inline namespace checkbox
	{
		inline ImVec4 mark = ImColor(0, 120, 255, 255);
	}

	inline namespace text
	{
		inline namespace label
		{
			inline ImColor active = ImColor(0, 0, 0, 255);
			inline ImColor hovered = ImColor(20, 20, 20, 255);
			// 'default' is a keyword in Objective-C++, using default_color instead
			inline ImColor default_color = ImColor(50, 50, 50, 255);
		}
		inline namespace description
		{
			inline ImColor active = ImColor(90, 90, 90, 255);
			inline ImColor hovered = ImColor(100, 100, 100, 255);
			// 'default' is a keyword in Objective-C++, using default_color instead
			inline ImColor default_color = ImColor(120, 120, 120, 255);
		}
	}
}


inline void UpdateTheme(bool bTheme, float t)
{
	c::second_color = ImLerpColor(
		c::second_color,
		bTheme ? ImColor(240, 240, 240, 200) : ImColor(22, 22, 24, 255),
		t);

	c::anim::default_color = ImLerpColor(
		c::anim::default_color,
		bTheme ? ImColor(215, 215, 215, 200) : ImColor(27, 27, 32, 200),
		t);

	c::background_color = ImLerpColor(
		c::background_color,
		bTheme ? ImColor(250, 250, 250, 180) : ImColor(22, 22, 27, 255),
		t);

	c::stroke_color = ImLerpColor(
		c::stroke_color,
		bTheme ? ImColor(220, 220, 220, 180) : ImColor(46, 48, 56, 0),
		t);

	c::window_bg_color = ImLerpColor(
		c::window_bg_color,
		bTheme ? ImColor(255, 255, 255, 180) : ImColor(14, 14, 16, 220),
		t);

	c::separator = ImLerpColor(
		c::separator,
		bTheme ? ImColor(200, 200, 200, 180) : ImColor(40, 42, 52, 255),
		t);

	c::bg::background = ImLerpColor(
		c::bg::background,
		bTheme ? ImColor(245, 245, 245, 200) : ImColor(14, 14, 16, 255),
		t);

	c::child::background = ImLerpColor(
		c::child::background,
		bTheme ? ImColor(255, 255, 255, 120) : ImColor(19, 19, 23, 120),
		t);

	c::child::stroke = ImLerpColor(
		c::child::stroke,
		bTheme ? ImColor(230, 230, 240, 180) : ImColor(47, 48, 55, 60),
		t);

	c::page::background_active = ImLerpColor(
		c::page::background_active,
		bTheme ? ImColor(255, 255, 255, 200) : ImColor(37, 39, 53, 255),
		t);

	c::page::background = ImLerpColor(
		c::page::background,
		bTheme ? ImColor(240, 240, 240, 200) : ImColor(31, 33, 40, 255),
		t);

	c::page::text_hov = ImLerpColor(
		c::page::text_hov,
		bTheme ? ImColor(70, 100, 255, 255) : ImColor(240, 240, 240, 255),
		t);
	c::page::text = ImLerpColor(
		c::page::text,
		bTheme ? ImColor(60, 90, 255, 255) : ImColor(224, 224, 224, 255),
		t);

	c::elements::background_hovered = ImLerpColor(
		c::elements::background_hovered,
		bTheme ? ImColor(220, 220, 220, 200) : ImColor(44, 46, 52, 255),
		t);

	c::elements::background = ImLerpColor(
		c::elements::background,
		bTheme ? ImColor(210, 210, 210, 200) : ImColor(39, 41, 47, 255),
		t);

	c::checkbox::mark = ImLerpColor(
		c::checkbox::mark,
		bTheme ? ImColor(0, 120, 255, 255) : ImColor(59, 130, 246, 255),
		t);

	c::text::label::active = ImLerpColor(
		c::text::label::active,
		bTheme ? ImColor(0, 0, 0, 255) : ImColor(255, 255, 255, 255),
		t);
	c::text::label::hovered = ImLerpColor(
		c::text::label::hovered,
		bTheme ? ImColor(20, 20, 20, 255) : ImColor(235, 235, 240, 255),
		t);
	c::text::label::default_color = ImLerpColor(
		c::text::label::default_color,
		bTheme ? ImColor(50, 50, 50, 255) : ImColor(185, 185, 185, 255),
		t);

	c::text::description::active = ImLerpColor(
		c::text::description::active,
		bTheme ? ImColor(90, 90, 90, 255) : ImColor(180, 180, 185, 255),
		t);
	c::text::description::hovered = ImLerpColor(
		c::text::description::hovered,
		bTheme ? ImColor(100, 100, 100, 255) : ImColor(160, 160, 170, 255),
		t);
	c::text::description::default_color = ImLerpColor(
		c::text::description::default_color,
		bTheme ? ImColor(120, 120, 120, 255) : ImColor(140, 140, 150, 255),
		t);
}
inline bool tab_want_to_change;

// GetAnimSpeed is already defined in imgui_internal.h (MENTALITY V2 fork)
// No duplicate needed here
