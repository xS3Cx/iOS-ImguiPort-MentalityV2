#ifndef IMGUI_DEFINE_MATH_OPERATORS
#define IMGUI_DEFINE_MATH_OPERATORS
#endif
#pragma once

#include <string>
#include <cmath>
#include "ios_compat.h"

#include <iostream>


#include "../IMGUI/imgui_internal.h"

#include "notifications_ios.h"	
#include "../IMGUI/imstb_textedit.h"	
#include "custom_popup_ios.h"

#include <cstdlib>
#include "../IMGUI/imgui.h"

#include <map>
#include <algorithm>
#include <random>
inline bool getRandomBool(double probability = 0.5) {
    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::bernoulli_distribution dist(probability);
    return dist(gen);
}


using namespace ImGui;

namespace particle {

    struct Particle {
        float posX, posY, velocityX, velocityY, alpha;
        int lifespan, seed, flag, delay;
        float alphaTimer;
        Particle() : posX(0), posY(0), velocityX(0), velocityY(0), alpha(0.f), lifespan(0), seed(0), flag(0), delay(0), alphaTimer(0.f) {}
    };

    static int PARTICLE_COUT = 35;
    const int MAX_PARTICLES = 6048;
    inline Particle particles[MAX_PARTICLES];

    inline void AddParticle(ImVec2 origin, ImVec2 size, float flag) {
        Particle newParticle;
        newParticle.posX = origin.x + size.x / 2;
        newParticle.posY = origin.y;
        newParticle.velocityX = ((float)rand() / 32767) * 1.5f - 0.75f;
        newParticle.velocityY = ((float)rand() / 32767) * 0.5f - (flag ? 2.f : 0.5f);

        newParticle.lifespan = rand() % (flag ? 250 : 299);
        newParticle.seed = rand();
        newParticle.flag = static_cast<int>(flag);
        newParticle.alpha = 0.f;
        newParticle.alphaTimer = 0.f;

        for (int i = 0; i < MAX_PARTICLES; i++) {
            if (particles[i].lifespan == 0) {
                particles[i] = newParticle;
                break;
            }
        }
    }

    inline void RenderEffects(ImDrawList* drawList, ImVec2 renderSize, float timeOffset) {
        int activeParticles = 0; (void)activeParticles;
        for (int i = 0; i < MAX_PARTICLES; i++) {
            Particle& particle = particles[i];
            if (particle.lifespan) {
                if (particle.delay) {
                    particle.delay--;
                }
                else {
                    particle.posX += particle.velocityX;
                    particle.posY += particle.velocityY;
                    particle.velocityY += ImGui::GetIO().DeltaTime;
                    particle.lifespan -= (particle.velocityY > 0) ? 1 : 0;

                    particle.alpha = ImLerp(0.f, 1.f, min(1.f, particle.alphaTimer)); // Быстрое увеличение до 1
                    if (particle.alphaTimer >= 1.f) {
                        particle.alpha = ImLerp(1.f, 0.f, max(0.f, particle.alphaTimer - 1.f)); // Плавное уменьшение до 0
                    }
                    particle.alphaTimer += 0.01f;

                    ImVec2 points[4];
                    float scale = (static_cast<float>(rand()) / RAND_MAX * 1.5f + 0.1f) * (particle.flag + 1);

                    float noise = (timeOffset * (particle.lifespan < 0 ? 0 : 1)) + (i * static_cast<float>(rand()) / RAND_MAX * 2.5 - 1.5);
                    float sinAngle = sin(noise) * scale;
                    float cosAngle = cos(noise) * scale;

                    for (int j = 0; j < 4; j++) {
                        float angle = 2 * IM_PI * j / 4 + (static_cast<float>(rand()) / RAND_MAX - 0.5) * IM_PI / 8;
                        points[j].x = particle.posX - cosAngle * cos(angle) - sinAngle * sin(angle);
                        points[j].y = particle.posY + sinAngle * cos(angle) + cosAngle * sin(angle);
                    }

                    int red = 128 + (rand() % 128);
                    int green = 128 + (rand() % 128);
                    int blue = 128 + (rand() % 128);

                    drawList->AddShadowConvexPoly(points, 4, utils::GetColorWithAlpha(i % 2 == 0 ? c::anim::active : c::dark_color, particle.alpha), 35.f, ImVec2(0, 0));
                    drawList->AddConvexPolyFilled(points, 4, utils::GetColorWithAlpha(i % 2 == 0 ? c::anim::active : c::dark_color, particle.alpha));

                    if (!particle.lifespan && particle.flag) {

                    }
                }
                if (particle.flag)
                    activeParticles++;
            }
        }
    }
}


