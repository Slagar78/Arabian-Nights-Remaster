module game_map
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    implicit none

    integer, parameter :: MAP_COLS = 38
    integer, parameter :: MAP_ROWS = 42
    integer, parameter :: TILE_SIZE = 64
    
    integer :: grid(MAP_ROWS, MAP_COLS) = 0
    integer(c_int8_t) :: collision_grid(MAP_ROWS, MAP_COLS) = 1_c_int8_t
    type(texture_t) :: tileset_tex

    ! --- ГРАНИЦЫ ОБЛАСТИ ДЛЯ КАМЕРЫ ---
    integer :: area_x = 0
    integer :: area_y = 0
    integer :: area_w = 2432 ! По умолчанию весь мир
    integer :: area_h = 2688
    ! ---------------------------------

contains
    function is_solid(x, y) result(solid)
        integer, intent(in) :: x, y
        logical :: solid
        
        solid = .false.
        if (x < 1 .or. x > MAP_COLS .or. y < 1 .or. y > MAP_ROWS) then
            solid = .true.
            return
        end if
        
        if (collision_grid(y, x) == -1_c_int8_t) solid = .true.
    end function

    subroutine map_load(filename, renderer, tileset_path, collision_filename, areas_filename)
        character(len=*), intent(in) :: filename, tileset_path, collision_filename, areas_filename
        type(c_ptr), intent(in) :: renderer
        integer :: io, r, start_tx, start_ty, w_tiles, h_tiles
        integer(c_int16_t) :: row_buffer(MAP_COLS)
        integer(c_int8_t) :: col_buffer(MAP_COLS)
        
        call texture_load(tileset_tex, renderer, tileset_path)
        
        ! 1. Читаем layout.bin
        open(10, file=filename, form='unformatted', access='stream', status='old', iostat=io)
        if (io /= 0) stop "ОШИБКА: Не найден layout.bin"
        do r = 1, MAP_ROWS
            read(10) row_buffer
            grid(r, 1:MAP_COLS) = int(row_buffer)
        end do
        close(10)
        
        ! 2. Читаем collision.bin
        open(11, file=collision_filename, form='unformatted', access='stream', status='old', iostat=io)
        if (io /= 0) then
            print *, "ВНИМАНИЕ: Не найден collision.bin."
        else
            do r = 1, MAP_ROWS
                read(11) col_buffer
                collision_grid(r, 1:MAP_COLS) = col_buffer
            end do
            close(11)
        end if

        ! 3. Читаем areas.txt
        open(12, file=areas_filename, status='old', iostat=io)
        if (io /= 0) then
            print *, "ВНИМАНИЕ: Не найден areas.txt. Камера ограничена всей картой."
            area_x = 0
            area_y = 0
            area_w = MAP_COLS * TILE_SIZE
            area_h = MAP_ROWS * TILE_SIZE
        else
            read(12, *) start_tx, start_ty, w_tiles, h_tiles
            close(12)
            
            area_x = start_tx * TILE_SIZE
            area_y = start_ty * TILE_SIZE
            area_w = w_tiles * TILE_SIZE
            area_h = h_tiles * TILE_SIZE
            print *, "Область камеры: ", area_w, "x", area_h
        end if
    end subroutine

    subroutine map_draw(renderer, cam_x, cam_y)
        type(c_ptr), intent(in) :: renderer
        integer, intent(in) :: cam_x, cam_y
        integer :: r, c, tile, tiles_per_row
        type(sdl_rect), target :: src_rect, dst_rect

        if (.not. tileset_tex%loaded) return

        tiles_per_row = tileset_tex%w / TILE_SIZE

        do r = 1, MAP_ROWS
            do c = 1, MAP_COLS
                tile = grid(r, c)
                
                if (tile == 0) cycle

                dst_rect%x = (c - 1) * TILE_SIZE - cam_x
                dst_rect%y = (r - 1) * TILE_SIZE - cam_y
                dst_rect%w = TILE_SIZE
                dst_rect%h = TILE_SIZE

                if (dst_rect%x < -TILE_SIZE .or. dst_rect%x > 1280 .or. &
                    dst_rect%y < -TILE_SIZE .or. dst_rect%y > 720) cycle

                tile = tile - 1 

                src_rect%x = mod(tile, tiles_per_row) * TILE_SIZE
                src_rect%y = (tile / tiles_per_row) * TILE_SIZE
                src_rect%w = TILE_SIZE
                src_rect%h = TILE_SIZE

                call sdl_render_copy(renderer, tileset_tex%ptr, c_loc(src_rect), dst_rect)
            end do
        end do
    end subroutine
end module game_map