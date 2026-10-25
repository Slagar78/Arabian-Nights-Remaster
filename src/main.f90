program rts_prototype
    use, intrinsic :: iso_c_binding
    use :: sdl2
    use :: audio
    use :: textures
    use :: ui
    use :: game_map
    use :: game_camera
    use :: game_player
    use :: timer
    use :: game_intro
    use :: ui_status
    use :: ui_magia
    
    implicit none

    type :: map_settings
        character(len=50)  :: folder = ""
        character(len=150) :: tileset = ""
        character(len=150) :: music = ""
        character(len=150) :: layout_file = ""    ! <--- стало 150
        character(len=150) :: collision_file = "" ! <--- стало 150
        character(len=150) :: areas_file = ""     ! <--- стало 150
        character(len=150) :: warps_file = ""     ! <--- стало 150
        character(len=150) :: chests_file = ""    ! <--- стало 150
    end type

    type(c_ptr) :: window, renderer
    type(sdl_event) :: ev
    integer :: running, have_event, numkeys
    type(c_ptr) :: kptr
    integer(c_int8_t), pointer :: keys(:)
    
    type(texture_t) :: btn_tex, tex_track, tex_thumb
    type(texture_t) :: tex_down, tex_up, tex_right
    type(texture_t) :: crystal_red, crystal_blue, crystal_yellow, crystal_green
    type(texture_t) :: menu_panel_tex, portrait_frame_tex, portrait_tex
    type(texture_t) :: mystic_card_tex
    
    logical :: sound_on, music_on
    type(sdl_rect) :: top_bar

    logical :: menu_open = .false.
    logical :: pause_menu_open = .false.
    logical :: pending_menu_request = .false.
    integer :: menu_selected = 0 
    integer :: current_submenu = 0 
    ! Ждём РЕАЛЬНОЙ остановки камеры (cam_x/cam_y не меняются),
    ! а не флага cam_arrived — он true даже когда карта скроллится
    ! вместе с игроком у края экрана.
    integer :: menu_still_frames = 0
    integer :: menu_last_cam_x = -99999
    integer :: menu_last_cam_y = -99999
    
    integer :: status_y = 720      ! Начальное положение меню (за нижним краем экрана)
    integer :: status_state = 0    ! Состояние: 0=скрыто, 1=выезжает, 2=открыто, 3=уезжает
    
    logical :: flipping = .false.
    integer :: flip_timer = 0
    real :: flip_phase = 0.0
    
    character(len=20) :: menu_labels(0:3)
    
    character(len=50), allocatable :: map_folders(:)
    integer :: num_maps
    character(len=50)  :: current_folder
    character(len=150) :: layout_path, collision_path, areas_path
    type(map_settings) :: current_config

    integer(c_int8_t) :: prev_keys(512)
    prev_keys = 0_c_int8_t

    menu_labels(0) = "Stato"
    menu_labels(1) = "Magia"
    menu_labels(2) = "Oggetti"
    menu_labels(3) = "Cerca"

    if (sdl_init(SDL_INIT_VIDEO) /= 0) stop "SDL_Init failed"
    
    window = sdl_create_window("Arabian Nights Remaster" // c_null_char, &
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 1280, 720, SDL_WINDOW_SHOWN)
        
    renderer = sdl_create_renderer(window, -1, SDL_RENDERER_ACCELERATED + SDL_RENDERER_PRESENTVSYNC)

    call texture_load(btn_tex, renderer, "assets/button.png")
    call texture_load(tex_track, renderer, "assets/track.png")
    call texture_load(tex_thumb, renderer, "assets/thumb.png")
    
    call texture_load(tex_down, renderer, "assets_game/characters/mapsprites/Shukran_down.png")
    call texture_load(tex_up, renderer, "assets_game/characters/mapsprites/Shukran_up.png")
    call texture_load(tex_right, renderer, "assets_game/characters/mapsprites/Shukran_right.png")
    
    call texture_load(crystal_red, renderer, "assets_game/menu/crystal/crystal.png")
    call texture_load(crystal_blue, renderer, "assets_game/menu/crystal/crystal_2.png")
    call texture_load(crystal_yellow, renderer, "assets_game/menu/crystal/crystal_4.png")
    call texture_load(crystal_green, renderer, "assets_game/menu/crystal/crystal_3.png")
    call texture_load(menu_panel_tex, renderer, "assets_game/menu/menu_panel.png")
    call texture_load(portrait_frame_tex, renderer, "assets_game/menu/portrait_frame.png")
    call texture_load(portrait_tex, renderer, "assets_game/portraits/shukran.png")
    call texture_load(mystic_card_tex, renderer, "assets_game/menu/mystic_card.png")
    
    call ui_init()
    
    ! ==========================================
    ! ЗАПУСКАЕМ АУДИО И МУЗЫКУ ИНТРО
    ! ==========================================
    call audio_init() ! Включаем аудиосистему SDL2_mixer
    
    ! Запускаем музыку (0 = проиграть 1 раз, -1 = бесконечный цикл)
    call audio_play_music("assets_game/music/intro.ogg", 0) 
    ! ==========================================

    ! ЗАПУСКАЕМ PS1-ИНТРО
    call play_intro(renderer)
    
    ! Загружаем список карт и их настройки из нового файла
    call load_maps_list("data/maps/maplist.txt", map_folders, num_maps)
    if (num_maps == 0) stop "ОШИБКА: Список карт пуст!"
    
    current_folder = trim(map_folders(1))
    
    ! Получаем настройки для первой карты
    call get_map_settings("data/maps/maplist.txt", current_folder, current_config)

    ! Формируем пути на основе данных из файла
    write(layout_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%layout_file)
    write(collision_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%collision_file)
    write(areas_path, '(A,A,A,A)') "data/maps/", trim(current_folder), "/", trim(current_config%areas_file)
    
    print *, "=== ЗАГРУЗКА: ", trim(current_folder), " ==="
    print *, "Тайлсет: ", trim(current_config%tileset)
    
    call map_load(trim(layout_path), renderer, trim(current_config%tileset), trim(collision_path), trim(areas_path))
    
    if (len_trim(current_config%music) > 0) then
        call audio_play_music(trim(current_config%music), -1) ! -1 значит "играть бесконечно"
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

    do while (running /= 0)
        have_event = sdl_poll_event(ev)
        do while (have_event /= 0)
            if (ev%type_ == SDL_QUITEVENT) running = 0
            have_event = sdl_poll_event(ev)
        end do
        
        if (timer_update()) then
            
            ! --- АНИМАЦИЯ ВЫЕЗДА/УЕЗДА МЕНЮ СТАТУСА ---
            if (status_state == 1) then
                status_y = status_y - 80    ! Скорость выезда (80 пикс/кадр - очень быстро)
                if (status_y <= 0) then
                    status_y = 0
                    status_state = 2        ! Меню на месте, ждем нажатий
                end if
            else if (status_state == 3) then
                status_y = status_y + 80    ! Скорость уезда
                if (status_y >= 720) then
                    status_y = 720
                    status_state = 0        ! Меню полностью уехало
                    current_submenu = 0     ! Теперь возвращаемся в главное меню
                    menu_open = .true.
                end if
            end if

            ! Открытие/закрытие меню паузы по Esc
            if (keys(42) /= 0 .and. prev_keys(42) == 0) then
                pause_menu_open = .not. pause_menu_open
                if (pause_menu_open) then
                    menu_open = .false.
                    current_submenu = 0
                end if
            end if

            if (current_submenu > 0) then
                if (keys(23) /= 0 .and. prev_keys(23) == 0) then
                    if (status_state == 2) then
                        status_state = 3    ! Запускаем анимацию уезда вниз ДЛЯ ЛЮБОГО МЕНЮ
                    end if
                end if
            else
                if ((keys(5) /= 0 .and. prev_keys(5) == 0) .or. (keys(8) /= 0 .and. prev_keys(8) == 0)) then
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
                        else if (menu_selected == 1) then  !
                            current_submenu = 2 
                            status_y = 720
                            status_state = 1
                        end if
                        menu_open = .false. 
                    end if
                end if

                if (menu_open) then
                    if (keys(83) /= 0 .and. prev_keys(83) == 0 .and. menu_selected /= 0) then
                        menu_selected = 0; flipping = .true.; flip_timer = 0
                    else if (keys(81) /= 0 .and. prev_keys(81) == 0 .and. menu_selected /= 1) then
                        menu_selected = 1; flipping = .true.; flip_timer = 0
                    else if (keys(80) /= 0 .and. prev_keys(80) == 0 .and. menu_selected /= 2) then
                        menu_selected = 2; flipping = .true.; flip_timer = 0
                    else if (keys(82) /= 0 .and. prev_keys(82) == 0 .and. menu_selected /= 3) then
                        menu_selected = 3; flipping = .true.; flip_timer = 0
                    end if
                    
                    if (keys(23) /= 0 .and. prev_keys(23) == 0) then
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
            
            if (.not. menu_open .and. current_submenu == 0 .and. .not. pause_menu_open) then
                
                ! Если меню уже запрошено, но мы еще идем - 
                ! передаем пустые клавиши, чтобы персонаж не делал новых шагов
                if (pending_menu_request) then
                    block
                        integer(c_int8_t) :: empty_keys(512)
                        empty_keys = 0_c_int8_t
                        call player_update(empty_keys)
                    end block
                else
                    call player_update(keys)
                end if
                
                ! Обычная камера (логика deadzone как была).
                if (moving) then
                    call camera_update(px, py, direction)
                else
                    call camera_update(px, py, 0)
                end if

                ! Меню только когда: Шукран стоит на тайле И камера
                ! реально не двигалась несколько кадров (скролл карты закончен).
                if (pending_menu_request) then
                    if (.not. moving .and. target_tile_x == -1) then
                        if (cam_x == menu_last_cam_x .and. cam_y == menu_last_cam_y) then
                            menu_still_frames = menu_still_frames + 1
                        else
                            menu_still_frames = 0
                        end if
                        ! ~8 кадров @ 60fps — камера точно стоит
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
            end if
            
            prev_keys = keys
        end if

        call sdl_set_render_draw_color(renderer, uint8(210), uint8(180), uint8(140), uint8(255))
        call sdl_render_clear(renderer)

        call map_draw(renderer, cam_x, cam_y)
        
        top_bar%x = -cam_x
        top_bar%y = -cam_y - 64
        call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(255))
        call sdl_render_fill_rect(renderer, top_bar)

        call player_draw(renderer, tex_down, tex_up, tex_right, cam_x, cam_y)

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
                
                ! 1. Увеличили off (отступ), чтобы 108x108 ромбы не слипались
                cx = 640; cy = 580; off = 56
                
                ! 2. Вырезаем из текстуры квадрат 108x108
                src%x = 0; src%y = 0; src%w = 108; src%h = 108
                
                do i = 0, 3
                    if (.not. crystals(i)%loaded) cycle 
                    
                    if (i == 0) then; px = cx; py = cy - off; end if
                    if (i == 1) then; px = cx - off; py = cy; end if
                    if (i == 2) then; px = cx + off; py = cy; end if
                    if (i == 3) then; px = cx; py = cy + off; end if
                    
                    ! 3. Размер отрисовки тоже 108x108
                    dst%w = 108; dst%h = 108
                    
                    ! 4. Центрируем (108 / 2 = 54)
                    dst%x = px - 54; dst%y = py - 54
                    flip_flag = 0
                    
                    if (i == menu_selected .and. flipping) then
                        ! 5. Меняем 64.0 на 108.0 для анимации переворота
                        dw = int(108.0 * (1.0 - flip_phase))
                        dx = px - dw / 2
                        dst%w = dw
                        dst%x = dx
                        
                        if (flip_timer > 4) then
                            flip_flag = SDL_FLIP_HORIZONTAL
                        end if
                        
                        call texture_draw_part_ex(crystals(i), renderer, src, dst, flip_flag)
                    else
                        call texture_draw_part(crystals(i), renderer, src, dst)
                    end if
                    
                    if (i == menu_selected .and. .not. flipping) then
                        call sdl_set_render_draw_color(renderer, uint8(255), uint8(215), 0_c_int8_t, 255_c_int8_t)
                        ! 6. Увеличиваем желтую рамку под размер 108 (54 вместо 34)
                        call sdl_render_draw_line(renderer, px, py - 54, px + 54, py)
                        call sdl_render_draw_line(renderer, px + 54, py, px, py + 54)
                        call sdl_render_draw_line(renderer, px, py + 54, px - 54, py)
                        call sdl_render_draw_line(renderer, px - 54, py, px, py - 54)
                    end if
                end do
                
                call ui_draw_text(renderer, trim(menu_labels(menu_selected)), cx + off + 100, cy - 10, 255, 255, 255)
                
            end block
        end if

        ! --- ОТРИСОВКА ПОДМЕНЮ ---
        if (current_submenu > 0) then
            if (current_submenu == 1) then
                call draw_character_status(renderer, portrait_tex, menu_panel_tex, portrait_frame_tex, status_y)
                
            else if (current_submenu == 2) then
                ! Вкладка "Magia" (Магия)
                call draw_magic_menu(renderer, mystic_card_tex, status_y)
                
            else if (current_submenu == 3) then
                ! Вкладка "Oggetti" (Предметы)
                ! Пока пусто, сюда будем вызывать draw_items_menu
                
            else if (current_submenu == 4) then
                ! Вкладка "Carte" (Карты Джиннов)
                ! Пока пусто, сюда будем вызывать draw_cards_menu
                
            end if
        end if

        ! Рисуем интерфейс ТОЛЬКО если меню паузы закрыто
        if (.not. pause_menu_open) then            
            call ui_draw_text(renderer, "Audio", 1050, 30, 255, 255, 255)
            if (ui_toggle_simple(renderer, tex_track, tex_thumb, 1150, 20, 80, 40, sound_on)) print *, "Audio: ", sound_on

            call ui_draw_text(renderer, "Musica", 1050, 90, 255, 255, 255)
            if (ui_toggle_simple(renderer, tex_track, tex_thumb, 1150, 80, 80, 40, music_on)) print *, "Musica: ", music_on            
        end if

         ! --- МЕНЮ ПАУЗЫ (ESC) ---
        if (pause_menu_open) then
            call sdl_set_render_draw_blend_mode(renderer, SDL_BLENDMODE_BLEND)
            
            ! Черный затемняющий экран
            block
                type(sdl_rect) :: ov
                ov%x = 0; ov%y = 0; ov%w = 1280; ov%h = 720
                call sdl_set_render_draw_color(renderer, uint8(0), uint8(0), uint8(0), uint8(220))
                call sdl_render_fill_rect(renderer, ov)
            end block

            ! Кнопка "Riprendi" (светло-зеленая)
            if (ui_button(renderer, btn_tex, 540, 280, 200, 50, "Riprendi", 150, 255, 150, 0, 0, 0)) then
                pause_menu_open = .false.
            end if

            ! Кнопка "Esci" (красная)
            if (ui_button(renderer, btn_tex, 540, 360, 200, 50, "Esci", 255, 100, 100, 255, 255, 255)) then
                running = 0
            end if
        end if
        ! -------------------------

        call sdl_render_present(renderer)
        call ui_update()
    end do ! <--- ВОТ ЗДЕСЬ ЗАКАНЧИВАЕТСЯ ИГРОВОЙ ЦИКЛ
    
    ! 1. Сначала закрываем аудио
    call audio_shutdown()

    ! 2. Освобождаем ВСЕ текстуры через нашу новую функцию
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

    ! 3. Теперь уничтожаем рендерер и окно
    call sdl_destroy_renderer(renderer)
    call sdl_destroy_window(window)
    
    ! 4. Выходим из SDL
    call sdl_quit()