inline float ImDegToRad(float degrees)
{
    return degrees * (IM_PI / 180.0f);
}

enum fade_direction : int
{
    vertically,
    horizontally,
    diagonally,
    diagonally_reversed,
};

inline void set_linear_color(ImDrawList* draw_list, int vert_start_idx, int vert_end_idx, ImVec2 gradient_p0, ImVec2 gradient_p1, ImU32 col0, ImU32 col1, float angle = 0.f)
{
    ImVec2 gradient_extent = gradient_p1 - gradient_p0;

    float cos_angle = cosf(angle);
    float sin_angle = sinf(angle);
    float rotated_x = cos_angle * gradient_extent.x - sin_angle * gradient_extent.y;
    float rotated_y = sin_angle * gradient_extent.x + cos_angle * gradient_extent.y;

    ImVec2 rotated_p1 = gradient_p0 + ImVec2(rotated_x, rotated_y);

    float gradient_inv_length2 = 1.0f / ImLengthSqr(rotated_p1 - gradient_p0);
    ImDrawVert* vert_start = draw_list->VtxBuffer.Data + vert_start_idx;
    ImDrawVert* vert_end = draw_list->VtxBuffer.Data + vert_end_idx;
    const int col0_r = (int)(col0 >> IM_COL32_R_SHIFT) & 0xFF;
    const int col0_g = (int)(col0 >> IM_COL32_G_SHIFT) & 0xFF;
    const int col0_b = (int)(col0 >> IM_COL32_B_SHIFT) & 0xFF;
    const int col_delta_r = ((int)(col1 >> IM_COL32_R_SHIFT) & 0xFF) - col0_r;
    const int col_delta_g = ((int)(col1 >> IM_COL32_G_SHIFT) & 0xFF) - col0_g;
    const int col_delta_b = ((int)(col1 >> IM_COL32_B_SHIFT) & 0xFF) - col0_b;

    for (ImDrawVert* vert = vert_start; vert < vert_end; vert++)
    {
        float d = ImDot(vert->pos - gradient_p0, rotated_p1 - gradient_p0);
        float t = ImClamp(d * gradient_inv_length2, 0.0f, 1.0f);
        int r = (int)(col0_r + col_delta_r * t);
        int g = (int)(col0_g + col_delta_g * t);
        int b = (int)(col0_b + col_delta_b * t);
        vert->col = (r << IM_COL32_R_SHIFT) | (g << IM_COL32_G_SHIFT) | (b << IM_COL32_B_SHIFT) | (vert->col & IM_COL32_A_MASK);
    }
}

