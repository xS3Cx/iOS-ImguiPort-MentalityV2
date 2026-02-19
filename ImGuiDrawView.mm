// ImGuiDrawView.mm — MENTALITY V2 iOS/Metal Port
// Ported from Windows/D3D11 backend to Metal/iOS
// Ported By Alexzero 

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// ImGui core
#define IMGUI_DEFINE_MATH_OPERATORS
#import "IMGUI/imgui.h"
#import "IMGUI/imgui_internal.h"
#import "IMGUI/imgui_impl_metal.h"

// MENTALITY V2 iOS-ported modules
#import "MentalityUI/ios_compat.h"
#import "MentalityUI/imgui_settings_ios.h"
#import "MentalityUI/font_defines.h"
#import "MentalityUI/font.h"
#import "MentalityUI/custom_widgets_ios.h"
#import "MentalityUI/custom_popup_ios.h"
#import "MentalityUI/notifications_ios.h"

// Existing project headers
#import "Esp/CaptainHook.h"
#import "Esp/ImGuiDrawView.h"

// Hooking / patching
#import "5Toubun/NakanoIchika.h"
#import "5Toubun/NakanoNino.h"
#import "5Toubun/NakanoMiku.h"
#import "5Toubun/NakanoYotsuba.h"
#import "5Toubun/NakanoItsuki.h"
#import "5Toubun/dobby.h"

#define kWidth  [UIScreen mainScreen].bounds.size.width
#define kHeight [UIScreen mainScreen].bounds.size.height
#define kScale  [UIScreen mainScreen].scale
#define patch_NULL(a, b) vm(ENCRYPTOFFSET(a), strtoul(ENCRYPTHEX(b), nullptr, 0))
#define patch(a, b)      vm_unity(ENCRYPTOFFSET(a), strtoul(ENCRYPTHEX(b), nullptr, 0))

// ============================================================================
// MARK: - Forward declarations & globals
// ============================================================================

@interface ImGuiDrawView () <MTKViewDelegate>
@property (nonatomic, strong) id<MTLDevice>       device;
@property (nonatomic, strong) id<MTLCommandQueue>  commandQueue;
@end

// ============================================================================
// MARK: - Global child toggle tracking (UIKit touch → ImGui toggle)
// ============================================================================

#include <vector>
#include <set>

struct ChildToggleRect {
    ImRect bb;
    ImGuiID id;
};

static std::vector<ChildToggleRect> g_child_toggle_rects;   // rebuilt each frame
static std::set<ImGuiID>            g_child_toggle_pending; // IDs clicked by touch

void RegisterChildToggle(ImGuiID id, const ImRect& bb) {
    g_child_toggle_rects.push_back({bb, id});
}

bool ConsumeChildToggleClick(ImGuiID id) {
    auto it = g_child_toggle_pending.find(id);
    if (it != g_child_toggle_pending.end()) {
        g_child_toggle_pending.erase(it);
        return true;
    }
    return false;
}

void ClearChildToggleRects() {
    g_child_toggle_rects.clear();
}

// ============================================================================
// MARK: - Style variables (from PC main.cpp / main.h)
// ============================================================================

static bool init_done = false;

static bool checkboxes[60];
static int slider_int_vals[30];
static float color_edit[10][4];
static int combo_vals[30];
static int keybind_vals[30];
static int keybind_mode_vals[30];
static const char* combo_list[] = {
    "AK-47", "M4A4", "AWP", "Desert Eagle", "Glock-18", "USP-S"
};

static float menu_alpha = 1.F;
static bool menu_active = true;
static bool MenDeal = true;

static char UserName[50] = { "" };

static ImGuiColorEditFlags picker_flags = ImGuiColorEditFlags_NoSidePreview | ImGuiColorEditFlags_AlphaBar | ImGuiColorEditFlags_NoInputs | ImGuiColorEditFlags_AlphaPreview;

static float slider_float = 0.5f;
static int select1 = 0;
static float col[4] = { 0.9f, 0.5f, 0.35f, 0.5f };

static bool tab_is_changed = false;
static float tab_offset = 0.f;

// ============================================================================
// MARK: - Helper functions (from PC main.cpp)
// ============================================================================

void UpdateFloatWithLerp(bool& condition, float& a, float b, float cc) {
    float deltaTime = ImGui::GetIO().DeltaTime;
    float speed = 11.0f;
    if (condition) {
        a = ImLerp(a, cc, deltaTime * speed);
        if (ImAbs(a - cc) < 30.f) {
            condition = false;
        }
    }
    else {
        a = ImLerp(a, b, deltaTime * speed);
    }
}

// ============================================================================
// MARK: - SetupProfessionalDarkStyle()
// Ported from MENTALITY V2 PC → Metal/iOS — identical color values
// ============================================================================

