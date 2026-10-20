module sdl2
    use, intrinsic :: iso_c_binding
    implicit none

    integer(c_int), parameter :: SDL_INIT_VIDEO = 32
    integer(c_int), parameter :: SDL_WINDOWPOS_CENTERED = 805240832
    integer(c_int), parameter :: SDL_WINDOW_SHOWN = 4
    integer(c_int), parameter :: SDL_QUITEVENT = 256
    integer(c_int), parameter :: SDL_RENDERER_ACCELERATED = 2
    integer(c_int), parameter :: SDL_RENDERER_PRESENTVSYNC = 4
    integer(c_int), parameter :: SDL_BUTTON_LEFT = 1
    integer(c_int), parameter :: SDL_BLENDMODE_BLEND = 1
    integer(c_int), parameter :: SDL_FLIP_HORIZONTAL = 1

    type, bind(C) :: sdl_event
        integer(c_int32_t) :: type_
        integer(c_int8_t)  :: padding(52)
    end type

    type, bind(C) :: sdl_rect
        integer(c_int) :: x, y, w, h
    end type

    type, bind(C) :: sdl_color
        integer(c_int8_t) :: r, g, b, a
    end type

    interface
        function sdl_init(f) bind(C, name="SDL_Init") result(r)
            import :: c_int
            integer(c_int), value :: f
            integer(c_int) :: r
        end function
        subroutine sdl_quit() bind(C, name="SDL_Quit")
        end subroutine
        function sdl_create_window(t, x, y, w, h, f) bind(C, name="SDL_CreateWindow") result(p)
            import :: c_char, c_int, c_ptr
            character(kind=c_char), intent(in) :: t(*)
            integer(c_int), value :: x, y, w, h, f
            type(c_ptr) :: p
        end function
        subroutine sdl_destroy_window(p) bind(C, name="SDL_DestroyWindow")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine
        function sdl_create_renderer(w, i, f) bind(C, name="SDL_CreateRenderer") result(p)
            import :: c_ptr, c_int
            type(c_ptr), value :: w
            integer(c_int), value :: i, f
            type(c_ptr) :: p
        end function
        subroutine sdl_destroy_renderer(p) bind(C, name="SDL_DestroyRenderer")
            import :: c_ptr
            type(c_ptr), value :: p
        end subroutine
        subroutine sdl_set_render_draw_color(r, cr, cg, cb, ca) bind(C, name="SDL_SetRenderDrawColor")
            import :: c_ptr, c_int8_t
            type(c_ptr), value :: r
            integer(c_int8_t), value :: cr, cg, cb, ca
        end subroutine
        subroutine sdl_render_clear(r) bind(C, name="SDL_RenderClear")
            import :: c_ptr
            type(c_ptr), value :: r
        end subroutine
        subroutine sdl_render_present(r) bind(C, name="SDL_RenderPresent")
            import :: c_ptr
            type(c_ptr), value :: r
        end subroutine
        subroutine sdl_render_fill_rect(r, rect) bind(C, name="SDL_RenderFillRect")
            import :: c_ptr, sdl_rect
            type(c_ptr), value :: r
            type(sdl_rect), intent(in) :: rect
        end subroutine
        
        subroutine sdl_set_render_draw_blend_mode(r, mode) bind(C, name="SDL_SetRenderDrawBlendMode")
            import :: c_ptr, c_int
            type(c_ptr), value :: r
            integer(c_int), value :: mode
        end subroutine
        
        ! НОВАЯ ФУНКЦИЯ: Рисование пустой рамки
        subroutine sdl_render_draw_rect(r, rect) bind(C, name="SDL_RenderDrawRect")
            import :: c_ptr, sdl_rect
            type(c_ptr), value :: r
            type(sdl_rect), intent(in) :: rect
        end subroutine
        subroutine sdl_render_draw_line(r, x1, y1, x2, y2) bind(C, name="SDL_RenderDrawLine")
            import :: c_ptr, c_int
            type(c_ptr), value :: r
            integer(c_int), value :: x1, y1, x2, y2
        end subroutine
        function sdl_poll_event(e) bind(C, name="SDL_PollEvent") result(r)
            import :: c_int, sdl_event
            type(sdl_event), intent(out) :: e
            integer(c_int) :: r
        end function
        function sdl_get_mouse_state(x, y) bind(C, name="SDL_GetMouseState") result(mask)
            import :: c_ptr, c_int
            type(c_ptr), value :: x, y
            integer(c_int) :: mask
        end function
        subroutine sdl_set_texture_color_mod(t, r, g, b) bind(C, name="SDL_SetTextureColorMod")
            import :: c_ptr, c_int8_t
            type(c_ptr), value :: t
            integer(c_int8_t), value :: r, g, b
        end subroutine

        ! SDL_image
        function img_load(file) bind(C, name="IMG_Load") result(p)
            import :: c_char, c_ptr
            character(kind=c_char), intent(in) :: file(*)
            type(c_ptr) :: p
        end function
        function sdl_create_texture_from_surface(r, s) bind(C, name="SDL_CreateTextureFromSurface") result(p)
            import :: c_ptr
            type(c_ptr), value :: r, s
            type(c_ptr) :: p
        end function
        subroutine sdl_free_surface(s) bind(C, name="SDL_FreeSurface")
            import :: c_ptr
            type(c_ptr), value :: s
        end subroutine
        subroutine sdl_query_texture(tex, fmt, access, w, h) bind(C, name="SDL_QueryTexture")
            import :: c_ptr, c_int
            type(c_ptr), value :: tex, fmt, access
            integer(c_int), intent(out) :: w, h
        end subroutine
        subroutine sdl_render_copy(r, tex, src, dst) bind(C, name="SDL_RenderCopy")
            import :: c_ptr, sdl_rect
            type(c_ptr), value :: r, tex, src
            type(sdl_rect), intent(in) :: dst
        end subroutine
        subroutine sdl_destroy_texture(tex) bind(C, name="SDL_DestroyTexture")
            import :: c_ptr
            type(c_ptr), value :: tex
        end subroutine

        ! Отзеркаливание
        subroutine sdl_render_copy_ex(r, tex, src, dst, angle, center, flip) bind(C, name="SDL_RenderCopyEx")
            import :: c_ptr, sdl_rect, c_double, c_int
            type(c_ptr), value :: r, tex, src, center
            type(sdl_rect), intent(in) :: dst
            real(c_double), value :: angle
            integer(c_int), value :: flip
        end subroutine

        ! SDL_ttf
        function ttf_init() bind(C, name="TTF_Init") result(r)
            import :: c_int
            integer(c_int) :: r
        end function
        function ttf_open_font(f, size) bind(C, name="TTF_OpenFont") result(p)
            import :: c_char, c_int, c_ptr
            character(kind=c_char), intent(in) :: f(*)
            integer(c_int), value :: size
            type(c_ptr) :: p
        end function
        function ttf_render_utf8_blended(f, t, c) bind(C, name="TTF_RenderUTF8_Blended") result(p)
            import :: c_char, c_ptr, sdl_color
            type(c_ptr), value :: f
            character(kind=c_char), intent(in) :: t(*)
            type(sdl_color), value :: c
            type(c_ptr) :: p
        end function
        subroutine ttf_close_font(f) bind(C, name="TTF_CloseFont")
            import :: c_ptr
            type(c_ptr), value :: f
        end subroutine

        function sdl_get_keyboard_state(n) bind(C, name="SDL_GetKeyboardState") result(p)
            import :: c_int, c_ptr
            integer(c_int), intent(out) :: n
            type(c_ptr) :: p
        end function
        function sdl_get_ticks() bind(C, name="SDL_GetTicks") result(ms)
            import :: c_int32_t
            integer(c_int32_t) :: ms
        end function
        function sdl_get_performance_counter() bind(C, name="SDL_GetPerformanceCounter") result(r)
            import :: c_int64_t
            integer(c_int64_t) :: r
        end function
        function sdl_get_performance_frequency() bind(C, name="SDL_GetPerformanceFrequency") result(r)
            import :: c_int64_t
            integer(c_int64_t) :: r
        end function
        subroutine sdl_delay(ms) bind(C, name="SDL_Delay")
            import :: c_int32_t
            integer(c_int32_t), value :: ms
        end subroutine        
        subroutine sdl_set_texture_alpha_mod(t, a) bind(C, name="SDL_SetTextureAlphaMod")
            import :: c_ptr, c_int8_t
            type(c_ptr), value :: t
            integer(c_int8_t), value :: a
        end subroutine
        function sdl_set_hint(name, value) bind(C, name="SDL_SetHint") result(r)
            import :: c_char, c_bool
            character(kind=c_char), intent(in) :: name(*)
            character(kind=c_char), intent(in) :: value(*)
            logical(c_bool) :: r
        end function
        
    end interface

contains
    pure function uint8(i) result(r)
        integer, intent(in) :: i
        integer(c_int8_t) :: r
        r = transfer([i, 1], 1_c_int8_t)
    end function
end module sdl2