inline void fade_rect_filled(ImDrawList* draw, const ImVec2& pos_min, const ImVec2& pos_max, ImU32 col_one, ImU32 col_two, fade_direction direction, float rounding, ImDrawFlags flags, bool filled)
{
    const ImVec2 fade_pos_in = (direction == fade_direction::diagonally_reversed) ? ImVec2(pos_max.x, pos_min.y) : pos_min;

    const ImVec2 fade_pos_out = (direction == fade_direction::vertically) ? ImVec2(pos_min.x, pos_max.y) :
        (direction == fade_direction::horizontally) ? ImVec2(pos_max.x, pos_min.y) :
        (direction == fade_direction::diagonally) ? pos_max :
        (direction == fade_direction::diagonally_reversed) ? ImVec2(pos_min.x, pos_max.y) : ImVec2(0, 0);

    const int vtx_buffer_start = draw->VtxBuffer.Size;
    if (filled)
        draw->AddRectFilled(pos_min, pos_max, ImColor(1.f, 1.f, 1.f, ImColor(col_one).Value.w), rounding, flags);
    else
        draw->AddRect(pos_min, pos_max, ImColor(1.f, 1.f, 1.f, 1.f), rounding, flags);

    const int vtx_buffer_end = draw->VtxBuffer.Size;
    set_linear_color(draw, vtx_buffer_start, vtx_buffer_end, fade_pos_in, fade_pos_out, col_one, col_two);
}

inline void fade_text(ImDrawList* draw, const char* text, ImVec2 pos, ImU32 col_one, ImU32 col_two, float animation_time, ImFont* font = nullptr, float font_size = 0.f)
{
    if (!font)
        font = ImGui::GetFont();
    if (font_size <= 0.f)
        font_size = ImGui::GetFontSize();

    ImVec2 text_size = font->CalcTextSizeA(font_size, FLT_MAX, 0.0f, text);

    // Получаем позиции начала и конца текста
    ImVec2 gradient_p0 = pos;
    ImVec2 gradient_p1 = pos + ImVec2(text_size.x, 0); // горизонтальный градиент

    int vtx_start = draw->VtxBuffer.Size;

    draw->AddText(font, font_size, pos, IM_COL32_WHITE, text);

    int vtx_end = draw->VtxBuffer.Size;

    float angle = ImDegToRad(animation_time * 360.f);

    set_linear_color(draw, vtx_start, vtx_end, gradient_p0, gradient_p1, col_one, col_two, angle);
}


enum interpolation_type {
    expo,
    back,
    quint,
    bounce,
    elastic,
};

class c_easing
{

public:

    template <typename T>
    T* anim_container(T** state_ptr, ImGuiID id)
    {
        T* state = static_cast<T*>(GetStateStorage()->GetVoidPtr(id));
        if (!state)
            GetStateStorage()->SetVoidPtr(id, state = new T());

        *state_ptr = state;
        return state;
    }

private:


    float easing_value;

    // Easing functions
    float ease_in_quint(float t) {
        return 1 - pow(1 - t, 5);
    }

    float ease_in_expo(float t) {
        return (t == 0.0f) ? 0.0f : pow(2, 10 * t - 10);
    }

    float ease_in_elastic(float t) {
        const float c4 = (2 * IM_PI) / 2;
        return (t <= 0.01f) ? 0.0f : (t >= 0.60f) ? 1.0f : pow(2, -10 * t) * sin((t * 10 - 0.75) * c4) + 1;
    }

    float ease_in_back(float t) {
        const float c1 = 1.70158;
        const float c3 = c1 + 1;
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
    }


    float ease_in_bounce(float t) {
        float n1 = 7.5625f;
        const float d1 = 2.75f;

        if (t < 1.0f / d1) {
            return n1 * t * t;
        }
        else if (t < 2.0f / d1) {
            float reduced_t = t - 1.5f / d1;
            return n1 * reduced_t * reduced_t + 0.75f;
        }
        else if (t < 2.5f / d1) {
            float reduced_t = t - 2.25f / d1;
            return n1 * reduced_t * reduced_t + 0.9375f;
        }
        else {
            float reduced_t = t - 2.625f / d1;
            return n1 * reduced_t * reduced_t + 0.984375f;
        }
    }

public:
    struct easing_state {
        float animTime = 0.0f;
        bool reverse = false;
    };

