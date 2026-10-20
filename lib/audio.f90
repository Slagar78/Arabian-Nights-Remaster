module audio
    use, intrinsic :: iso_c_binding
    implicit none

    ! Константы SDL_mixer
    integer(c_int), parameter :: MIX_DEFAULT_FORMAT = 32784 ! AUDIO_S16LSB
    integer(c_int), parameter :: MIX_MAX_VOLUME = 128

    interface
        ! Инициализация аудио
        function mix_open_audio(freq, format, channels, chunksize) bind(C, name="Mix_OpenAudio") result(r)
            import :: c_int
            integer(c_int), value :: freq, format, channels, chunksize
            integer(c_int) :: r
        end function

        ! Загрузка музыки (OGG, MP3) и звуков (WAV)
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

        ! Проигрывание (ВОЗВРАЩАЕТ INTEGER, А НЕ ПОДПРОГРАММА!)
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

        ! Остановка и очистка
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
    ! Инициализация аудиосистемы
    subroutine audio_init()
        integer(c_int) :: r
        r = mix_open_audio(44100, MIX_DEFAULT_FORMAT, 2, 2048)
        if (r /= 0) print *, "ОШИБКА: Не удалось инициализировать SDL_mixer"
    end subroutine

    ! Проиграть фоновую музыку (-1 = бесконечный цикл, 0 = 1 раз)
    subroutine audio_play_music(filename, loops)
        character(len=*), intent(in) :: filename
        integer, intent(in) :: loops
        type(c_ptr) :: music
        integer(c_int) :: r
        
        music = mix_load_mus(trim(filename) // c_null_char)
        if (.not. c_associated(music)) then
            print *, "ОШИБКА: Не найден музыкальный файл ", trim(filename)
            return
        end if
        
        ! ВОТ ИСПРАВЛЕНИЕ: функция возвращает результат, поэтому просто присваиваем его
        r = mix_play_music(music, int(loops, c_int))
    end subroutine

    ! Остановить музыку
    subroutine audio_stop_music()
        call mix_halt_music()
    end subroutine
end module audio