void SetupProfessionalDarkStyle() {
    // -----------------------------------------------------------------------
    // Styl MENTALITY V2 — profesjonalny dark mode
    // Kopia 1:1 z wersji PC (D3D11/Win32)
    // Żadne kolory, roundingi, spacingi, paddingi NIE zostały zmienione
    // -----------------------------------------------------------------------

    ImGuiStyle& s = ImGui::GetStyle();
    s.FramePadding     = ImVec2(15, 20);
    s.ItemSpacing      = ImVec2(10, 10);
    s.FrameRounding    = 2.f;
    s.WindowRounding   = 20.f;
    s.WindowBorderSize = 0.f;
    s.PopupBorderSize  = 0.f;
    s.WindowPadding    = ImVec2(0, 0);
    s.ChildBorderSize  = 1.f;

    s.Colors[ImGuiCol_Border]       = ImVec4(0.f, 0.f, 0.f, 0.f);
    s.Colors[ImGuiCol_Separator]    = ImVec4(1.f, 1.f, 1.f, 0.2f);
    s.Colors[ImGuiCol_BorderShadow] = ImVec4(0.f, 0.f, 0.f, 0.f);

    s.WindowShadowSize = 0;
    s.PopupRounding    = 5.f;
    s.ScrollbarSize    = 1;
    s.SeparatorTextPadding = ImVec2(10, 10);
}

// ============================================================================
// MARK: - Tab system (from PC main.h)
// ============================================================================

struct s_tab {
    std::vector<const char*> icon;
    std::vector<const char*> name;
};

static bool once_init = false;

// Tab class for iOS (same content layout as PC, simplified tab bar)
static class c_tabs_ios {
private:
    int current_idx;
    int stored_idx;
    std::vector<s_tab> tab_selection;
    float content_size;

public:
    c_tabs_ios() : current_idx(0), stored_idx(0), content_size(0) {}

    c_tabs_ios(std::vector<s_tab> tab_info) {
        this->current_idx = 0;
        this->stored_idx = 0;
        this->tab_selection = tab_info;
    }

    int GetCurrentTab() { return current_idx; }
    float GetCurrentScroll() { return current_scroll; }

    bool IsTabActive(int id) {
        if (bool(this->stored_idx == id) || tab_want_to_change)
            return true;
        else {
            ImGui::Dummy(ImVec2(c::bg::size.x, c::bg::size.y - 100));
            return false;
        }
    }

    void DrawTabs(bool horizontal) {
        ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(8, 8));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(0, 0));
        ImGui::SetCursorPos(ImVec2(8, horizontal ? 8 : 26.f));
        ImGui::BeginChild("Tabs", ImVec2(ImGui::GetContentRegionAvail().x - 8, ImGui::GetContentRegionAvail().y), false, ImGuiWindowFlags_NoScrollbar);
        {
            if (!once_init) {
                this->stored_idx = 0;
                once_init = true;
            }

            if (horizontal) {
                for (int i = 0; i < (int)tab_selection[0].icon.size(); i++) {
                    if (custom::SquareTab(tab_selection[0].name[i], tab_selection[0].icon[i], &this->stored_idx, i)) {
                        tab_want_to_change = true;
                        this->stored_idx = i;
                        this->current_idx = i;
                    }
                    ImGui::SameLine();
                }
            }
            else {
                for (int i = 0; i < (int)tab_selection[0].icon.size(); i++) {
                    if (i == 0)
                        ImGui::Text(" Environment & Transport");
                    else if (i == 3)
                        ImGui::Text(" Players & Vision");
                    else if (i == 6)
                        ImGui::Text(" Utilities & Settings");

                    if (custom::Tab(tab_selection[0].name[i], tab_selection[0].icon[i], &this->stored_idx, i)) {
                        tab_want_to_change = true;
                        this->stored_idx = i;
                        this->current_idx = i;
                    }
                }
            }

            current_scroll = ImLerp(current_scroll, this->stored_idx * c::bg::size.x, ImGui::GetIO().DeltaTime * 7.f);

            if (tab_want_to_change) {
                if (abs(current_scroll - (this->stored_idx * c::bg::size.x)) < 8.f)
                    tab_want_to_change = false;
            }
            content_size = ImGui::GetCurrentWindow()->ContentSize.x;
        }
        ImGui::EndChild();
        ImGui::PopStyleVar(2);
    }
} g_tabs;

// ============================================================================
// MARK: - InitImGuiMetal
// ============================================================================