    template <typename T>
    T easing_in_out(int animation_id, bool callback, T min, T max, float speed, interpolation_type type) {
        easing_state* state = anim_container(&state, GetCurrentWindow()->GetID(animation_id));

        state->animTime = (callback != state->reverse) ? 0.0f : ImMin(state->animTime + 0.1f * speed, 1.0f);
        state->reverse = callback;

        easing_value = (type == elastic) ? ease_in_elastic(state->animTime) :
            (type == bounce) ? ease_in_bounce(state->animTime) :
            (type == back) ? ease_in_back(state->animTime) :
            (type == expo) ? ease_in_expo(state->animTime) :
            (type == quint) ? ease_in_quint(state->animTime) : 0;

        if constexpr (std::is_same_v<T, float>) {
            return callback ? easing_value * (max - min) + min : easing_value * (min - max) + max;
        }
        else if constexpr (std::is_same_v<T, ImVec4>) {
            return ImVec4(
                callback ? easing_value * (max.x - min.x) + min.x : easing_value * (min.x - max.x) + max.x,
                callback ? easing_value * (max.y - min.y) + min.y : easing_value * (min.y - max.y) + max.y,
                callback ? easing_value * (max.z - min.z) + min.z : easing_value * (min.z - max.z) + max.z,
                callback ? easing_value * (max.w - min.w) + min.w : easing_value * (min.w - max.w) + max.w
            );
        }

        return T();
    }

    template <typename T>
    T easing_in(int animation_id, T min, T max, float speed, interpolation_type type) {
        easing_state* state = anim_container(&state, GetCurrentWindow()->GetID(animation_id));
        state->animTime = ImClamp(state->animTime + speed, 0.0f, 1.0f);

        float t = state->animTime;
        float eased = (type == back) ? ease_in_back(t) :
            (type == bounce) ? ease_in_bounce(t) :
            (type == expo) ? ease_in_expo(t) :
            (type == elastic) ? ease_in_elastic(t) :
            (type == quint) ? ease_in_quint(t) : t;

        return ImLerp(min, max, eased);
    }

    template <typename T>
    T easing_out(int animation_id, T min, T max, float speed, interpolation_type type) {
        easing_state* state = anim_container(&state, GetCurrentWindow()->GetID(animation_id));
        state->animTime = ImClamp(state->animTime + speed, 0.0f, 1.0f);

        float t = state->animTime;
        float eased = (type == back) ? ease_out_back(t) : t;

        return ImLerp(min, max, eased);
    }

    float ease_out_back(float t) {
        const float c1 = 1.70158f;
        const float c3 = c1 + 1.0f;
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2);
    }


    // Специализация для ImVec2
    template <>
    ImVec2 easing_in_out<ImVec2>(int animation_id, bool callback, ImVec2 min, ImVec2 max, float speed, interpolation_type type) {
        easing_state* state = anim_container(&state, GetCurrentWindow()->GetID(animation_id));

        state->animTime = (callback != state->reverse) ? 0.0f : min(state->animTime + 0.1f * speed, 1.0f);
        state->reverse = callback;

        easing_value = (type == elastic) ? ease_in_elastic(state->animTime) :
            (type == bounce) ? ease_in_bounce(state->animTime) :
            (type == back) ? ease_in_back(state->animTime) :
            (type == expo) ? ease_in_expo(state->animTime) :
            (type == quint) ? ease_in_quint(state->animTime) : 0;

        ImVec2 result;
        result.x = callback ? easing_value * (max.x - min.x) + min.x : easing_value * (min.x - max.x) + max.x;
        result.y = callback ? easing_value * (max.y - min.y) + min.y : easing_value * (min.y - max.y) + max.y;
        return result;
    }
};

inline std::unique_ptr<c_easing> easing = std::make_unique<c_easing>();



