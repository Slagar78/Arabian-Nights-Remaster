module game_intro
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    implicit none

contains
    subroutine play_intro(renderer)
        type(c_ptr), intent(in) :: renderer
        type(texture_t) :: tex_diamond, tex_top, tex_bot
        type(sdl_rect) :: dst_diamond, dst_top, dst_bot
        integer(c_int32_t) :: start_time, elapsed
        integer :: alpha_diamond, alpha_top, alpha_bot
        integer :: running
        type(sdl_event) :: ev
        integer :: have_event
        logical(c_bool) :: hint_res ! Переменная для результата SDL_SetHint

        ! =================================================================
        ! ВКЛЮЧАЕМ СГЛАЖИВАНИЕ (LINEAR FILTERING) ДЛЯ ЛОГОТИПА
        ! Это нужно, чтобы плавные края ромба не превращались в "лесенку".
        ! "1" = Linear, "0" = Nearest (пиксели)
        ! =================================================================
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "1" // c_null_char)

        ! Загружаем картинки
        call texture_load(tex_diamond, renderer, "assets_game/intro/diamond.png")
        call texture_load(tex_top, renderer, "assets_game/intro/Fortran_text.png")
        call texture_load(tex_bot, renderer, "assets_game/intro/text_2.png")

        ! НАСТРОЙКА КООРДИНАТ (ТВОИ РАЗМЕРЫ)
        
        ! 1. Ромб (380x360)
        dst_diamond%w = 380
        dst_diamond%h = 360
        dst_diamond%x = (1280 - dst_diamond%w) / 2  ! Центрируем по горизонтали (450)
        dst_diamond%y = 180

        ! 2. Верхний текст FORTRAN (594x96)
        dst_top%w = 594
        dst_top%h = 96
        dst_top%x = (1280 - dst_top%w) / 2          ! Центрируем (343)
        dst_top%y = 50

        ! 3. Нижний текст COMPUTER ENTERTAINMENT (503x90)
        dst_bot%w = 503
        dst_bot%h = 90
        dst_bot%x = (1280 - dst_bot%w) / 2          ! Центрируем (388)
        dst_bot%y = 580

        running = 1
        start_time = sdl_get_ticks()

        ! --- ЦИКЛ ЗАСТАВКИ (7 СЕКУНД) ---
        do while (running /= 0)
            have_event = sdl_poll_event(ev)
            do while (have_event /= 0)
                ! Проверяем ТОЛЬКО закрытие окна (крестик)
                if (ev%type_ == SDL_QUITEVENT) then
                    running = 0
                    return
                end if
                have_event = sdl_poll_event(ev)
            end do

            elapsed = sdl_get_ticks() - start_time

            ! --- ЛОГИКА АНИМАЦИИ ПРОЯВЛЕНИЯ (FADE-IN) ---
            ! 0.0 - 1.5 сек: Проявляется ромб
            if (elapsed < 1500) then
                alpha_diamond = int((real(elapsed) / 1500.0) * 255.0)
                alpha_top = 0
                alpha_bot = 0
            ! 1.5 - 2.5 сек: Проявляется верхний текст
            else if (elapsed < 2500) then
                alpha_diamond = 255
                alpha_top = int(((real(elapsed) - 1500.0) / 1000.0) * 255.0)
                alpha_bot = 0
            ! 2.5 - 3.5 сек: Проявляется нижний текст
            else if (elapsed < 3500) then
                alpha_diamond = 255
                alpha_top = 255
                alpha_bot = int(((real(elapsed) - 2500.0) / 1000.0) * 255.0)
            ! 3.5 - 7.0 сек: Всё висит на экране
            else
                alpha_diamond = 255
                alpha_top = 255
                alpha_bot = 255
            end if

            ! Завершаем экран через 7 секунд (7000 мс)
            if (elapsed > 7000) running = 0

            ! --- ОТРИСОВКА ---
            ! Очищаем экран черным
            call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(255))
            call sdl_render_clear(renderer)

            ! Рисуем ромб
            if (tex_diamond%loaded .and. alpha_diamond > 0) then
                call sdl_set_texture_alpha_mod(tex_diamond%ptr, uint8(alpha_diamond))
                call texture_draw(tex_diamond, renderer, dst_diamond)
            end if
            
            ! Рисуем верхний текст
            if (tex_top%loaded .and. alpha_top > 0) then
                call sdl_set_texture_alpha_mod(tex_top%ptr, uint8(alpha_top))
                call texture_draw(tex_top, renderer, dst_top)
            end if
            
            ! Рисуем нижний текст
            if (tex_bot%loaded .and. alpha_bot > 0) then
                call sdl_set_texture_alpha_mod(tex_bot%ptr, uint8(alpha_bot))
                call texture_draw(tex_bot, renderer, dst_bot)
            end if

            call sdl_render_present(renderer)
            call sdl_delay(16) ! Задержка ~60 FPS
        end do

        ! =================================================================
        ! ВЫКЛЮЧАЕМ СГЛАЖИВАНИЕ (ВОЗВРАЩАЕМ NEAREST NEIGHBOR)
        ! Это критически важно! Иначе Шукран и карта в игре станут мыльными.
        ! =================================================================
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "0" // c_null_char)

        ! ======================================================
        ! МЕСТО ДЛЯ ВТОРОГО ИНТРО (если будешь делать)
        ! ======================================================

    end subroutine
end module game_intro