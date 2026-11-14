program rts_prototype
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: audio
    use :: textures
    use :: ui
    use :: controls
    use :: game_map
    use :: game_camera
    use :: game_player
    use :: timer
    use :: game_intro
    use :: ui_status
    use :: ui_magia
    
    implicit none

    ! =====================================================================
    ! 1. ОБЪЯВЛЕНИЕ ПЕРЕМЕННЫХ И ТИПОВ
    ! =====================================================================
    type :: map_settings
        character(len=50)  :: folder = ""
        character(len=150) :: tileset = ""
        character(len=150) :: music = ""
        character(len=150) :: layout_file = ""
        character(len=150) :: collision_file = ""
        character(len=150) :: areas_file = ""
        character(len=150) :: warps_file = ""
        character(len=150) :: chests_file = ""
    end type

    type(c_ptr) :: window, renderer
    type(sdl_event) :: ev
    integer :: running, have_event, numkeys
    type(c_ptr) :: kptr
    integer(c_int8_t), pointer :: keys(:)
    
    ! Текстуры
    type(texture_t) :: btn_tex, tex_track, tex_thumb
    type(texture_t) :: tex_down, tex_up, tex_right
    type(texture_t) :: crystal_red, crystal_blue, crystal_yellow, crystal_green
    type(texture_t) :: menu_panel_tex, portrait_frame_tex, portrait_tex
    type(texture_t) :: mystic_card_tex
    
    logical :: sound_on, music_on
    type(sdl_rect) :: top_bar

    ! Состояния меню
    logical :: menu_open = .false.
    logical :: pause_menu_open = .false.
    logical :: pending_menu_request = .false.
    integer :: menu_selected = 0 
    integer :: current_submenu = 0 
    integer :: menu_still_frames = 0
    integer :: menu_last_cam_x = -99999
    integer :: menu_last_cam_y = -99999
    
    ! Анимация подменю
    integer :: status_y = 720
    integer :: status_state = 0
    
    ! Анимация кристаллов
    logical :: flipping = .false.
    integer :: flip_timer = 0
    real :: flip_phase = 0.0
    integer :: pulse_timer = 0
    integer :: pulse_alpha = 255
    
    character(len=20) :: menu_labels(0:3)
    
    ! Данные карт
    character(len=50), allocatable :: map_folders(:)
    integer :: num_maps
    character(len=50)  :: current_folder
    character(len=150) :: layout_path, collision_path, areas_path
    type(map_settings) :: current_config

    ! Клавиатура
    integer(c_int8_t) :: prev_keys(512)
    integer(c_int8_t) :: empty_keys(512)
    prev_keys = 0_c_int8_t
    empty_keys = 0_c_int8_t

    menu_labels(0) = "Stato"
    menu_labels(1) = "Magia"
    menu_labels(2) = "Oggetti"
    menu_labels(3) = "Cerca"

    ! =====================================================================
    ! 2. ИНИЦИАЛИЗАЦИЯ SDL, ОКНА И ЗАГРУЗКА АССЕТОВ
    ! =====================================================================
    if (sdl_init(SDL_INIT_VIDEO) /= 0) stop "SDL_Init failed"
    
    window = sdl_create_window("Arabian Nights Remaster" // c_null_char, &
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_SHOWN)
        
    renderer = sdl_create_renderer(window, -1, SDL_RENDERER_ACCELERATED + SDL_RENDERER_PRESENTVSYNC)

    ! Загрузка UI и персонажа
    call texture_load(btn_tex, renderer, "assets/button.png")
    call texture_load(tex_track, renderer, "assets/track.png")
    call texture_load(tex_thumb, renderer, "assets/thumb.png")
    call load_character_assets(renderer, "Shukran", tex_down, tex_up, tex_right, portrait_tex)
    
    ! Загрузка меню
    call texture_load(crystal_red, renderer, "assets_game/menu/crystal/crystal.png")
    call texture_load(crystal_blue, renderer, "assets_game/menu/crystal/crystal_2.png")
    call texture_load(crystal_yellow, renderer, "assets_game/menu/crystal/crystal_4.png")
    call texture_load(crystal_green, renderer, "assets_game/menu/crystal/crystal_3.png")
    call texture_load(menu_panel_tex, renderer, "assets_game/menu/menu_panel.png")
    call texture_load(portrait_frame_tex, renderer, "assets_game/menu/portrait_frame.png")
    call texture_load(mystic_card_tex, renderer, "assets_game/menu/mystic_card.png")
    
    call ui_init()

    ! =====================================================================
    ! 3. АУДИО И ИНТРО
    ! =====================================================================
    call audio_init() 
    call audio_play_music("assets_game/music/intro.ogg", 0) 
    call play_intro(renderer)
    
    ! =====================================================================
    ! 4. ЗАГРУЗКА КАРТЫ
    ! =====================================================================
    call load_maps_list("data/maps/maplist.txt", map_folders, num_maps)
    if (num_maps == 0) stop "ОШИБКА: Список карт пуст!"
    
    current_folder = trim(map_folders(1))
    call get_map_settings("data/maps/maplist.txt", current_folder, current_config)

    write(layout_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%layout_file)
    write(collision_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%collision_file)
    write(areas_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%areas_file)
    
    print *, "=== ЗАГРУЗКА: ", trim(current_folder), " ==="
    print *, "Тайлсет: ", trim(current_config%tileset)
    
    call map_load(trim(layout_path), renderer, trim(current_config%tileset), trim(collision_path), trim(areas_path))
    
    if (len_trim(current_config%music) > 0) then
        call audio_play_music(trim(current_config%music), -1)
    end if

    call player_init(19, 21) 
    call camera_init(px, py)

    kptr = sdl_get_keyboard_state(numkeys)
    call c_f_pointer(kptr, keys, [512])

    sound_on = .true.
    music_on = .false.
    running = 1

    top_bar%w = 2432
    top_bar%h = 64
    
    call timer_init()

    ! =====================================================================
    ! 5. ГЛАВНЫЙ ИГРОВОЙ ЦИКЛ
    ! =====================================================================
    do while (running /= 0)
        ! --- События (Закрытие окна) ---
        have_event = sdl_poll_event(ev)
        do while (have_event /= 0)
            if (ev%type_ == SDL_QUITEVENT) running = 0
            have_event = sdl_poll_event(ev)
        end do
        
        ! --- Обновление логики (60 FPS) ---
        if (timer_update()) then
            
            ! --- Пульсация рамки меню ---
            pulse_timer = pulse_timer + 1
            pulse_alpha = 205 + int(50.0 * sin(real(pulse_timer) * 0.2))          
            
            ! --- Анимация выезда/уезда подменю ---
            if (status_state == 1) then
                status_y = status_y - 80
                if (status_y <= 0) then
                    status_y = 0
                    status_state = 2
                end if
            else if (status_state == 3) then
                status_y = status_y + 80
                if (status_y >= 720) then
                    status_y = 720
                    status_state = 0
                    current_submenu = 0
                    menu_open = .true.
                end if
            end if

            ! --- Обработка нажатий (Пауза, Меню) ---
            if (keys(KEY_ESC) /= 0 .and. prev_keys(KEY_ESC) == 0) then
                pause_menu_open = .not. pause_menu_open
                if (pause_menu_open) then
                    menu_open = .false.
                    current_submenu = 0
                end if
            end if

            if (current_submenu > 0) then
                if (keys(KEY_S) /= 0 .and. prev_keys(KEY_S) == 0) then
                    if (status_state == 2) status_state = 3
                end if
            else
                ! Открытие радиального меню (A/D)
                if ((keys(KEY_A) /= 0 .and. prev_keys(KEY_A) == 0) .or. (keys(KEY_D) /= 0 .and. prev_keys(KEY_D) == 0)) then
                    if (.not. menu_open .and. current_submenu == 0 .and. .not. pause_menu_open) then
                        pending_menu_request = .true.
                        menu_still_frames = 0
                        menu_last_cam_x = -99999
                        menu_last_cam_y = -99999
                    else if (menu_open) then
                        if (menu_selected == 0) then
                            current_submenu = 1 
                            status_y = 720
                            status_state = 1
                        else if (menu_selected == 1) then
                            current_submenu = 2 
                            status_y = 720
                            status_state = 1
                        end if
                        menu_open = .false. 
                    end if
                end if

                ! Управление в радиальном меню (Стрелки)
                if (menu_open) then
                    if (keys(KEY_UP) /= 0 .and. prev_keys(KEY_UP) == 0 .and. menu_selected /= 0) then
                        menu_selected = 0; flipping = .true.; flip_timer = 0
                    else if (keys(KEY_LEFT) /= 0 .and. prev_keys(KEY_LEFT) == 0 .and. menu_selected /= 1) then
                        menu_selected = 1; flipping = .true.; flip_timer = 0
                    else if (keys(KEY_RIGHT) /= 0 .and. prev_keys(KEY_RIGHT) == 0 .and. menu_selected /= 2) then
                        menu_selected = 2; flipping = .true.; flip_timer = 0
                    else if (keys(KEY_DOWN) /= 0 .and. prev_keys(KEY_DOWN) == 0 .and. menu_selected /= 3) then
                        menu_selected = 3; flipping = .true.; flip_timer = 0
                    end if
                    
                    if (keys(KEY_S) /= 0 .and. prev_keys(KEY_S) == 0) then
                        menu_open = .false.
                    end if

                    if (flipping) then
                        flip_timer = flip_timer + 1
                        if (flip_timer >= 8) then
                            flipping = .false.; flip_phase = 0.0
                        else if (flip_timer < 4) then
                            flip_phase = real(flip_timer) / 4.0
                        else
                            flip_phase = 2.0 - real(flip_timer) / 4.0
                        end if
                    end if
                end if
            end if
            
            ! --- Логика персонажа и камеры ---
            if (.not. menu_open .and. current_submenu == 0 .and. .not. pause_menu_open) then
                ! Игра и меню закрыты: управляем Шукран
                if (pending_menu_request) then
                    call player_update(empty_keys) 
                else
                    call player_update(keys)
                end if
                
                if (moving) then
                    call camera_update(px, py, direction)
                else
                    call camera_update(px, py, 0)
                end if

                if (pending_menu_request) then
                    if (.not. moving .and. target_tile_x == -1) then
                        if (cam_x == menu_last_cam_x .and. cam_y == menu_last_cam_y) then
                            menu_still_frames = menu_still_frames + 1
                        else
                            menu_still_frames = 0
                        end if
                        if (menu_still_frames >= 8) then
                            pending_menu_request = .false.
                            menu_still_frames = 0
                            menu_open = .true.
                        end if
                    else
                        menu_still_frames = 0
                    end if
                    menu_last_cam_x = cam_x
                    menu_last_cam_y = cam_y
                end if
                
            else if (.not. pause_menu_open) then
                ! Открыто меню (но не пауза): Шукран стоит и "дышит"
                call player_update(empty_keys)
            end if
            
            prev_keys = keys
        end if ! Конец timer_update

        ! =====================================================================
        ! 6. ОТРИСОВКА КАДРА
        ! =====================================================================
        
        ! --- Мир и персонаж ---
        call sdl_set_render_draw_color(renderer, uint8(210), uint8(180), uint8(140), uint8(255))
        call sdl_render_clear(renderer)
        call map_draw(renderer, cam_x, cam_y)
        
        top_bar%x = -cam_x
        top_bar%y = -cam_y - 64
        call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(255))
        call sdl_render_fill_rect(renderer, top_bar)

        call player_draw(renderer, tex_down, tex_up, tex_right, cam_x, cam_y)

        ! --- Радиальное меню ---
        if (menu_open) then
            call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
            
            block
                type(sdl_rect) :: overlay
                overlay%x = 0; overlay%y = 0; overlay%w = 1280; overlay%h = 720
                call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(120))
                call sdl_render_fill_rect(renderer, overlay)
            end block

            block
                type(sdl_rect), target :: src, dst
                integer :: cx, cy, off, i, px, py, dw, dx
                integer :: flip_flag
                type(texture_t) :: crystals(0:3)
                
                crystals(0) = crystal_red
                crystals(1) = crystal_blue
                crystals(2) = crystal_yellow
                crystals(3) = crystal_green
                
                cx = 640; cy = 580; off = 56
                src%x = 0; src%y = 0; src%w = 108; src%h = 108
                
                do i = 0, 3
                    if (.not. crystals(i)%loaded) cycle 
                    
                    if (i == 0) then; px = cx; py = cy - off; end if
                    if (i == 1) then; px = cx - off; py = cy; end if
                    if (i == 2) then; px = cx + off; py = cy; end if
                    if (i == 3) then; px = cx; py = cy + off; end if
                    
                    dst%w = 108; dst%h = 108
                    dst%x = px - 54; dst%y = py - 54
                    flip_flag = 0
                    
                    if (i == menu_selected .and. flipping) then
                        dw = int(108.0 * (1.0 - flip_phase))
                        dx = px - dw / 2
                        dst%w = dw
                        dst%x = dx
                        if (flip_timer > 4) flip_flag = SDL_FLIP_HORIZONTAL
                        call texture_draw_part_ex(crystals(i), renderer, src, dst, flip_flag)
                    else
                        call texture_draw_part(crystals(i), renderer, src, dst)
                    end if
                    
                    if (i == menu_selected .and. .not. flipping) then
                        call sdl_set_render_draw_color(renderer, uint8(255), uint8(20), uint8(147), uint8(pulse_alpha))
                        ! Слой 1
                        call sdl_render_draw_line(renderer, px,      py - 54, px + 54, py)
                        call sdl_render_draw_line(renderer, px + 54, py,      px,      py + 54)
                        call sdl_render_draw_line(renderer, px,      py + 54, px - 54, py)
                        call sdl_render_draw_line(renderer, px - 54, py,      px,      py - 54)
                        ! Слой 2
                        call sdl_render_draw_line(renderer, px,      py - 55, px + 55, py)
                        call sdl_render_draw_line(renderer, px + 55, py,      px,      py + 55)
                        call sdl_render_draw_line(renderer, px,      py + 55, px - 55, py)
                        call sdl_render_draw_line(renderer, px - 55, py,      px,      py - 55)
                        ! Слой 3
                        call sdl_render_draw_line(renderer, px,      py - 53, px + 53, py)
                        call sdl_render_draw_line(renderer, px + 53, py,      px,      py + 53)
                        call sdl_render_draw_line(renderer, px,      py + 53, px - 53, py)
                        call sdl_render_draw_line(renderer, px - 53, py,      px,      py - 53)
                    end if
                end do
                
                call ui_draw_text(renderer, trim(menu_labels(menu_selected)), cx + off + 100, cy - 10, 255, 255, 255)
            end block
        end if

        ! --- Отрисовка подменю (Stato / Magia) ---
        if (current_submenu > 0) then
            if (current_submenu == 1) then
                call draw_character_status(renderer, portrait_tex, menu_panel_tex, portrait_frame_tex, status_y)
            else if (current_submenu == 2) then
                call draw_magic_menu(renderer, mystic_card_tex, portrait_tex, portrait_frame_tex, status_y)
            end if
        end if

        ! --- Интерфейс (Тумблеры аудио) ---
        if (.not. pause_menu_open) then            
            call ui_draw_text(renderer, "Audio", 1050, 30, 255, 255, 255)
            if (ui_toggle_simple(renderer, tex_track, tex_thumb, 1150, 20, 80, 40, sound_on)) print *, "Audio: ", sound_on

            call ui_draw_text(renderer, "Musica", 1050, 90, 255, 255, 255)
            if (ui_toggle_simple(renderer, tex_track, tex_thumb, 1150, 80, 80, 40, music_on)) print *, "Musica: ", music_on            
        end if

        ! --- Меню паузы (ESC) ---
        if (pause_menu_open) then
            call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
            block
                type(sdl_rect) :: ov
                ov%x = 0; ov%y = 0; ov%w = 1280; ov%h = 720
                call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(220))
                call sdl_render_fill_rect(renderer, ov)
            end block

            if (ui_button(renderer, btn_tex, 540, 280, 200, 50, "Riprendi", 150, 255, 150, 0, 0, 0)) then
                pause_menu_open = .false.
            end if
            if (ui_button(renderer, btn_tex, 540, 360, 200, 50, "Esci", 255, 100, 100, 255, 255, 255)) then
                running = 0
            end if
        end if

        call sdl_render_present(renderer)
        call ui_update()
    end do ! Конец главного игрового цикла
    
    ! =====================================================================
    ! 7. ОЧИСТКА ПАМЯТИ И ВЫХОД
    ! =====================================================================
    call audio_shutdown()

    call texture_free(btn_tex)
    call texture_free(tex_track)
    call texture_free(tex_thumb)
    call texture_free(tex_down)
    call texture_free(tex_up)
    call texture_free(tex_right)
    call texture_free(crystal_red)
    call texture_free(crystal_blue)
    call texture_free(crystal_yellow)
    call texture_free(crystal_green)
    call texture_free(menu_panel_tex)
    call texture_free(portrait_frame_tex)
    call texture_free(portrait_tex)
    call texture_free(mystic_card_tex)

    call sdl_destroy_renderer(renderer)
    call sdl_destroy_window(window)
    call sdl_quit()

