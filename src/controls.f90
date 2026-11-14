module controls
    use, intrinsic :: iso_c_binding
    implicit none

    ! --- КОДЫ КЛАВИШ (SDL2 Scancode + 1) ---
    integer(c_int), parameter :: KEY_ESC   = 42
    integer(c_int), parameter :: KEY_S     = 23
    integer(c_int), parameter :: KEY_UP    = 83
    integer(c_int), parameter :: KEY_DOWN  = 82
    integer(c_int), parameter :: KEY_LEFT  = 81
    integer(c_int), parameter :: KEY_RIGHT = 80
    integer(c_int), parameter :: KEY_A     = 5
    integer(c_int), parameter :: KEY_D     = 8

end module controls