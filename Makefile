FC      = gfortran
FCFLAGS = -O2 -Wall -fno-range-check -J. -I. -Ilib -Isrc -Isrc/ui
INC     = -IC:/msys64/ucrt64/include/SDL2
LIB     = -LC:/msys64/ucrt64/lib -lSDL2 -lSDL2_image -lSDL2_ttf -lSDL2_mixer

# ДОБАВИЛИ src/ui/magia.o
OBJ = lib/sdl_bind.o lib/textures.o lib/timer.o lib/audio.o \
      src/ui.o src/map.o src/camera.o src/player.o src/intro.o \
      src/ui/status.o src/ui/magia.o src/main.o

app.exe: $(OBJ)
	$(FC) -o $@ $(OBJ) $(LIB)

lib/%.o: lib/%.f90
	$(FC) $(FCFLAGS) $(INC) -c $< -o $@

src/%.o: src/%.f90
	$(FC) $(FCFLAGS) $(INC) -c $< -o $@

src/ui/%.o: src/ui/%.f90
	$(FC) $(FCFLAGS) $(INC) -c $< -o $@

# ЖЕСТКИЕ ЗАВИСИМОСТИ
src/ui/status.o: src/ui.o
src/ui/magia.o: src/ui.o
# main зависит от ВСЕХ модулей, включая magia
src/main.o: src/ui/status.o src/ui/magia.o src/ui.o src/map.o src/camera.o src/player.o src/intro.o

run: app.exe
	cp -f /c/msys64/ucrt64/bin/SDL2.dll . 2>/dev/null || true
	cp -f /c/msys64/ucrt64/bin/SDL2_image.dll . 2>/dev/null || true
	cp -f /c/msys64/ucrt64/bin/SDL2_ttf.dll . 2>/dev/null || true
	cp -f /c/msys64/ucrt64/bin/SDL2_mixer.dll . 2>/dev/null || true
	cmd //c "chcp 65001 >nul & app.exe"

clean:
	rm -f lib/*.o lib/*.mod src/*.o src/*.mod src/ui/*.o src/ui/*.mod *.mod *.exe SDL2*.dll