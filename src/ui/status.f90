module ui_status
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    use :: ui, only: ui_draw_text, ui_draw_text_small
    implicit none

contains
    ! ДОБАВИЛИ ПАРАМЕТР portrait_frame_tex
    subroutine draw_character_status(renderer, portrait_tex, panel_tex, portrait_frame_tex)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: portrait_tex, panel_tex, portrait_frame_tex
        
        type(sdl_rect) :: bg_rect, port_dst, frame_dst
        type(sdl_rect) :: src_port, p_src, p_dst
        
        ! 1. Затемнение фона
        call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
        call sdl_set_render_draw_color(renderer, uint8(20), uint8(20), uint8(25), uint8(180))
        bg_rect%x = 0; bg_rect%y = 0; bg_rect%w = 1280; bg_rect%h = 720
        call sdl_render_fill_rect(renderer, bg_rect)

        ! 2. РИСУЕМ РАМКУ ПЕРГАМЕНТА
        if (panel_tex%loaded) then
            p_src%x = 0; p_src%y = 0; p_src%w = 960; p_src%h = 640
            p_dst%x = 160; p_dst%y = 40; p_dst%w = 960; p_dst%h = 640
            call texture_draw_part(panel_tex, renderer, p_src, p_dst)
        end if

        ! ЛЕВАЯ КОЛОНКА: ПОРТРЕТ
        if (portrait_tex%loaded) then
            src_port%x = 0; src_port%y = 0; src_port%w = portrait_tex%w; src_port%h = portrait_tex%h
            port_dst%x = 354; port_dst%y = 226; port_dst%w = 192; port_dst%h = 256
            call texture_draw_part(portrait_tex, renderer, src_port, port_dst)
        end if
        
        ! ВОЗВРАЩАЕМ РАМКУ ПОРТРЕТА (рисуем ПОВЕРХ портрета)
        if (portrait_frame_tex%loaded) then
            p_src%x = 0; p_src%y = 0; p_src%w = 200; p_src%h = 256
            frame_dst%x = 350; frame_dst%y = 226; frame_dst%w = 200; frame_dst%h = 256
            call texture_draw_part(portrait_frame_tex, renderer, p_src, frame_dst)
        end if
        
        ! ИМЯ: Голубой цвет
        call ui_draw_text(renderer, "Shukran", 415, 490, 0, 200, 255)
        
        ! УРОВЕНЬ: Разделенный
        call ui_draw_text(renderer, "Livello", 405, 520, 40, 20, 10)
        call ui_draw_text(renderer, "12", 480, 520, 150, 255, 150)

        ! ЦЕНТРАЛЬНАЯ КОЛОНКА: HP/MP
        call ui_draw_text(renderer, "HP: 120 / 120", 580, 240, 255, 100, 100)
        call ui_draw_text(renderer, "MP:  45 /  50", 580, 280, 100, 150, 255)

        ! Характеристики (Выравниваем в колонку)
        call ui_draw_text_small(renderer, "FORZA:",       580, 350, 255, 255, 255)
        call ui_draw_text_small(renderer, "RESISTENZA:",  580, 380, 255, 255, 255)
        call ui_draw_text_small(renderer, "AGILITA:",     580, 410, 255, 255, 255)
        call ui_draw_text_small(renderer, "INTELLIGENZA:",580, 440, 255, 255, 255)
        
        ! Цифры статов
        call ui_draw_text_small(renderer, "4", 760, 350, 255, 255, 255)
        call ui_draw_text_small(renderer, "4", 760, 380, 255, 255, 255)
        call ui_draw_text_small(renderer, "4", 760, 410, 255, 255, 255)
        call ui_draw_text_small(renderer, "4", 760, 440, 255, 255, 255)
        
        call ui_draw_text_small(renderer, "EXP: 450 / 1000", 580, 500, 150, 255, 150)

        ! ПРАВАЯ КОЛОНКА: ИНВЕНТАРЬ
        call ui_draw_text(renderer, "ZAINO", 820, 240, 255, 215, 0)
        
        call ui_draw_text_small(renderer, "1. Scimitarra [E]", 820, 290, 255, 255, 255)
        call ui_draw_text_small(renderer, "2. Pozione",        820, 320, 255, 255, 255)
        call ui_draw_text_small(renderer, "3. Armatura   [E]", 820, 350, 255, 255, 255)
        call ui_draw_text_small(renderer, "4. Vuoto",          820, 380, 130, 130, 130)
        call ui_draw_text_small(renderer, "5. Vuoto",          820, 410, 130, 130, 130)

        ! Деньги
        call ui_draw_text_small(renderer, "Oro: 150", 820, 500, 255, 215, 0)
        
        ! Подсказка внизу
        call ui_draw_text(renderer, "Premi ESC per chiudere", 530, 620, 150, 150, 150)
        
    end subroutine
end module ui_status