module audio
    use, intrinsic :: iso_c_binding
    implicit none

    integer(c_int), parameter :: MIX_DEFAULT_FORMAT = 32784
    integer(c_int), parameter :: MIX_MAX_VOLUME = 128

    ! Указатель на текущий играющий трек. Живёт весь процесс.
    type(c_ptr) :: current_music = c_null_ptr

    interface
        function mix_open_audio(freq, format, channels, chunksize) bind(C, name="Mix_OpenAudio") result(r)
            import :: c_int
            integer(c_int), value :: freq, format, channels, chunksize
            integer(c_int) :: r
        end function

        function mix_load_mus(file) bind(C, name="Mix_LoadMUS") result(p)
            import :: c_char, c_ptr
            character(kind=c_char), intent(in) :: file(*)
            type(c_ptr) :: p
        end function
        function mix_load_wav(file) bind(C, name="Mix_LoadWAV") result(p)
            import :: c_char, c_ptr
            character(kind=c_char), intent(in) :: file(*)
            type(c_ptr) :: p
        end function

        function mix_play_music(music, loops) bind(C, name="Mix_PlayMusic") result(r)
            import :: c_ptr, c_int
            type(c_ptr), value :: music
            integer(c_int), value :: loops
            integer(c_int) :: r
        end function
        function mix_play_channel(channel, chunk, loops) bind(C, name="Mix_PlayChannel") result(r)
            import :: c_ptr, c_int
            integer(c_int), value :: channel, loops
            type(c_ptr), value :: chunk
            integer(c_int) :: r
        end function

        subroutine mix_halt_music() bind(C, name="Mix_HaltMusic")
        end subroutine
        subroutine mix_free_music(music) bind(C, name="Mix_FreeMusic")
            import :: c_ptr
            type(c_ptr), value :: music
        end subroutine
        subroutine mix_free_chunk(chunk) bind(C, name="Mix_FreeChunk")
            import :: c_ptr
            type(c_ptr), value :: chunk
        end subroutine
        subroutine mix_close_audio() bind(C, name="Mix_CloseAudio")
        end subroutine
    end interface

contains

    subroutine audio_init()
        integer(c_int) :: r
        r = mix_open_audio(44100, MIX_DEFAULT_FORMAT, 2, 2048)
        if (r /= 0) print *, "ОШИБКА: Не удалось инициализировать SDL_mixer"
        current_music = c_null_ptr
    end subroutine

    subroutine audio_play_music(filename, loops)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: loops
        type(c_ptr) :: new_music
        integer(c_int) :: r

        ! Освобождаем предыдущий трек, если он был
        if (c_associated(current_music)) then
            call mix_halt_music()
            call mix_free_music(current_music)
            current_music = c_null_ptr
        end if

        new_music = mix_load_mus(trim(filename) // c_null_char)
        if (.not. c_associated(new_music)) then
            print *, "ОШИБКА: Не найден музыкальный файл ", trim(filename)
            return
        end if

        current_music = new_music

        r = mix_play_music(current_music, int(loops, c_int))
        if (r /= 0) print *, "ПРЕДУПРЕЖДЕНИЕ: Mix_PlayMusic вернул код ", r
    end subroutine

    subroutine audio_stop_music()
        call mix_halt_music()
        if (c_associated(current_music)) then
            call mix_free_music(current_music)
            current_music = c_null_ptr
        end if
    end subroutine

    subroutine audio_shutdown()
        call audio_stop_music()
        call mix_close_audio()
    end subroutine

end module audio