void InitImGuiMetal(id<MTLDevice> device) {
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO(); (void)io;
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    // Font configuration — same as PC version with Poppins + icomoon icons
    ImFontConfig cfg;
    cfg.FontBuilderFlags = 0;

    // Default font: Poppins Medium 18px
    io.Fonts->AddFontFromMemoryTTF(PoppinsMedium, sizeof(PoppinsMedium), 18.f, &cfg, io.Fonts->GetGlyphRangesDefault());

    // Icomoon icon font (merged)
    static ImWchar icomoon_ranges[] = { 0x1, 0xFFFF, 0 };
    static ImFontConfig icomoon_config;
    icomoon_config.OversampleH = icomoon_config.OversampleV = 1;
    icomoon_config.MergeMode = true;
    icomoon_config.GlyphOffset.y = 3.f;
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 18.f, &icomoon_config, icomoon_ranges);

    // Additional font variants — same sizes as PC
    font::default_r = io.Fonts->AddFontFromMemoryTTF(PoppinsRegular, sizeof(PoppinsRegular), 18.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 18.f, &icomoon_config, icomoon_ranges);

    font::default_m = io.Fonts->AddFontFromMemoryTTF(PoppinsMedium, sizeof(PoppinsMedium), 18.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 18.f, &icomoon_config, icomoon_ranges);

    font::default_s = io.Fonts->AddFontFromMemoryTTF(PoppinsSemiBold, sizeof(PoppinsSemiBold), 18.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 18.f, &icomoon_config, icomoon_ranges);

    font::esp_font = io.Fonts->AddFontFromMemoryTTF(PoppinsMedium, sizeof(PoppinsMedium), 15.f, &cfg, io.Fonts->GetGlyphRangesDefault());

    font::description_font = io.Fonts->AddFontFromMemoryTTF(PoppinsMedium, sizeof(PoppinsMedium), 16.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 16.f, &icomoon_config, icomoon_ranges);

    icomoon_config.GlyphOffset.y = 3.f;
    font::regular_m = io.Fonts->AddFontFromMemoryTTF(PoppinsRegular, sizeof(PoppinsRegular), 23.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 23.f, &icomoon_config, icomoon_ranges);

    font::regular_l = io.Fonts->AddFontFromMemoryTTF(PoppinsRegular, sizeof(PoppinsRegular), 35.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    icomoon_config.GlyphOffset.y = 0.f;
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 35.f, &icomoon_config, icomoon_ranges);

    font::s_inter_semibold = io.Fonts->AddFontFromMemoryTTF(PoppinsSemiBold, sizeof(PoppinsSemiBold), 17.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    font::inter_bold = io.Fonts->AddFontFromMemoryTTF(PoppinsSemiBold, sizeof(PoppinsSemiBold), 18.f, &cfg, io.Fonts->GetGlyphRangesDefault());

    icomoon_config.GlyphOffset.y = 3.f;
    font::inter_semibold = io.Fonts->AddFontFromMemoryTTF(PoppinsSemiBold, sizeof(PoppinsSemiBold), 29.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 27.f, &icomoon_config, icomoon_ranges);

    font::small_font = io.Fonts->AddFontFromMemoryTTF(PoppinsSemiBold, sizeof(PoppinsSemiBold), 14.f, &cfg, io.Fonts->GetGlyphRangesDefault());
    font::inter_medium = io.Fonts->AddFontFromMemoryTTF(PoppinsMedium, sizeof(PoppinsMedium), 17.f, &cfg, io.Fonts->GetGlyphRangesDefault());

    // Icon-only fonts for logo / page headers
    font::icomoon_logo = io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 35.f, nullptr, icomoon_ranges);
    font::icomoon_page = io.Fonts->AddFontFromMemoryCompressedBase85TTF(icomoon_compressed_data_base85, 23.f, nullptr, icomoon_ranges);

    // Metal backend init
    ImGui_ImplMetal_Init(device);

    // Setup professional dark style (identical to PC)
    SetupProfessionalDarkStyle();
}

// ============================================================================
// MARK: - ShutdownImGuiMetal
// ============================================================================

void ShutdownImGuiMetal() {
    ImGui_ImplMetal_Shutdown();
    ImGui::DestroyContext();
}

// ============================================================================
// MARK: - RenderImGuiUI — 100% identical UI logic as PC
// ============================================================================