namespace custom
{
	void				ItemBackground(ImGuiID id, ImRect bb, bool hovered);
	bool				Tab(const char* label, const char* icon, int* v, int number);;
	bool				SquareTab(const char* label, const char* icon, int* v, int number);;
	bool				SubTab(const char* label, int* v, int number, ImColor color);
    bool				ToggleButton(const char* first_text, const char* second_text, bool* v, const ImVec2& size_arg);
	bool				ThemeButton(const char* id_theme, bool dark, const ImVec2& size_arg);
	bool				rotated_text(const char* label, bool active);
	bool				Button(const char* label, const ImVec2& size_arg);
    bool                InActiveButton(const char* label, const ImVec2& size_arg);

    bool                ChildEx(const char* name, ImGuiID id, const ImVec2& size_arg, bool cap, ImGuiWindowFlags flags, const char* icon = "");
	bool				Child(const char* str_id, const ImVec2& size = ImVec2(0, 0), bool cap = false, ImGuiWindowFlags flags = 0, bool space = false, const char* icon = "");
	bool				ChildID(ImGuiID id, const ImVec2& size = ImVec2(0, 0), bool cap = false, ImGuiWindowFlags flags = 0);
	void				EndChild();

	void				BeginGroup();
	void				EndGroup();

	bool				Checkbox(const char* label, bool* v);
	bool				CheckboxClicked(const char* label, bool* v);
    void                DrawHexGrid(
        const std::vector<std::string>& labels,
        const std::vector<int>& indicators);

	bool			    Selectable(const char* label, bool selected = false, ImGuiSelectableFlags flags = 0, const ImVec2& size = ImVec2(0, 0));
	bool				Selectable(const char* label, bool* p_selected, ImGuiSelectableFlags flags = 0, const ImVec2& size = ImVec2(0, 0));

	bool				BeginCombo(const char* label, const char* preview_value, int val = 0, bool multi = false, ImGuiComboFlags flags = 0);
	void				EndCombo();
	void				MultiCombo(const char* label, bool variable[], const char* labels[], int count);
	bool				Combo(const char* label, int* current_item, const char* const items[], int items_count, int popup_max_height_in_items = -1);
	bool				Combo(const char* label, int* current_item, const char* items_separated_by_zeros, int popup_max_height_in_items = -1);
	bool				Combo(const char* label, int* current_item, const char* (*getter)(void* user_data, int idx), void* user_data, int items_count, int popup_max_height_in_items = -1);

	bool				ColorButton(const char* desc_id, const ImVec4& col, ImGuiColorEditFlags flags = 0, const ImVec2& size = ImVec2(0, 0));
	bool				ColorEdit4(const char* label, float col[4], ImGuiColorEditFlags flags = 0);
	bool			    ColorPicker4(const char* label, float col[4], ImGuiColorEditFlags flags = 0, const float* ref_col = NULL);

	bool				KnobScalar(const char* label, ImGuiDataType data_type, void* p_data, const void* p_min, const void* p_max, const char* format, ImGuiSliderFlags flags = 0);
	bool				KnobFloat(const char* label, float* v, float v_min, float v_max, const char* format, ImGuiSliderFlags flags = 0);
	bool				KnobInt(const char* label, int* v, int v_min, int v_max, const char* format, ImGuiSliderFlags flags = 0);

	bool				SliderScalar(const char* label, ImGuiDataType data_type, void* p_data, const void* p_min, const void* p_max, const char* format, ImGuiSliderFlags flags = 0);
	bool				SliderFloat(const char* label, float* v, float v_min, float v_max, const char* format = "%d", ImGuiSliderFlags flags = 0);
	bool				SliderInt(const char* label, int* v, int v_min, int v_max, const char* format = "%d", ImGuiSliderFlags flags = 0);

	void				Separator_line();

	void				SeparatorEx(ImGuiSeparatorFlags flags, float thickness);
	void				Separator();


    bool				Keybind(const char* label, int* key, int* mode);
    bool				MiniBind(const char* label, int* key, int* mode);
    bool                Bindbox(const char* label, bool* v, int* key, int* mode);
    bool                Featuresbox(const char* label, bool* v);
}