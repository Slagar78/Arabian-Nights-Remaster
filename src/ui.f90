module ui
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    implicit none

    type(c_ptr) :: default_font = c_null_ptr
    logical :: mouse_was_down = .false. ! Защита от дребезга

contains
    subroutine ui_init()
        if (ttf_init() /= 0) print *, "ОШИБКА: TTF_Init failed"
        
        ! Подключаем наш сказочный шрифт. 
        ! 24 — это размер шрифта (подбери под свои кнопки, если будет мелко)
        default_font = ttf_open_font("assets/fonts/cleopatra.ttf" // c_null_char, 24)
        
        ! Если шрифт вдруг не найден, игра не упадет, а возьмет системный
        if (.not. c_associated(default_font)) then
            print *, "ВНИМАНИЕ: Шрифт не найден! Грузим Arial."
            default_font = ttf_open_font("C:/Windows/Fonts/arial.ttf" // c_null_char, 20)
        end if
    end subroutine

    ! Вызываем в конце каждого кадра, чтобы сбросить защелку
    subroutine ui_update()
        integer(c_int), target :: mx, my
        integer(c_int) :: mask
        mask = sdl_get_mouse_state(c_loc(mx), c_loc(my))
        
        ! Если кнопка мыши отпущена, снимаем блокировку
        if (iand(mask, SDL_BUTTON_LEFT) == 0) then
            mouse_was_down = .false.
        end if
    end subroutine

    subroutine ui_draw_text(renderer, text, x, y, r, g, b)
        type(c_ptr), intent(in) :: renderer
        character(len=*), intent(in) :: text
        integer, intent(in) :: x, y, r, g, b
        type(sdl_color) :: col
        type(c_ptr) :: txt_surf, txt_tex
        integer(c_int) :: tw, th
        type(sdl_rect) :: dst

        if (c_associated(default_font)) then
            col%r = uint8(r); col%g = uint8(g); col%b = uint8(b); col%a = uint8(255)
            txt_surf = ttf_render_utf8_blended(default_font, trim(text) // c_null_char, col)
            if (c_associated(txt_surf)) then
                txt_tex = sdl_create_texture_from_surface(renderer, txt_surf)
                call sdl_free_surface(txt_surf)
                call sdl_query_texture(txt_tex, c_null_ptr, c_null_ptr, tw, th)
                ! 1. Рисуем ТЕНЬ (черная, полупрозрачная, со сдвигом +2 пикселя)
                block
                    type(sdl_color) :: shadow_col
                    type(c_ptr) :: shadow_surf, shadow_tex
                    type(sdl_rect) :: shadow_dst
                    
                    shadow_col%r = uint8(0); shadow_col%g = uint8(0); shadow_col%b = uint8(0); shadow_col%a = uint8(180)
                    shadow_surf = ttf_render_utf8_blended(default_font, trim(text) // c_null_char, shadow_col)
                    
                    if (c_associated(shadow_surf)) then
                        shadow_tex = sdl_create_texture_from_surface(renderer, shadow_surf)
                        call sdl_free_surface(shadow_surf)
                        shadow_dst%x = x + 2; shadow_dst%y = y + 2; shadow_dst%w = tw; shadow_dst%h = th
                        call sdl_render_copy(renderer, shadow_tex, c_null_ptr, shadow_dst)
                        call sdl_destroy_texture(shadow_tex)
                    end if
                end block

                ! 2. Рисуем сам ТЕКСТ (поверх тени)
                dst%x = x; dst%y = y; dst%w = tw; dst%h = th
                call sdl_render_copy(renderer, txt_tex, c_null_ptr, dst)
                call sdl_destroy_texture(txt_tex)
            end if
        end if
    end subroutine

    function ui_button(renderer, tex, x, y, w, h, label, btn_r, btn_g, btn_b, txt_r, txt_g, txt_b) result(clicked)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: tex
        integer, intent(in) :: x, y, w, h
        character(len=*), intent(in) :: label
        integer, intent(in), optional :: btn_r, btn_g, btn_b, txt_r, txt_g, txt_b
        logical :: clicked
        
        integer(c_int), target :: mx, my
        integer(c_int) :: mask
        integer :: cr, cg, cb, tr, tg, tb
        type(sdl_color) :: col
        type(c_ptr) :: txt_surf, txt_tex
        integer(c_int) :: tw, th
        type(sdl_rect) :: dst

        clicked = .false.
        mask = sdl_get_mouse_state(c_loc(mx), c_loc(my))

        cr = 255; cg = 255; cb = 255
        tr = 255; tg = 255; tb = 255

        if (present(btn_r)) cr = btn_r
        if (present(btn_g)) cg = btn_g
        if (present(btn_b)) cb = btn_b
        if (present(txt_r)) tr = txt_r
        if (present(txt_g)) tg = txt_g
        if (present(txt_b)) tb = txt_b

        ! Ховер-эффект
        if (mx >= x .and. mx <= x+w .and. my >= y .and. my <= y+h) then
            cr = min(255, cr + 40)
            cg = min(255, cg + 40)
            cb = min(255, cb + 40)
            
            ! Защита от дребезга
            if (iand(mask, SDL_BUTTON_LEFT) /= 0 .and. .not. mouse_was_down) then
                clicked = .true.
                mouse_was_down = .true.
            end if
        end if

        call texture_draw_9slice(tex, renderer, x, y, w, h, 12, cr, cg, cb)

        if (c_associated(default_font)) then
            col%r = uint8(tr); col%g = uint8(tg); col%b = uint8(tb); col%a = uint8(255)
            txt_surf = ttf_render_utf8_blended(default_font, trim(label) // c_null_char, col)
            if (c_associated(txt_surf)) then
                txt_tex = sdl_create_texture_from_surface(renderer, txt_surf)
                call sdl_free_surface(txt_surf)
                call sdl_query_texture(txt_tex, c_null_ptr, c_null_ptr, tw, th)
                dst%x = x + (w - tw)/2; dst%y = y + (h - th)/2
                dst%w = tw; dst%h = th
                call sdl_render_copy(renderer, txt_tex, c_null_ptr, dst)
                call sdl_destroy_texture(txt_tex)
            end if
        end if
    end function

    function ui_toggle_simple(renderer, tex_track, tex_thumb, x, y, w, h, state) result(clicked)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: tex_track, tex_thumb
        integer, intent(in) :: x, y, w, h
        logical, intent(inout) :: state
        logical :: clicked
        
        integer(c_int), target :: mx, my
        integer(c_int) :: mask
        integer :: padding, thumb_x, thumb_y
        integer :: tr, tg, tb
        type(sdl_rect) :: dst_thumb

        clicked = .false.
        mask = sdl_get_mouse_state(c_loc(mx), c_loc(my))

        if (mx >= x .and. mx <= x+w .and. my >= y .and. my <= y+h) then
            if (iand(mask, SDL_BUTTON_LEFT) /= 0 .and. .not. mouse_was_down) then
                clicked = .true.
                state = .not. state
                mouse_was_down = .true.
            end if
        end if

        ! ЛОГИКА ЦВЕТА (идеальные цвета iOS):
        if (state) then
            tr = 0; tg = 122; tb = 255   ! ВКЛ: Ярко-синий
        else
            tr = 120; tg = 120; tb = 120 ! ВЫКЛ: Темно-серый (как в iPhone)
        end if

        ! Рисуем трек, передавая ему вычисленный цвет
        call texture_draw_9slice(tex_track, renderer, x, y, w, h, 12, tr, tg, tb)

        ! Вычисляем позицию кружка (thumb)
        padding = (h - tex_thumb%h) / 2
        
        if (state) then
            thumb_x = x + w - tex_thumb%w - padding ! Вправо
        else
            thumb_x = x + padding                   ! Влево
        end if
        thumb_y = y + padding

        dst_thumb%x = thumb_x
        dst_thumb%y = thumb_y
        dst_thumb%w = tex_thumb%w
        dst_thumb%h = tex_thumb%h
        call texture_draw(tex_thumb, renderer, dst_thumb)
    end function

end module ui