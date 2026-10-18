module textures
    use, intrinsic :: iso_c_binding
    use :: sdl2
    implicit none

    type :: texture_t
        type(c_ptr) :: ptr = c_null_ptr
        integer     :: w = 0, h = 0
        logical     :: loaded = .false.
    end type

contains
    subroutine texture_load(tex, renderer, filename)
        type(texture_t), intent(out) :: tex
        type(c_ptr), intent(in) :: renderer
        character(len=*), intent(in) :: filename
        type(c_ptr) :: surface
        integer(c_int) :: tw, th

        surface = img_load(filename // c_null_char)
        if (.not. c_associated(surface)) then
            print *, "ОШИБКА: Не удалось загрузить ", trim(filename)
            return
        end if
        tex%ptr = sdl_create_texture_from_surface(renderer, surface)
        call sdl_free_surface(surface)
        call sdl_query_texture(tex%ptr, c_null_ptr, c_null_ptr, tw, th)
        tex%w = int(tw); tex%h = int(th); tex%loaded = .true.
    end subroutine

    subroutine texture_draw_9slice(tex, renderer, x, y, w, h, border, cr, cg, cb)
        type(texture_t), intent(in) :: tex
        type(c_ptr), intent(in) :: renderer
        integer, intent(in) :: x, y, w, h, border, cr, cg, cb
        type(sdl_rect), target :: src, dst
        integer :: b, cw, ch, mid_w, mid_h

        if (.not. tex%loaded) return

        call sdl_set_texture_color_mod(tex%ptr, uint8(cr), uint8(cg), uint8(cb))

        b = border
        if (w < 2*b) b = w / 2
        if (h < 2*b) b = h / 2
        cw = tex%w; ch = tex%h
        mid_w = w - 2*b; mid_h = h - 2*b

        src%x = 0; src%y = 0; src%w = b; src%h = b; dst%x = x; dst%y = y; dst%w = b; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = b; src%y = 0; src%w = cw - 2*b; src%h = b; dst%x = x + b; dst%y = y; dst%w = mid_w; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = cw - b; src%y = 0; src%w = b; src%h = b; dst%x = x + w - b; dst%y = y; dst%w = b; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = 0; src%y = b; src%w = b; src%h = ch - 2*b; dst%x = x; dst%y = y + b; dst%w = b; dst%h = mid_h
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = b; src%y = b; src%w = cw - 2*b; src%h = ch - 2*b; dst%x = x + b; dst%y = y + b; dst%w = mid_w; dst%h = mid_h
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = cw - b; src%y = b; src%w = b; src%h = ch - 2*b; dst%x = x + w - b; dst%y = y + b; dst%w = b; dst%h = mid_h
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = 0; src%y = ch - b; src%w = b; src%h = b; dst%x = x; dst%y = y + h - b; dst%w = b; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = b; src%y = ch - b; src%w = cw - 2*b; src%h = b; dst%x = x + b; dst%y = y + h - b; dst%w = mid_w; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
        
        src%x = cw - b; src%y = ch - b; src%w = b; src%h = b; dst%x = x + w - b; dst%y = y + h - b; dst%w = b; dst%h = b
        call sdl_render_copy(renderer, tex%ptr, c_loc(src), dst)
    end subroutine
end module textures