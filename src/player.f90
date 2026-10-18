module game_player
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: textures
    use :: game_map
    implicit none

    integer, parameter :: PLAYER_SPEED = 6 

    integer :: tile_x = 19, tile_y = 21
    integer :: target_tile_x = -1, target_tile_y = -1
    integer :: pixel_offset = 0
    
    integer :: direction = 1
    integer :: just_turned = 0
    
    integer :: anim_frame = 0
    integer :: anim_timer = 0
    logical :: moving = .false.
    
    integer :: px = 0, py = 0

contains
    subroutine player_init(start_tx, start_ty)
        integer, intent(in) :: start_tx, start_ty
        tile_x = start_tx
        tile_y = start_ty
        px = tile_x * TILE_SIZE
        py = tile_y * TILE_SIZE
    end subroutine

    subroutine player_update(keys)
        integer(c_int8_t), intent(in) :: keys(*)
        integer :: step

        if (target_tile_x /= -1) then
            step = min(PLAYER_SPEED, TILE_SIZE - pixel_offset)
            pixel_offset = pixel_offset + step
            
            if (pixel_offset >= TILE_SIZE) then
                tile_x = target_tile_x
                tile_y = target_tile_y
                target_tile_x = -1
                target_tile_y = -1
                pixel_offset = 0
                call continue_move(keys)
            else
                anim_timer = anim_timer + 1
                if (anim_timer > 6) then
                    anim_frame = 1 - anim_frame
                    anim_timer = 0
                end if
            end if
        else
            call start_move(keys)
            if (target_tile_x == -1) then
                anim_frame = 0
                anim_timer = 0
            end if
        end if

        px = tile_x * TILE_SIZE
        py = tile_y * TILE_SIZE
        
        if (target_tile_x /= -1) then
            if (direction == 3) px = px + pixel_offset 
            if (direction == 4) px = px - pixel_offset 
            if (direction == 1) py = py + pixel_offset 
            if (direction == 2) py = py - pixel_offset 
        end if
    end subroutine

    subroutine continue_move(keys)
        integer(c_int8_t), intent(in) :: keys(*)
        integer :: dx, dy, new_x, new_y
        dx = 0; dy = 0
        
        if (direction == 3 .and. keys(80) /= 0) dx = 1     
        if (direction == 4 .and. keys(81) /= 0) dx = -1    
        if (direction == 1 .and. keys(82) /= 0) dy = 1     
        if (direction == 2 .and. keys(83) /= 0) dy = -1    

        if (dx /= 0 .or. dy /= 0) then
            new_x = tile_x + dx
            new_y = tile_y + dy
            
            if (new_x < 0 .or. new_x >= MAP_COLS .or. new_y < 0 .or. new_y >= MAP_ROWS) then
                moving = .false.
                anim_frame = 0
                return
            end if

            if (is_solid(new_x + 1, new_y + 1)) then
                moving = .false.
                anim_frame = 0
                return
            end if

            target_tile_x = new_x
            target_tile_y = new_y
            moving = .true.
            pixel_offset = 0
        end if
    end subroutine

    subroutine start_move(keys)
        integer(c_int8_t), intent(in) :: keys(*)
        integer :: new_dir, dx, dy, new_x, new_y
        new_dir = -1
        dx = 0; dy = 0

        if (keys(80) /= 0) then; new_dir = 3; dx = 1; dy = 0; end if 
        if (keys(81) /= 0) then; new_dir = 4; dx = -1; dy = 0; end if 
        if (keys(82) /= 0) then; new_dir = 1; dx = 0; dy = 1; end if 
        if (keys(83) /= 0) then; new_dir = 2; dx = 0; dy = -1; end if 

        if (new_dir == -1) then
            moving = .false.
            anim_frame = 0
            just_turned = 0
            return
        end if

        if (direction /= new_dir) then
            direction = new_dir
            just_turned = 1
            anim_frame = 0
            return
        end if

        if (just_turned == 1) then
            just_turned = 0
            return
        end if

        new_x = tile_x + dx
        new_y = tile_y + dy

        if (new_x < 0 .or. new_x >= MAP_COLS .or. new_y < 0 .or. new_y >= MAP_ROWS) then
            moving = .false.
            return
        end if

        if (is_solid(new_x + 1, new_y + 1)) then
            moving = .false.
            return
        end if

        target_tile_x = new_x
        target_tile_y = new_y
        moving = .true.
        anim_frame = 0
        anim_timer = 0
        pixel_offset = 0
    end subroutine

    subroutine player_draw(renderer, tex_down, tex_up, tex_right, cam_x, cam_y)
        type(c_ptr), intent(in) :: renderer
        type(texture_t), intent(in) :: tex_down, tex_up, tex_right
        integer, intent(in) :: cam_x, cam_y
        type(sdl_rect), target :: src_rect, dst_rect
        type(texture_t) :: current_tex
        integer :: flip_flag

        flip_flag = 0
        select case (direction)
            case (1); current_tex = tex_down
            case (2); current_tex = tex_up
            case (3); current_tex = tex_right
            case (4); current_tex = tex_right; flip_flag = SDL_FLIP_HORIZONTAL
        end select

        if (.not. current_tex%loaded) return

        src_rect%x = anim_frame * 64
        src_rect%y = 0
        src_rect%w = 64
        src_rect%h = 128

        dst_rect%x = px - cam_x
        dst_rect%y = py - cam_y - 64 
        dst_rect%w = 64
        dst_rect%h = 128

        if (flip_flag /= 0) then
            call texture_draw_part_ex(current_tex, renderer, src_rect, dst_rect, flip_flag)
        else
            call texture_draw_part(current_tex, renderer, src_rect, dst_rect)
        end if
    end subroutine
end module game_player