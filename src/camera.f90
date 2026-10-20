module game_camera
    use, intrinsic :: iso_c_binding
    use :: game_map, only: area_x, area_y, area_w, area_h
    implicit none

    integer :: cam_x = 0, cam_y = 0
    
    ! Флаг, показывающий, что камера достигла цели и больше не двигается
    logical :: cam_arrived = .true.
    
    integer, parameter :: SCREEN_W = 1280
    integer, parameter :: SCREEN_H = 720
    integer, parameter :: TILE_SIZE = 64

    integer, parameter :: CAM_SPEED = 6

    integer, parameter :: DZ_MOVE_LEFT = 256
    integer, parameter :: DZ_MOVE_RIGHT = SCREEN_W - 256
    integer, parameter :: DZ_MOVE_TOP = 256
    integer, parameter :: DZ_MOVE_BOTTOM = SCREEN_H - 256

    integer, parameter :: DZ_STOP_LEFT = 320
    integer, parameter :: DZ_STOP_RIGHT = SCREEN_W - 320
    integer, parameter :: DZ_STOP_TOP = 320
    integer, parameter :: DZ_STOP_BOTTOM = SCREEN_H - 320

contains
    subroutine camera_init(player_x, player_y)
        integer, intent(in) :: player_x, player_y
        cam_x = player_x + (TILE_SIZE / 2) - (SCREEN_W / 2)
        cam_y = player_y + (TILE_SIZE / 2) - (SCREEN_H / 2)
        
        ! Ограничиваем начальную позицию
        call clamp_target(cam_x, cam_y)
        cam_arrived = .true.
    end subroutine

    subroutine camera_update(player_x, player_y, direction)
        integer, intent(in) :: player_x, player_y, direction
        integer :: screen_x, screen_y
        integer :: target_x, target_y

        target_x = cam_x
        target_y = cam_y

        screen_x = player_x - cam_x
        screen_y = player_y - cam_y

        if (direction /= 0) then
            if (direction == 3 .or. direction == 4) then
                if (screen_x > DZ_MOVE_RIGHT) target_x = player_x - DZ_MOVE_RIGHT
                if (screen_x < DZ_MOVE_LEFT) then
                    target_x = player_x - DZ_MOVE_LEFT
                else if (screen_x > DZ_MOVE_RIGHT) then
                    target_x = player_x - DZ_MOVE_RIGHT
                end if
                
                if (screen_y > DZ_STOP_BOTTOM) target_y = player_y - DZ_STOP_BOTTOM
                if (screen_y < DZ_STOP_TOP) target_y = player_y - DZ_STOP_TOP

            else if (direction == 1 .or. direction == 2) then
                if (screen_y > DZ_MOVE_BOTTOM) target_y = player_y - DZ_MOVE_BOTTOM
                if (screen_y < DZ_MOVE_TOP) then
                    target_y = player_y - DZ_MOVE_TOP
                else if (screen_y > DZ_MOVE_BOTTOM) then
                    target_y = player_y - DZ_MOVE_BOTTOM
                end if
                
                if (screen_x > DZ_STOP_RIGHT) target_x = player_x - DZ_STOP_RIGHT
                if (screen_x < DZ_STOP_LEFT) target_x = player_x - DZ_STOP_LEFT
            end if
        else
            if (screen_x > DZ_STOP_RIGHT) target_x = player_x - DZ_STOP_RIGHT
            if (screen_x < DZ_STOP_LEFT) target_x = player_x - DZ_STOP_LEFT
            if (screen_y > DZ_STOP_BOTTOM) target_y = player_y - DZ_STOP_BOTTOM
            if (screen_y < DZ_STOP_TOP) target_y = player_y - DZ_STOP_TOP
        end if

        ! НОВОЕ: Сначала ограничиваем саму ЦЕЛЬ, а не текущую позицию
        call clamp_target(target_x, target_y)

        if (target_x > cam_x) then
            cam_x = min(cam_x + CAM_SPEED, target_x)
        else if (target_x < cam_x) then
            cam_x = max(cam_x - CAM_SPEED, target_x)
        end if

        if (target_y > cam_y) then
            cam_y = min(cam_y + CAM_SPEED, target_y)
        else if (target_y < cam_y) then
            cam_y = max(cam_y - CAM_SPEED, target_y)
        end if
        
        ! Проверяем, доехали ли мы ровно до цели
        cam_arrived = (cam_x == target_x .and. cam_y == target_y)
    end subroutine

    ! Эта функция ограничивает ПЕРЕДАННЫЕ координаты (target_x, target_y)
    subroutine clamp_target(tx, ty)
        integer, intent(inout) :: tx, ty
        
        if (tx < area_x) tx = area_x
        if (tx > area_x + area_w - SCREEN_W) tx = area_x + area_w - SCREEN_W
        
        if (ty < area_y - 64) ty = area_y - 64
        if (ty > area_y + area_h - SCREEN_H) ty = area_y + area_h - SCREEN_H
        
        if (area_w < SCREEN_W) tx = area_x
        if (area_h < SCREEN_H) ty = area_y - 64
    end subroutine
end module game_camera