contains

    ! =====================================================================
    ! 8. ПОДПРОГРАММЫ
    ! =====================================================================

    subroutine load_maps_list(filename, folders, count)
        character(len=*), intent(in) :: filename
        character(len=50), allocatable, intent(out) :: folders(:)
        integer, intent(out) :: count
        integer :: io, i
        character(len=300) :: line
        
        count = 0
        open(10, file=filename, status='old', iostat=io)
        if (io /= 0) stop "ОШИБКА: Не найден файл " // trim(filename)
        
        do
            read(10, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            if (line(1:1) == '[') count = count + 1
        end do
        rewind(10)
        
        allocate(folders(count))
        i = 1
        do
            read(10, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            if (line(1:1) == '[') then
                folders(i) = line(2:index(line, ']')-1)
                i = i + 1
            end if
        end do
        close(10)
    end subroutine

    subroutine get_map_settings(filename, folder_name, config)
        character(len=*), intent(in) :: filename
        character(len=*), intent(in) :: folder_name
        type(map_settings), intent(out) :: config
        integer :: io, eq_pos
        character(len=300) :: line
        character(len=50) :: key
        character(len=150) :: value
        logical :: in_block
        
        in_block = .false.
        open(11, file=filename, status='old', iostat=io)
        if (io /= 0) return
        
        do
            read(11, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            
            if (len_trim(line) == 0 .or. line(1:1) == '#') cycle
            
            if (line(1:1) == '[') then
                if (index(line, trim(folder_name)) > 0) then
                    in_block = .true.
                    config%folder = trim(folder_name)
                else
                    in_block = .false.
                end if
                cycle
            end if
            
            if (in_block) then
                eq_pos = index(line, '=')
                if (eq_pos > 0) then
                    key = trim(adjustl(line(1:eq_pos-1)))
                    value = trim(adjustl(line(eq_pos+1:)))
                    
                    select case (key)
                        case ('tileset');   config%tileset = value
                        case ('music');     config%music = value
                        case ('layout');    config%layout_file = value
                        case ('collision'); config%collision_file = value
                        case ('areas');     config%areas_file = value
                        case ('warps');     config%warps_file = value
                        case ('chests');    config%chests_file = value
                    end select
                end if
            end if
        end do
        close(11)
    end subroutine

    subroutine load_character_assets(renderer, char_name, tex_down, tex_up, tex_right, tex_portrait)
        type(c_ptr), intent(in) :: renderer
        character(len=*), intent(in) :: char_name
        type(texture_t), intent(out) :: tex_down, tex_up, tex_right, tex_portrait
        
        character(len=150) :: sprite_dir, portrait_file
        character(len=250) :: path
        integer :: io, eq_pos
        character(len=300) :: line
        character(len=50) :: key
        character(len=150) :: value
        logical :: in_block
        
        sprite_dir = "mapsprites/" // trim(char_name) // "/"
        portrait_file = "portraits/" // trim(char_name) // ".png"
        
        in_block = .false.
        open(12, file="assets_game/characters/characters.txt", status='old', iostat=io)
        if (io == 0) then
            do
                read(12, '(A)', iostat=io) line
                if (io /= 0) exit
                line = adjustl(line)
                
                if (len_trim(line) == 0 .or. line(1:1) == '#') cycle
                
                if (line(1:1) == '[') then
                    if (index(line, trim(char_name)) > 0) then
                        in_block = .true.
                    else
                        in_block = .false.
                    end if
                    cycle
                end if
                
                if (in_block) then
                    eq_pos = index(line, '=')
                    if (eq_pos > 0) then
                        key = trim(adjustl(line(1:eq_pos-1)))
                        value = trim(adjustl(line(eq_pos+1:)))
                        select case (key)
                            case ('mapsprite'); sprite_dir = value
                            case ('portrait');  portrait_file = value
                        end select
                    end if
                end if
            end do
            close(12)
        else
            print *, "ВНИМАНИЕ: characters.txt не найден. Используем пути по умолчанию."
        end if

        write(path, '(A,A,A,A)') "assets_game/characters/", trim(sprite_dir), trim(char_name), "_down.png"
        call texture_load(tex_down, renderer, trim(path))

        write(path, '(A,A,A,A)') "assets_game/characters/", trim(sprite_dir), trim(char_name), "_up.png"
        call texture_load(tex_up, renderer, trim(path))

        write(path, '(A,A,A,A)') "assets_game/characters/", trim(sprite_dir), trim(char_name), "_right.png"
        call texture_load(tex_right, renderer, trim(path))

        write(path, '(A,A)') "assets_game/characters/", trim(portrait_file)
        call texture_load(tex_portrait, renderer, trim(path))
    end subroutine

end program