void RenderImGuiUI() {
    // Tab setup — same as PC
    static std::vector<s_tab> tabs_info;
    static bool tabs_initialized = false;
    static CNotifications p_notif;

    if (!tabs_initialized) {
        tabs_info.push_back({ {ICON_CAR_FILL, ICON_EYE_2_FILL, ICON_TRANSLATE_2_AI_LINE, ICON_GROUP_3_FILL, ICON_COMPASS_FILL, ICON_EARTH_2_FILL, ICON_MIC_AI_FILL, ICON_BOMB_FILL },
            { "Car", "ESP", "Lang", "Players", "Radar", "World", "Misc", "Exploits" } });
        g_tabs = c_tabs_ios(tabs_info);
        tabs_initialized = true;
    }

    // Update tabs for language (only update the labels/icons array, don't reconstruct g_tabs)
    tabs_info[0] = { {ICON_CAR_FILL, ICON_EYE_2_FILL, ICON_TRANSLATE_2_AI_LINE, ICON_GROUP_3_FILL, ICON_COMPASS_FILL, ICON_EARTH_2_FILL, ICON_MIC_AI_FILL, ICON_BOMB_FILL },
        { c::lang ? "载具" : "Car", c::lang ? "透视" : "ESP", c::lang ? "语言" : "Lang", c::lang ? "玩家" : "Players", c::lang ? "雷达" : "Radar", c::lang ? "世界" : "World", c::lang ? "麦克风" : "Misc", c::lang ? "漏洞" : "Exploits" } };

    // Do NOT reconstruct g_tabs here — it resets stored_idx to 0 every frame

    UpdateFloatWithLerp(tab_is_changed, tab_offset, 0.f, 600.f);

    ImGuiWindowFlags flags = ImGuiWindowFlags_NoTitleBar
        | ImGuiWindowFlags_NoBringToFrontOnFocus
        | ImGuiWindowFlags_NoResize
        | ImGuiWindowFlags_AlwaysAutoResize
        | ImGuiWindowFlags_NoBackground;

    // Main menu window — positioned directly below tab bar with no gap
    ImVec2 main_window_pos = ImVec2(10, 100);  // Will be updated after main window is rendered
    ImGui::SetNextWindowPos(ImVec2(10, 100), ImGuiCond_FirstUseEver);
    ImGui::SetNextWindowSize(c::bg::size);
    ImGui::Begin("IMGUI MENU MENTALITY V2", nullptr, flags);
    {
        ImGuiWindow* current_window = ImGui::GetCurrentWindow();
        main_window_pos = current_window->Pos;

        c::anim::speed = ImGui::GetIO().DeltaTime * 12.f;
        c::bg::menu_bb = ImGui::GetCurrentWindow()->Rect();

        const ImVec2& pos = ImGui::GetWindowPos();
        const ImVec2& region = ImGui::GetContentRegionMax();
        const ImGuiStyle& s = ImGui::GetStyle();

        menu_alpha = ImLerp(menu_alpha, menu_active ? 1.f : 0.f, c::anim::speed);
        ImGui::GetStyle().Alpha = menu_alpha;

        // Background fill (solid — no D3D11 blur)
        ImGui::GetWindowDrawList()->AddRectFilled(pos, pos + c::bg::size, utils::GetColorWithAlpha(c::window_bg_color, c::window_bg_color.Value.w * ImGui::GetStyle().Alpha), c::bg::rounding, ImDrawFlags_RoundCornersBottom);

        // Top block
        ImGui::GetWindowDrawList()->AddRectFilled(pos + ImVec2(0, 60), pos + c::bg::size, utils::GetColorWithAlpha(c::window_bg_color, c::window_bg_color.Value.w / 2), c::bg::rounding, ImDrawFlags_RoundCornersBottom);

        // Logo text
        ImGui::PushFont(font::inter_bold);
        fade_text(ImGui::GetWindowDrawList(), "MENTALITY v2", ImVec2(pos.x + 60, utils::center_text(pos, pos + ImVec2(c::bg::size.x, 60), "MENTALITY v2").y - ImGui::CalcTextSize("MENTALITY v2").y / 2), c::label::active, c::label::active, 0);
        ImGui::PopFont();

        fade_text(ImGui::GetWindowDrawList(), "Fine-tuning for sure wins", ImVec2(pos.x + 60, utils::center_text(pos, pos + ImVec2(c::bg::size.x, 60), "Fine-tuning for sure wins").y + ImGui::CalcTextSize("Fine-tuning for sure wins").y / 2), c::label::default_color, c::label::default_color, 0);

        ImGui::PushFont(font::regular_l);
        fade_text(ImGui::GetWindowDrawList(), ICON_TETHER_USDT_FILL, ImVec2(pos.x + 35, pos.y + 36) - ImGui::CalcTextSize(ICON_TETHER_USDT_FILL) / 2, c::anim::active, c::dark_color, 0);
        ImGui::PopFont();

        // Settings button
        ImGui::SetCursorPos(ImVec2(c::bg::size.x - 95, 15));
        if (custom::InActiveButton(ICON_SETTINGS_4_FILL, ImVec2(35, 35)))
            settings_popup.open();
        ImGui::SameLine();
        custom::InActiveButton(ICON_CLOSE_FILL, ImVec2(35, 35));

        // Theme update
        {
            UpdateTheme(bTheme, ImGui::GetIO().DeltaTime * 12.f);

            ImGui::PushStyleVar(ImGuiStyleVar_CellPadding, ImVec2(10.0f, 5.0f));

            ImGui::SetCursorPos(ImVec2(10.f, 70 + tab_offset));
            ImGui::BeginChild("FRAMECHILD", ImVec2(c::bg::size.x * 2 - 40, c::bg::size.y - 85), false, ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoScrollWithMouse);
            {
                ImGuiContext& g = *GImGui;
                ImGuiWindow* window = g.CurrentWindow;
                window->Scroll.x = g_tabs.GetCurrentScroll();

                // ============================================================
                // TAB 0: Aimbot + Menu settings
                // ============================================================
                if (g_tabs.IsTabActive(0)) {
                    ImGui::BeginGroup(); {
                        custom::Child(c::lang ? "自瞄" : "Aimbot:This decsription for child", ImVec2(350, 300), true, 0, 0, ICON_SWORD_FILL); {

                            if (custom::Featuresbox(c::lang ? "显示载具" : "Target Prediction", &checkboxes[9]))
                                features_popup.open();

                            static bool   cb[6] = {};
                            static int    si[5] = {};
                            static float  tracer_col[4] = { 0.0f, 0.5f, 1.0f, 1.0f };
                            static float  glow_col[4] = { 1.0f, 0.5f, 0.0f, 1.0f };

                            static const char* radar_levels[] = { "Off", "Minimal", "Full" };
                            static int combo_radar = 0;
                            static const char* footprint_types[] = { "Allies", "Enemies", "None" };
                            static int combo_footprints = 0;
                            static const char* recoil_items[] = { "Low", "Medium", "High" };
                            static int combo_recoil = 0;

                            custom::SliderInt(c::lang ? "雷达范围" : "Radar Range", &si[2], 0, 500);
                            custom::Combo(c::lang ? "雷达模式" : "Radar Mode", &combo_radar, radar_levels, IM_ARRAYSIZE(radar_levels));
                            custom::Checkbox(c::lang ? "显示脚印" : "Footprints", &cb[3]);
                            custom::Combo(c::lang ? "脚印类型" : "Footprint Type", &combo_footprints, footprint_types, IM_ARRAYSIZE(footprint_types));
                            custom::ColorEdit4(c::lang ? "追踪颜色" : "Tracer Color", tracer_col, picker_flags);
                            custom::SliderInt(c::lang ? "追踪数量" : "Tracer Count", &si[3], 1, 50);
                            custom::Combo(c::lang ? "后座力等级" : "Recoil Level", &combo_recoil, recoil_items, IM_ARRAYSIZE(recoil_items));
                            custom::ColorEdit4(c::lang ? "光晕颜色" : "Glow Color", glow_col, picker_flags);
                            custom::Checkbox(c::lang ? "自动装填" : "Auto Reload", &cb[4]);
                        }
                        custom::EndChild();

                        custom::Child(c::lang ? "空子窗口" : "Menu settings:This decsription for child", ImVec2(350, ImGui::GetContentRegionAvail().y - ImGui::GetStyle().FramePadding.y * 2) + ImVec2(0, tab_offset), true, 0, 0, ICON_BOMB_FILL);

                        if (custom::Button(ICON_SWORD_FILL " BUTTON WITH ICON", ImVec2(ImGui::GetContentRegionAvail().x, 35))) {
                            p_notif.AddMessage("Config created\t ^6Config 123123 created.", ICON_NOTIFICATION_FILL, c::anim::active);
                        }

                        if (custom::Button(" CHANGE THEME", ImVec2(ImGui::GetContentRegionAvail().x, 35))) {
                            bTheme = !bTheme;
                        }

                        if (custom::Button("Change language", ImVec2(ImGui::GetContentRegionAvail().x, 35))) {
                            c::lang = !c::lang;
                        }

                        custom::SliderInt(c::lang ? "粒子;粒子" : "Particle count", &particle::PARTICLE_COUT, 15, 150);

                        custom::ColorEdit4(c::lang ? "第一渐变色" : "First gradient color", (float*)&c::anim::active, picker_flags);
                        custom::ColorEdit4(c::lang ? "子一渐变色" : "Second gradient color", (float*)&c::dark_color, picker_flags);

                        ImGui::InputTextEx("Username", NULL, UserName, IM_ARRAYSIZE(UserName), ImVec2(ImGui::GetContentRegionAvail().x, 40), 0);

                        custom::EndChild();
                    } ImGui::EndGroup();

                    ImGui::SameLine();

                    ImGui::BeginGroup(); {
                        custom::Child(c::lang ? "透视" : "Wallhack:This decsription for child", ImVec2(350, ImGui::GetContentRegionAvail().y - ImGui::GetStyle().FramePadding.y * 2) + ImVec2(0, tab_offset), true, 0, true, ICON_TARGET_FILL); {

                            custom::Combo(c::lang ? "启用透视" : "Select gun", &combo_vals[0], combo_list, IM_ARRAYSIZE(combo_list));
                            custom::Checkbox(c::lang ? "启用透视" : "Enable Wallhack", &checkboxes[4]);
                            custom::Checkbox(c::lang ? "显示敌人" : "Show Enemies", &checkboxes[5]);
                            custom::Checkbox(c::lang ? "显示血量" : "Show Health", &checkboxes[6]);
                            custom::Checkbox(c::lang ? "显示护甲" : "Show Armor", &checkboxes[7]);
                            custom::Checkbox(c::lang ? "显示武器" : "Show Weapons", &checkboxes[8]);

                            if (custom::Featuresbox(c::lang ? "显示载具" : "Show Vehicles", &checkboxes[9]))
                                vehicle_popup.open();

                            custom::Checkbox(c::lang ? "显示投掷物" : "Show Grenades", &checkboxes[10]);
                            custom::Checkbox(c::lang ? "无障碍物" : "No Obstacles", &checkboxes[11]);
                            custom::ColorEdit4(c::lang ? "敌人颜色" : "Enemy Color", col, picker_flags);
                            custom::ColorEdit4(c::lang ? "物品颜色" : "Item Color", col, picker_flags);
                            custom::SliderInt(c::lang ? "最大距离" : "Max Distance", &slider_int_vals[2], 0, 500);
                            custom::Checkbox(c::lang ? "显示队伍" : "Show Teammates", &checkboxes[12]);
                            custom::Checkbox(c::lang ? "显示名字" : "Show Names", &checkboxes[13]);
                            custom::Checkbox(c::lang ? "显示死亡箱" : "Show Dead Boxes", &checkboxes[14]);
                            custom::Checkbox(c::lang ? "高亮模式" : "Highlight Mode", &checkboxes[15]);
                            custom::Checkbox(c::lang ? "自动标记" : "Auto Mark", &checkboxes[16]);
                        }
                        custom::EndChild();
                    }
                    ImGui::EndGroup();
                }

                // ============================================================
                // TAB 1: Combat Settings + ESP Preview
                // ============================================================
                if (g_tabs.IsTabActive(1)) {
                    ImGui::SetCursorPos(ImVec2(c::bg::size.x + 15, 0));
                    ImGui::BeginGroup(); {
                        custom::Child(c::lang ? "基础功能" : "Combat Settings:Esp features", ImVec2(350, ImGui::GetContentRegionAvail().y - ImGui::GetStyle().FramePadding.y * 2), true, 0, false, ICON_PIC_AI_FILL); {

                            static bool   cb2[6] = {};
                            static int    si2[5] = {};
                            static float  tracer_col2[4] = { 0.0f, 0.5f, 1.0f, 1.0f };
                            static float  glow_col2[4] = { 1.0f, 0.5f, 0.0f, 1.0f };

                            static const char* radar_levels2[] = { "Off", "Minimal", "Full" };
                            static int combo_radar2 = 0;
                            static const char* footprint_types2[] = { "Allies", "Enemies", "None" };
                            static int combo_footprints2 = 0;
                            static const char* recoil_items2[] = { "Low", "Medium", "High" };
                            static int combo_recoil2 = 0;

                            custom::SliderInt(c::lang ? "雷达范围" : "Radar Range", &si2[2], 0, 500);
                            custom::Combo(c::lang ? "雷达模式" : "Radar Mode", &combo_radar2, radar_levels2, IM_ARRAYSIZE(radar_levels2));
                            custom::Checkbox(c::lang ? "显示脚印" : "Footprints", &cb2[3]);
                            custom::Combo(c::lang ? "脚印类型" : "Footprint Type", &combo_footprints2, footprint_types2, IM_ARRAYSIZE(footprint_types2));
                            custom::ColorEdit4(c::lang ? "追踪颜色" : "Tracer Color", tracer_col2, picker_flags);
                            custom::SliderInt(c::lang ? "追踪数量" : "Tracer Count", &si2[3], 1, 50);
                            custom::Combo(c::lang ? "后座力等级" : "Recoil Level", &combo_recoil2, recoil_items2, IM_ARRAYSIZE(recoil_items2));
                            custom::ColorEdit4(c::lang ? "光晕颜色" : "Glow Color", glow_col2, picker_flags);
                            custom::Checkbox(c::lang ? "自动装填" : "Auto Reload", &cb2[4]);
                        }
                        custom::EndChild();
                    }
                    ImGui::EndGroup();

                    ImGui::SameLine();

                    ImGui::BeginGroup(); {
                        custom::Child(c::lang ? "透视预览" : "ESP Preview:Esp visible items change", ImVec2(350, ImGui::GetContentRegionAvail().y - ImGui::GetStyle().FramePadding.y * 2), true, 0, true, ICON_EYE_FILL); {
                            // ESP preview placeholder — D3D11 texture removed
                            ImGui::Text("ESP Preview Area");
                        }
                        custom::EndChild();
                    }
                    ImGui::EndGroup();
                }

            }
            ImGui::EndChild();
            ImGui::PopStyleVar(1);
        }

        // Notifications
        p_notif.Render();

        // Features popup
        if (features_popup.begin(300.0f)) {
            custom::Checkbox(c::lang ? "无限子弹" : "Unlimited Ammo", &checkboxes[16]);
            custom::Checkbox(c::lang ? "透视" : "Wallhack", &checkboxes[17]);
            custom::Checkbox(c::lang ? "快速切换武器" : "Fast Weapon Swap", &checkboxes[18]);
            custom::Checkbox(c::lang ? "自动射击" : "Auto Fire", &checkboxes[19]);
            custom::Checkbox(c::lang ? "快速装弹" : "Rapid Reload", &checkboxes[20]);
            custom::MiniBind("keybind mini", &keybind_vals[5], &keybind_mode_vals[5]);
            custom::ToggleButton("Toggle", "Hold", &checkboxes[21], ImVec2(ImGui::GetContentRegionAvail().x, 40));

            if (custom::Button("Close", ImVec2(ImGui::GetContentRegionAvail().x, 40)))
                features_popup.close();
            features_popup.end();
        }

        // Settings popup
        if (settings_popup.begin(340.0f)) {
            custom::ColorEdit4(c::lang ? "第一渐变色" : "First gradient color", (float*)&c::anim::active, picker_flags);
            custom::ColorEdit4(c::lang ? "子一渐变色" : "Second gradient color", (float*)&c::dark_color, picker_flags);

            const char* font_weights[] = { "Regular", "Medium", "Semibold" };
            ImFont* default_fonts[] = { font::default_r, font::default_m, font::default_s };

            custom::Combo(c::lang ? "启用透视" : "Font weight", &c::selected_font, font_weights, IM_ARRAYSIZE(font_weights));
            ImGui::GetIO().FontDefault = default_fonts[c::selected_font];

            const char* offset_sides[] = { ICON_ARROWS_RIGHT_LINE " From the left", ICON_ARROWS_LEFT_LINE " From the right" };
            custom::Combo(c::lang ? "启用透视" : "Animation side", &c::anim_offset_side, offset_sides, IM_ARRAYSIZE(offset_sides));

            custom::ToggleButton(ICON_MOONLIGHT_FILL, ICON_SUN_2_FILL, &bTheme, ImVec2(ImGui::GetContentRegionAvail().x, 40));

            if (custom::Button("Save", ImVec2(ImGui::GetContentRegionAvail().x, 50)))
                settings_popup.close();
            settings_popup.end();
        }

        // Vehicle popup
        if (vehicle_popup.begin(340.0f)) {
            static const char* car_models[] = {
                "Ford Mustang", "Chevrolet Camaro", "Dodge Charger", "BMW M3",
                "Audi R8", "Porsche 911", "Ferrari 488", "Lamborghini Huracán",
                "McLaren 720S", "Tesla Model S", "Nissan GT-R", "Mercedes-AMG GT",
                "Aston Martin DB11", "Chevrolet Corvette", "Jaguar F-Type"
            };
            static bool car_box[15] = { false };
            for (int i = 0; i < IM_ARRAYSIZE(car_models); i++)
                custom::Checkbox(car_models[i], &car_box[i]);

            if (custom::Button("Close", ImVec2(ImGui::GetContentRegionAvail().x, 40)))
                vehicle_popup.close();
            vehicle_popup.end();
        }
    }
    ImGui::End();

    // Tab bar rendered AFTER main window — uses main window's current position with no lag
    ImGui::SetNextWindowPos(ImVec2(main_window_pos.x, main_window_pos.y - 90), ImGuiCond_Always);
    ImGui::SetNextWindowSize(ImVec2(c::bg::size.x, 90));
    ImGui::Begin("TAB BAR", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoBringToFrontOnFocus | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground | ImGuiWindowFlags_NoMove);
    {
        const ImVec2& pos = ImGui::GetWindowPos();
        ImGui::GetBackgroundDrawList()->AddRectFilled(pos, pos + ImGui::GetWindowSize(), utils::GetColorWithAlpha(c::window_bg_color, c::window_bg_color.Value.w * ImGui::GetStyle().Alpha), c::bg::rounding, ImDrawFlags_RoundCornersTop);
        g_tabs.DrawTabs(true);
    }
    ImGui::End();
}