contains

    ! Читаем список всех карт (ищем строки в квадратных скобках)
    subroutine load_maps_list(filename, folders, count)
        character(len=*), intent(in) :: filename
        character(len=50), allocatable, intent(out) :: folders(:)
        integer, intent(out) :: count
        integer :: io, i
        character(len=300) :: line
        
        count = 0
        open(10, file=filename, status='old', iostat=io)
        if (io /= 0) stop "ОШИБКА: Не найден файл " // trim(filename)
        
        ! Первый проход: считаем количество карт
        do
            read(10, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            if (line(1:1) == '[') count = count + 1
        end do
        rewind(10)
        
        ! Второй проход: запоминаем названия
        allocate(folders(count))
        i = 1
        do
            read(10, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            if (line(1:1) == '[') then
                ! Вырезаем текст между [ и ]
                folders(i) = line(2:index(line, ']')-1)
                i = i + 1
            end if
        end do
        close(10)
    end subroutine

    ! Читаем настройки для конкретной карты
    subroutine get_map_settings(filename, folder_name, config)
        character(len=*), intent(in) :: filename
        character(len=*), intent(in) :: folder_name
        type(map_settings), intent(out) :: config
        integer :: io, eq_pos
        character(len=300) :: line
        character(len=50) :: key
        character(len=150) :: value  ! <-- ставим 150
        logical :: in_block
        
        in_block = .false.
        open(11, file=filename, status='old', iostat=io)
        if (io /= 0) return
        
        do
            read(11, '(A)', iostat=io) line
            if (io /= 0) exit
            line = adjustl(line)
            
            ! Пропускаем пустые строки и комментарии
            if (len_trim(line) == 0 .or. line(1:1) == '#') cycle
            
            ! Если нашли начало блока
            if (line(1:1) == '[') then
                if (index(line, trim(folder_name)) > 0) then
                    in_block = .true.
                    config%folder = trim(folder_name)
                else
                    in_block = .false.
                end if
                cycle
            end if
            
            ! Если мы внутри нужного блока, читаем ключ = значение
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

end program