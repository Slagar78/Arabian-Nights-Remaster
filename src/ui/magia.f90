module ui_magia
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    use :: ui, only: ui_draw_text
    implicit none

contains
    subroutine draw_magic_menu(renderer, card_tex, portrait_tex, portrait_frame_tex, y_offset)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: card_tex, portrait_tex, portrait_frame_tex
        integer, intent(in) :: y_offset
        
        type(sdl_rect) :: bg_rect, card_dst, src_rect
        type(sdl_rect) :: port_dst, frame_dst, src_port, p_src
        integer :: card_x, card_y, card_w, card_h
        
        ! 1. СНАЧАЛА ЗАДАЕМ РАЗМЕРЫ И КООРДИНАТЫ КАРТЫ
        ! (Это исправляет предупреждение 'card_y may be used uninitialized')
        card_w = 418
        card_h = 640
        card_x = (1280 - card_w) / 2
        card_y = 40 + y_offset
        
        ! 2. Затемнение фона
        call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
        call sdl_set_render_draw_color(renderer, uint8(20), uint8(20), uint8(25), uint8(180))
        bg_rect%x = 0; bg_rect%y = 0; bg_rect%w = 1280; bg_rect%h = 720
        call sdl_render_fill_rect(renderer, bg_rect)

        ! 3. РИСУЕМ МАГИЧЕСКУЮ КАРТУ
        if (card_tex%loaded) then
            src_rect%x = 0; src_rect%y = 0; src_rect%w = card_tex%w; src_rect%h = card_tex%h
            card_dst%x = card_x; card_dst%y = card_y; card_dst%w = card_w; card_dst%h = card_h
            call texture_draw_part(card_tex, renderer, src_rect, card_dst)
        end if
        
        ! 4. РИСУЕМ ПОРТРЕТ С РАМКОЙ (опущен ниже на +70)
        if (portrait_tex%loaded) then
            src_port%x = 0; src_port%y = 0; src_port%w = portrait_tex%w; src_port%h = portrait_tex%h
            port_dst%x = card_x + (418 - 192) / 2 
            port_dst%y = card_y + 70  ! Опустили ниже
            port_dst%w = 192; port_dst%h = 256
            call texture_draw_part(portrait_tex, renderer, src_port, port_dst)
        end if
        
        if (portrait_frame_tex%loaded) then
            p_src%x = 0; p_src%y = 0; p_src%w = 200; p_src%h = 256
            frame_dst%x = card_x + (418 - 200) / 2
            frame_dst%y = card_y + 80  ! Опустили ниже
            frame_dst%w = 200; frame_dst%h = 256
            call texture_draw_part(portrait_frame_tex, renderer, p_src, frame_dst)
        end if
        
        ! 5. ЗАГОЛОВОК (сдвинули вниз под портрет)
        call ui_draw_text(renderer, "MAGIA", card_x + 175, card_y + 360, 0, 0, 0)

        ! 6. СЕТКА 2x2 ДЛЯ ЗАКЛИНАНИЙ
        ! Первый ряд (Y = card_y + 420)
        call ui_draw_text(renderer, "1. Fuoco",    card_x + 60,  card_y + 420, 0, 0, 0)
        call ui_draw_text(renderer, "2. Ghiaccio", card_x + 230, card_y + 420, 0, 0, 0)
        
        ! Второй ряд (Y = card_y + 480)
        call ui_draw_text(renderer, "3. Fulmine",  card_x + 60,  card_y + 480, 0, 0, 0)
        call ui_draw_text(renderer, "4. Vento",    card_x + 230, card_y + 480, 0, 0, 0)
        
        ! Подсказка внизу карты
        call ui_draw_text(renderer, "Premi ESC", card_x + 145, card_y + 600, 150, 150, 150)
        
    end subroutine
end module ui_magia