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
        logical(c_bool) :: hint_res

        ! Включаем сглаживание для логотипа
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "1" // c_null_char)

        ! Загружаем картинки
        call texture_load(tex_diamond, renderer, "assets_game/intro/diamond.png")
        call texture_load(tex_top, renderer, "assets_game/intro/Fortran_text.png")
        call texture_load(tex_bot, renderer, "assets_game/intro/text_2.png")

        ! НАСТРОЙКА КООРДИНАТ (Твои размеры)
        dst_diamond%w = 380; dst_diamond%h = 360
        dst_diamond%x = (1280 - dst_diamond%w) / 2
        dst_diamond%y = 180

        dst_top%w = 594; dst_top%h = 96
        dst_top%x = (1280 - dst_top%w) / 2
        dst_top%y = 50

        dst_bot%w = 503; dst_bot%h = 90
        dst_bot%x = (1280 - dst_bot%w) / 2
        dst_bot%y = 580

        running = 1
        start_time = sdl_get_ticks()

        ! --- ЦИКЛ ЗАСТАВКИ (7 СЕКУНД) ---
        do while (running /= 0)
            have_event = sdl_poll_event(ev)
            do while (have_event /= 0)
                if (ev%type_ == SDL_QUITEVENT) then
                    running = 0
                    return
                end if
                have_event = sdl_poll_event(ev)
            end do

            elapsed = sdl_get_ticks() - start_time

            ! =========================================================
            ! 1. ЛОГИКА ПРОЯВЛЕНИЯ (АЛЬФА-КАНАЛ)
            ! =========================================================
            if (elapsed < 500) then
                ! 0.0 - 0.5 сек: Ждем (ромба нет)
                alpha_diamond = 0
                alpha_top = 0
                alpha_bot = 0
            else if (elapsed < 1500) then
                ! 0.5 - 1.5 сек: Плавно проявляется ромб за 1 сек
                alpha_diamond = int(((real(elapsed) - 500.0) / 1000.0) * 255.0)
                alpha_top = 0
                alpha_bot = 0
            else if (elapsed < 2000) then
                ! 1.5 - 2.0 сек: Ромб висит, текста пока нет
                alpha_diamond = 255
                alpha_top = 0
                alpha_bot = 0
            else if (elapsed < 3000) then
                ! 2.0 - 3.0 сек: Ромб на месте, ОДНОВРЕМЕННО проявляются оба текста
                alpha_diamond = 255
                alpha_top = int(((real(elapsed) - 2000.0) / 1000.0) * 255.0)
                alpha_bot = int(((real(elapsed) - 2000.0) / 1000.0) * 255.0)
            else
                ! 3.0 - 7.0 сек: Все висит на экране
                alpha_diamond = 255
                alpha_top = 255
                alpha_bot = 255
            end if

            if (elapsed > 7000) running = 0

            ! =========================================================
            ! 2. ОЧИСТКА ЭКРАНА (БЕЛЫЙ ИЛИ СЕРЫЙ ФОН)
            ! =========================================================
            if (elapsed < 500) then
                ! Первые 0.5 секунды - БЕЛЫЙ экран (вспышка)
                call sdl_set_render_draw_color(renderer, uint8(255), uint8(255), uint8(255), uint8(255))
            else
                ! Дальше - СЕРЫЙ фон (как у PS1)
                call sdl_set_render_draw_color(renderer, uint8(196), uint8(196), uint8(196), uint8(255))
            end if
            call sdl_render_clear(renderer)

            ! =========================================================
            ! 3. ОТРИСОВКА
            ! =========================================================
            if (tex_diamond%loaded .and. alpha_diamond > 0) then
                call sdl_set_texture_alpha_mod(tex_diamond%ptr, uint8(alpha_diamond))
                call texture_draw(tex_diamond, renderer, dst_diamond)
            end if
            if (tex_top%loaded .and. alpha_top > 0) then
                call sdl_set_texture_alpha_mod(tex_top%ptr, uint8(alpha_top))
                call texture_draw(tex_top, renderer, dst_top)
            end if
            if (tex_bot%loaded .and. alpha_bot > 0) then
                call sdl_set_texture_alpha_mod(tex_bot%ptr, uint8(alpha_bot))
                call texture_draw(tex_bot, renderer, dst_bot)
            end if

            call sdl_render_present(renderer)
            call sdl_delay(16)
        end do

        ! ВОЗВРАЩАЕМ ПИКСЕЛЬНЫЙ РЕЖИМ ДЛЯ ИГРЫ
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "0" // c_null_char)

    end subroutine
end module game_intro