module timer
    use, intrinsic :: iso_c_binding
    use :: sdl2
    implicit none

    integer(c_int64_t) :: freq, prev_time, curr_time
    real :: accumulator = 0.0
    real, parameter :: FIXED_DT = 1.0 / 60.0

contains
    subroutine timer_init()
        freq = sdl_get_performance_frequency()
        prev_time = sdl_get_performance_counter()
        accumulator = 0.0
    end subroutine

    ! Возвращает .true., если пора сделать шаг игровой логики
    function timer_update() result(do_step)
        logical :: do_step
        real :: delta_time

        curr_time = sdl_get_performance_counter()
        delta_time = real(curr_time - prev_time) / real(freq)
        prev_time = curr_time

        ! Защита от "спирали смерти" (если игра зависла на 1 секунду)
        if (delta_time > 0.25) delta_time = 0.25

        accumulator = accumulator + delta_time
        do_step = .false.

        if (accumulator >= FIXED_DT) then
            do_step = .true.
            accumulator = accumulator - FIXED_DT
        end if
    end function
end module timer