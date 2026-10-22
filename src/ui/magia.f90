module ui_magia
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    use :: ui, only: ui_draw_text
    implicit none

contains
    subroutine draw_magic_menu(renderer, card_tex, y_offset)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: card_tex
        integer, intent(in) :: y_offset
        
        type(sdl_rect) :: bg_rect, card_dst, src_rect
        integer :: card_x, card_y, card_w, card_h
        
        ! 1. Затемнение фона
        call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
        call sdl_set_render_draw_color(renderer, uint8(20), uint8(20), uint8(25), uint8(180))
        bg_rect%x = 0; bg_rect%y = 0; bg_rect%w = 1280; bg_rect%h = 720
        call sdl_render_fill_rect(renderer, bg_rect)

        ! 2. РИСУЕМ МАГИЧЕСКУЮ КАРТУ (418x640)
        if (card_tex%loaded) then
            card_w = 418
            card_h = 640
            card_x = (1280 - card_w) / 2
            card_y = 40 + y_offset ! 40 - это чтобы карта встала по центру по вертикали
            
            src_rect%x = 0; src_rect%y = 0; src_rect%w = card_tex%w; src_rect%h = card_tex%h
            card_dst%x = card_x; card_dst%y = card_y; card_dst%w = card_w; card_dst%h = card_h
            call texture_draw_part(card_tex, renderer, src_rect, card_dst)
        end if
        
        ! 3. ЗАГОЛОВОК (выводим по центру карты)
        ! (card_x + card_w/2) - (примерно половина ширины текста)
        call ui_draw_text(renderer, "MAGIA", 590, 100 + y_offset, 0, 0, 0)

        ! 4. ЗАГЛУШКИ ПОД ИКОНКИ МАГИИ (Сетка 2x2)
        ! В будущем здесь будет вывод реальных заклинаний
        call ui_draw_text(renderer, "1. Fuoco", 500, 250 + y_offset, 0, 0, 0)
        call ui_draw_text(renderer, "2. Ghiaccio", 500, 320 + y_offset, 0, 0, 0)
        call ui_draw_text(renderer, "3. Fulmine", 500, 390 + y_offset, 0, 0, 0)
        call ui_draw_text(renderer, "4. Vento", 500, 460 + y_offset, 0, 0, 0)
        
        ! Подсказка внизу карты
        call ui_draw_text(renderer, "Premi ESC", 570, 620 + y_offset, 150, 150, 150)
        
    end subroutine
end module ui_magia