// ============================================================================
// MARK: - ImGuiDrawView implementation (Metal backend)
// ============================================================================

@implementation ImGuiDrawView

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];

    _device = MTLCreateSystemDefaultDevice();
    _commandQueue = [_device newCommandQueue];

    if (!self.device) abort();

    // Initialize ImGui with Metal backend + MENTALITY V2 fonts & style
    InitImGuiMetal(_device);

    // Register for background/foreground transitions to prevent Metal crashes
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    ShutdownImGuiMetal();
}

- (void)appWillResignActive
{
    self.mtkView.paused = YES;
}

- (void)appDidBecomeActive
{
    self.mtkView.paused = NO;
}

+ (void)showChange:(BOOL)open
{
    MenDeal = open;
}

- (MTKView *)mtkView
{
    return (MTKView *)self.view;
}

- (void)loadView
{
    CGFloat w = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.width;
    CGFloat h = [UIApplication sharedApplication].windows[0].rootViewController.view.frame.size.height;
    self.view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, w, h)];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.mtkView.device = self.device;
    self.mtkView.delegate = self;
    self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
    self.mtkView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0];
    self.mtkView.clipsToBounds = YES;
}

#pragma mark - Interaction (multitouch → ImGui)

- (void)updateIOWithTouchEvent:(UIEvent *)event
{
    UITouch *anyTouch = event.allTouches.anyObject;
    CGPoint touchLocation = [anyTouch locationInView:self.view];
    ImGuiIO &io = ImGui::GetIO();

    // Use ImGui 1.90 queue-based input API for reliable touch handling
    // NOTE: Use Mouse source (not TouchScreen) to avoid input trickling delay
    // that defers button events by one frame when position changes simultaneously.
    io.AddMouseSourceEvent(ImGuiMouseSource_Mouse);
    io.AddMousePosEvent(touchLocation.x, touchLocation.y);

    BOOL hasActiveTouch = NO;
    for (UITouch *touch in event.allTouches)
    {
        if (touch.phase != UITouchPhaseEnded && touch.phase != UITouchPhaseCancelled)
        {
            hasActiveTouch = YES;
            break;
        }
    }
    io.AddMouseButtonEvent(0, hasActiveTouch);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    // Check if touch hits any registered child toggle rect
    UITouch *anyTouch = touches.anyObject;
    CGPoint loc = [anyTouch locationInView:self.view];
    ImVec2 tp(loc.x, loc.y);
    for (size_t i = 0; i < g_child_toggle_rects.size(); i++) {
        auto& t = g_child_toggle_rects[i];
        if (t.bb.Contains(tp)) {
            g_child_toggle_pending.insert(t.id);
            break;
        }
    }
    [self updateIOWithTouchEvent:event];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self updateIOWithTouchEvent:event];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView*)view
{
    // Display size and framebuffer scale (Retina / contentScaleFactor)
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize.x = view.bounds.size.width;
    io.DisplaySize.y = view.bounds.size.height;

    CGFloat framebufferScale = view.window.screen.scale ?: UIScreen.mainScreen.scale;
    io.DisplayFramebufferScale = ImVec2(framebufferScale, framebufferScale);
    io.DeltaTime = 1 / float(view.preferredFramesPerSecond ?: 120);

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];

    // Enable/disable touch based on menu state
    if (MenDeal) {
        [self.view setUserInteractionEnabled:YES];
    } else {
        [self.view setUserInteractionEnabled:NO];
    }

    MTLRenderPassDescriptor* renderPassDescriptor = view.currentRenderPassDescriptor;
    if (renderPassDescriptor != nil)
    {
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        [renderEncoder pushDebugGroup:@"ImGui MENTALITY V2"];

        // Metal backend new frame
        ImGui_ImplMetal_NewFrame(renderPassDescriptor);
        ClearChildToggleRects(); // clear previous frame's toggle rects
        ImGui::NewFrame();

        if (MenDeal) {
            // Render MENTALITY V2 UI — identical logic as PC
            RenderImGuiUI();
        }

        // Finalize ImGui frame
        ImGui::Render();
        ImDrawData* draw_data = ImGui::GetDrawData();
        ImGui_ImplMetal_RenderDrawData(draw_data, commandBuffer, renderEncoder);

        [renderEncoder popDebugGroup];
        [renderEncoder endEncoding];

        [commandBuffer presentDrawable:view.currentDrawable];
    }

    [commandBuffer commit];
}

- (void)mtkView:(MTKView*)view drawableSizeWillChange:(CGSize)size
{
    // Nothing needed — display size updated each frame in drawInMTKView
}

@end

