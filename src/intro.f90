module game_intro
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    implicit none

contains
    subroutine play_intro(renderer)
        type(c_ptr), intent(in) :: renderer
        ! Текстуры для первого экрана
        type(texture_t) :: tex_diamond, tex_top, tex_bot
        ! Текстуры для второго экрана
        type(texture_t) :: tex_fs_logo, tex_fs_text
        
        type(sdl_rect) :: dst_diamond, dst_top, dst_bot, dst_fs_logo, dst_fs_text
        integer(c_int32_t) :: start_time, elapsed
        integer :: alpha_diamond, alpha_top, alpha_bot, alpha_fs_logo, alpha_fs_text
        integer :: running
        type(sdl_event) :: ev
        integer :: have_event
        logical(c_bool) :: hint_res

        ! Включаем сглаживание для логотипов
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "1" // c_null_char)

        ! Загружаем картинки (убедись, что они лежат в assets_game/intro/)
        call texture_load(tex_diamond, renderer, "assets_game/intro/diamond.png")
        call texture_load(tex_top, renderer, "assets_game/intro/Fortran_text.png")
        call texture_load(tex_bot, renderer, "assets_game/intro/text_2.png")
        call texture_load(tex_fs_logo, renderer, "assets_game/intro/fs_logo.png")
        call texture_load(tex_fs_text, renderer, "assets_game/intro/fs_text.png")

        ! ==========================================
        ! НАСТРОЙКА КООРДИНАТ ЭТАПА 1 (РОМБ)
        ! ==========================================
        dst_diamond%w = 380; dst_diamond%h = 360
        dst_diamond%x = (1280 - dst_diamond%w) / 2; dst_diamond%y = 180

        dst_top%w = 594; dst_top%h = 96
        dst_top%x = (1280 - dst_top%w) / 2; dst_top%y = 50

        dst_bot%w = 503; dst_bot%h = 90
        dst_bot%x = (1280 - dst_bot%w) / 2; dst_bot%y = 580

        ! ==========================================
        ! НАСТРОЙКА КООРДИНАТ ЭТАПА 2 (ЛОГОТИП FS)
        ! ==========================================
        dst_fs_logo%w = 432; dst_fs_logo%h = 469
        dst_fs_logo%x = (1280 - dst_fs_logo%w) / 2; dst_fs_logo%y = 100

        dst_fs_text%w = 529; dst_fs_text%h = 73
        dst_fs_text%x = (1280 - dst_fs_text%w) / 2; dst_fs_text%y = 599


        ! =====================================================================
        ! ЭТАП 1: СЕРЫЙ ЭКРАН С РОМБОМ (ДЛИТСЯ РОВНО 7 СЕКУНД / 7000 МС)
        ! =====================================================================
        running = 1
        start_time = sdl_get_ticks()

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

            ! Логика проявления ромба и текста
            if (elapsed < 500) then
                alpha_diamond = 0; alpha_top = 0; alpha_bot = 0
            else if (elapsed < 1500) then
                alpha_diamond = int(((real(elapsed) - 500.0) / 1000.0) * 255.0)
                alpha_top = 0; alpha_bot = 0
            else if (elapsed < 2000) then
                alpha_diamond = 255; alpha_top = 0; alpha_bot = 0
            else if (elapsed < 3000) then
                alpha_diamond = 255
                alpha_top = int(((real(elapsed) - 2000.0) / 1000.0) * 255.0)
                alpha_bot = int(((real(elapsed) - 2000.0) / 1000.0) * 255.0)
            else
                alpha_diamond = 255; alpha_top = 255; alpha_bot = 255
            end if

            if (elapsed >= 7000) running = 0 ! Конец первого этапа

            ! Отрисовка (Белый или Серый фон)
            if (elapsed < 500) then
                call sdl_set_render_draw_color(renderer, uint8(255), uint8(255), uint8(255), uint8(255))
            else
                call sdl_set_render_draw_color(renderer, uint8(196), uint8(196), uint8(196), uint8(255))
            end if
            call sdl_render_clear(renderer)

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


        ! =====================================================================
        ! ЭТАП 2: ЧЕРНЫЙ ЭКРАН С ЛОГОТИПОМ FS (ДЛИТСЯ 9 СЕКУНД / 9000 МС)
        ! Итого: 7 + 9 = 16 секунд заставки.
        ! =====================================================================
        running = 1
        start_time = sdl_get_ticks() ! Сбрасываем таймер для второго этапа

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

            ! Логика анимации для Логотипа и Текста
            if (elapsed < 700) then
                ! 0.0 - 0.7 сек: Плавно проявляется только логотип FS
                alpha_fs_logo = int((real(elapsed) / 700.0) * 255.0)
                alpha_fs_text = 0
            else if (elapsed < 1700) then
                ! 0.7 - 1.7 сек: Логотип висит, а текст ждет (пауза 1.0 сек)
                alpha_fs_logo = 255
                alpha_fs_text = 0
            else if (elapsed < 3200) then
                ! 1.7 - 3.2 сек: Плавно проявляется текст (за 1.5 сек)
                alpha_fs_logo = 255
                alpha_fs_text = int(((real(elapsed) - 1700.0) / 1500.0) * 255.0)
            else if (elapsed < 7500) then
                ! 3.2 - 7.5 сек: Всё висит на экране
                alpha_fs_logo = 255
                alpha_fs_text = 255
                ! 2.2 - 7.5 сек: Всё висит на экране (пауза)
                alpha_fs_logo = 255
                alpha_fs_text = 255
            else if (elapsed < 9000) then
                ! 7.5 - 9.0 сек: Плавное растворение (Fade Out) всего за 1.5 сек
                alpha_fs_logo = int((1.0 - ((real(elapsed) - 7500.0) / 1500.0)) * 255.0)
                alpha_fs_text = int((1.0 - ((real(elapsed) - 7500.0) / 1500.0)) * 255.0)
            else
                alpha_fs_logo = 0
                alpha_fs_text = 0
            end if

            if (elapsed >= 9000) running = 0 ! Конец заставки на 16-й секунде

            ! Отрисовка (Всегда черный фон)
            call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(255))
            call sdl_render_clear(renderer)

            if (tex_fs_logo%loaded .and. alpha_fs_logo > 0) then
                call sdl_set_texture_alpha_mod(tex_fs_logo%ptr, uint8(alpha_fs_logo))
                call texture_draw(tex_fs_logo, renderer, dst_fs_logo)
            end if
            if (tex_fs_text%loaded .and. alpha_fs_text > 0) then
                call sdl_set_texture_alpha_mod(tex_fs_text%ptr, uint8(alpha_fs_text))
                call texture_draw(tex_fs_text, renderer, dst_fs_text)
            end if

            call sdl_render_present(renderer)
            call sdl_delay(16)
        end do

        ! ВОЗВРАЩАЕМ ПИКСЕЛЬНЫЙ РЕЖИМ ДЛЯ ИГРЫ
        hint_res = sdl_set_hint("SDL_RENDER_SCALE_QUALITY" // c_null_char, "0" // c_null_char)

    end subroutine
end module game_intro