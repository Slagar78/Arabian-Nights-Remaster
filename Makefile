FC      = gfortran
FCFLAGS = -O2 -Wall -fno-range-check -Ilib -Isrc
INC     = -IC:/msys64/ucrt64/include/SDL2
LIB     = -LC:/msys64/ucrt64/lib -lSDL2 -lSDL2_image -lSDL2_ttf

# Разделяем объектные файлы движка и игры
LIB_OBJ = lib/sdl_bind.o lib/textures.o lib/timer.o
SRC_OBJ = src/ui.o src/map.o src/camera.o src/player.o src/main.o

OBJ = $(LIB_OBJ) $(SRC_OBJ)

app.exe: $(OBJ)
	$(FC) -o $@ $(OBJ) $(LIB)

# Правило сборки для папки lib
lib/%.o: lib/%.f90
	$(FC) $(FCFLAGS) $(INC) -c $< -o $@

# Правило сборки для папки src
src/%.o: src/%.f90
	$(FC) $(FCFLAGS) $(INC) -c $< -o $@

run: app.exe
	cp -f /c/msys64/ucrt64/bin/SDL2.dll . 2>/dev/null || true
	cp -f /c/msys64/ucrt64/bin/SDL2_image.dll . 2>/dev/null || true
	cp -f /c/msys64/ucrt64/bin/SDL2_ttf.dll . 2>/dev/null || true
	cmd //c "chcp 65001 >nul & app.exe"

clean:
	rm -f lib/*.o lib/*.mod src/*.o src/*.mod *.mod *.exe SDL2*.dll