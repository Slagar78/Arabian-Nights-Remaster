require 'wx'

module MapEditor
  TILE_SIZE = 64
  COLS = 38
  ROWS = 42

  # Класс холста для рисования самой карты
  class MapCanvas < Wx::ScrolledWindow
    attr_accessor :map_grid, :collision_grid, :mode, :selected_tile

    def initialize(parent)
      super(parent)
      set_background_style(Wx::BG_STYLE_PAINT)
      set_scroll_rate(10, 10)
      set_virtual_size(Wx::Size.new(COLS * TILE_SIZE, ROWS * TILE_SIZE))

      @map_grid = Array.new(ROWS) { Array.new(COLS, 0) }
      @collision_grid = Array.new(ROWS) { Array.new(COLS, 1) }
      @tile_bitmaps = [] # Массив с готовыми квадратиками 64х64
      @mode = :tiles
      @selected_tile = 1
      @drawing = false
      @draw_action = 1

      evt_paint { on_paint }
      evt_erase_background { }
      evt_left_down  { |evt| start_draw(evt, 1) }
      evt_right_down { |evt| start_draw(evt, -1) }
      evt_motion     { |evt| do_draw(evt) if @drawing }
      evt_left_up    { stop_draw }
      evt_right_up   { stop_draw }
      evt_mouse_capture_lost { stop_draw }
    end

    def stop_draw
      if @drawing
        @drawing = false
        release_mouse if has_capture?
      end
    end

    # Смещение скролла в пикселях.
    def scroll_offset
      pt = get_view_start_pixels
      [pt.x, pt.y]
    end

    # При загрузке тайлсета мы сразу режем его на отдельные картинки
    def load_tileset_image(path)
      image = Wx::Image.new(path, Wx::BitmapType::BITMAP_TYPE_ANY)
      return false unless image.ok?

      @tile_bitmaps.clear
      cols = image.width / TILE_SIZE
      rows = image.height / TILE_SIZE

      rows.times do |r|
        cols.times do |c|
          sub = image.get_sub_image(Wx::Rect.new(c * TILE_SIZE, r * TILE_SIZE, TILE_SIZE, TILE_SIZE))
          @tile_bitmaps << Wx::Bitmap.new(sub)
        end
      end
      refresh
      true
    end

    def start_draw(evt, action)
      @drawing = true
      @draw_action = action
      capture_mouse
      do_draw(evt)
    end

    def do_draw(evt)
      sx, sy = scroll_offset

      # evt.get_x/get_y - "физические" координаты окна,
      # переводим их в координаты карты (виртуальные)
      x = evt.get_x + sx
      y = evt.get_y + sy
      c = x / TILE_SIZE
      r = y / TILE_SIZE

      return if r < 0 || r >= ROWS || c < 0 || c >= COLS

      if @mode == :tiles
        new_tile = @draw_action == 1 ? @selected_tile : 0
        if @map_grid[r][c] != new_tile
          @map_grid[r][c] = new_tile
          # refresh_rect принимает Wx::Rect, и в КЛИЕНТСКИХ координатах
          refresh_rect(Wx::Rect.new(c * TILE_SIZE - sx, r * TILE_SIZE - sy,
                                    TILE_SIZE, TILE_SIZE))
        end
      else
        new_col = @draw_action == 1 ? -1 : 1
        if @collision_grid[r][c] != new_col
          @collision_grid[r][c] = new_col
          refresh_rect(Wx::Rect.new(c * TILE_SIZE - sx, r * TILE_SIZE - sy,
                                    TILE_SIZE, TILE_SIZE))
        end
      end
    end

    def on_paint
      paint_buffered do |dc|
        prepare_dc(dc)

        ROWS.times do |r|
          COLS.times do |c|
            x = c * TILE_SIZE
            y = r * TILE_SIZE
            tile_id = @map_grid[r][c]

            if tile_id > 0 && @tile_bitmaps[tile_id - 1]
              dc.draw_bitmap(@tile_bitmaps[tile_id - 1], x, y, true)
            else
              dc.set_brush(Wx::Brush.new(Wx::Colour.new(34, 34, 34)))
              dc.set_pen(Wx::TRANSPARENT_PEN)
              dc.draw_rectangle(x, y, TILE_SIZE, TILE_SIZE)
            end

            if @collision_grid[r][c] == -1
              dc.set_brush(Wx::Brush.new(Wx::Colour.new(255, 0, 0, 76)))
              dc.set_pen(Wx::TRANSPARENT_PEN)
              dc.draw_rectangle(x, y, TILE_SIZE, TILE_SIZE)

              dc.set_pen(Wx::Pen.new(Wx::Colour.new(255, 0, 0, 204), 2))
              dc.draw_line(x + 10, y + 10, x + TILE_SIZE - 10, y + TILE_SIZE - 10)
              dc.draw_line(x + TILE_SIZE - 10, y + 10, x + 10, y + TILE_SIZE - 10)
            end
          end
        end
      end
    end
  end

  # Класс палитры тайлов справа
  class PaletteCanvas < Wx::ScrolledWindow
    attr_accessor :selected_tile, :on_select

    def initialize(parent)
      super(parent)
      set_background_style(Wx::BG_STYLE_PAINT)
      set_scroll_rate(10, 10)
      set_background_colour(Wx::Colour.new(42, 42, 42))
      @selected_tile = 1
      @tileset_bitmap = nil

      evt_paint { on_paint }
      evt_erase_background { }
      evt_left_down { |evt| on_click(evt) }
    end

    # Смещение скролла в пикселях (тот же фикс, что и в MapCanvas)
    def scroll_offset
      pt = get_view_start_pixels
      [pt.x, pt.y]
    end

    def set_tileset(bitmap)
      @tileset_bitmap = bitmap
      w = (bitmap.width / TILE_SIZE) * TILE_SIZE
      h = (bitmap.height / TILE_SIZE) * TILE_SIZE
      set_virtual_size(Wx::Size.new(w, h))
      refresh
    end

    def on_click(evt)
      return unless @tileset_bitmap
      sx, sy = scroll_offset
      x = evt.get_x + sx
      y = evt.get_y + sy
      c = x / TILE_SIZE
      r = y / TILE_SIZE
      cols = @tileset_bitmap.width / TILE_SIZE
      rows = @tileset_bitmap.height / TILE_SIZE

      if c >= 0 && c < cols && r >= 0 && r < rows
        @selected_tile = r * cols + c + 1
        @on_select.call(@selected_tile) if @on_select
        refresh
      end
    end

    def on_paint
      paint_buffered do |dc|
        prepare_dc(dc)
        next unless @tileset_bitmap

        dc.draw_bitmap(@tileset_bitmap, 0, 0, false)

        dc.set_pen(Wx::Pen.new(Wx::Colour.new(255, 255, 255, 51), 1))
        w = @tileset_bitmap.width
        h = @tileset_bitmap.height
        (0..w).step(TILE_SIZE).each { |x| dc.draw_line(x, 0, x, h) }
        (0..h).step(TILE_SIZE).each { |y| dc.draw_line(0, y, w, y) }

        sel_idx = @selected_tile - 1
        if sel_idx >= 0
          cols = w / TILE_SIZE
          sx = (sel_idx % cols) * TILE_SIZE
          sy = (sel_idx / cols) * TILE_SIZE
          dc.set_pen(Wx::Pen.new(Wx::Colour.new(76, 175, 80), 4))
          dc.set_brush(Wx::TRANSPARENT_BRUSH)
          dc.draw_rectangle(sx, sy, TILE_SIZE, TILE_SIZE)
        end
      end
    end
  end

  # Главное окно приложения
  class MainFrame < Wx::Frame
    def initialize
      super(nil, title: "Arabian Nights - Map Editor", size: Wx::Size.new(1280, 800))
      create_controls
      layout_ui
      centre
    end

    def create_controls
      @btn_load_layout = Wx::Button.new(self, label: '1. Загрузить layout.bin')
      @btn_load_tileset = Wx::Button.new(self, label: '2. Загрузить tileset.png')
      @btn_load_collision = Wx::Button.new(self, label: '3. Загрузить collision.bin')
      @status = Wx::StaticText.new(self, label: 'Ждем файлы...')

      @btn_mode_tiles = Wx::ToggleButton.new(self, label: '🖌️ Режим: Рисовать тайлы')
      @btn_mode_collision = Wx::ToggleButton.new(self, label: '🧱 Режим: Рисовать стены')
      @btn_clear_col = Wx::Button.new(self, label: '🗑️ Очистить стены')
      @btn_save_layout = Wx::Button.new(self, label: '💾 Скачать layout.bin')
      @btn_save_collision = Wx::Button.new(self, label: '💾 Скачать collision.bin')

      @splitter = Wx::SplitterWindow.new(self, style: Wx::SP_LIVE_UPDATE)

      @map_canvas = MapCanvas.new(@splitter)

      palette_panel = Wx::Panel.new(@splitter)
      @lbl_selected = Wx::StaticText.new(palette_panel, label: 'Выбран тайл: 1')
      pal_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
      pal_sizer.add(@lbl_selected, 0, Wx::ALL, 5)
      @palette_canvas = PaletteCanvas.new(palette_panel)
      pal_sizer.add(@palette_canvas, 1, Wx::EXPAND | Wx::ALL, 5)
      palette_panel.set_sizer(pal_sizer)

      @splitter.split_vertically(@map_canvas, palette_panel, 900)

      @btn_load_layout.evt_button(Wx::ID_ANY) { load_layout }
      @btn_load_tileset.evt_button(Wx::ID_ANY) { load_tileset }
      @btn_load_collision.evt_button(Wx::ID_ANY) { load_collision }

      @btn_mode_tiles.evt_togglebutton(Wx::ID_ANY) { set_mode(:tiles) }
      @btn_mode_collision.evt_togglebutton(Wx::ID_ANY) { set_mode(:collision) }
      @btn_clear_col.evt_button(Wx::ID_ANY) { clear_collisions }
      @btn_save_layout.evt_button(Wx::ID_ANY) { save_layout }
      @btn_save_collision.evt_button(Wx::ID_ANY) { save_collision }

      @palette_canvas.on_select = lambda do |tile_id|
        @lbl_selected.set_label("Выбран тайл: #{tile_id}")
        @map_canvas.selected_tile = tile_id
      end

      set_mode(:tiles)
    end

    def layout_ui
      main_sizer = Wx::BoxSizer.new(Wx::VERTICAL)

      header_sizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      header_sizer.add(@btn_load_layout, 0, Wx::ALL, 5)
      header_sizer.add(@btn_load_tileset, 0, Wx::ALL, 5)
      header_sizer.add(@btn_load_collision, 0, Wx::ALL, 5)
      header_sizer.add(@status, 1, Wx::ALIGN_CENTER_VERTICAL | Wx::LEFT, 10)

      toolbar_sizer = Wx::BoxSizer.new(Wx::HORIZONTAL)
      toolbar_sizer.add(@btn_mode_tiles, 0, Wx::ALL, 5)
      toolbar_sizer.add(@btn_mode_collision, 0, Wx::ALL, 5)
      toolbar_sizer.add(@btn_clear_col, 0, Wx::ALL, 5)
      toolbar_sizer.add_spacer(20)
      toolbar_sizer.add(@btn_save_layout, 0, Wx::ALL, 5)
      toolbar_sizer.add(@btn_save_collision, 0, Wx::ALL, 5)

      main_sizer.add(header_sizer, 0, Wx::EXPAND | Wx::ALL, 5)
      main_sizer.add(toolbar_sizer, 0, Wx::EXPAND | Wx::ALL, 5)
      main_sizer.add(@splitter, 1, Wx::EXPAND | Wx::ALL, 5)

      set_sizer(main_sizer)
    end

    def set_mode(mode)
      if mode == :tiles
        @btn_mode_tiles.set_value(true)
        @btn_mode_collision.set_value(false)
        @map_canvas.mode = :tiles
      else
        @btn_mode_tiles.set_value(false)
        @btn_mode_collision.set_value(true)
        @map_canvas.mode = :collision
      end
    end

    # ИСПРАВЛЕНО: "../data/maps" вместо "../../data/maps"
    def load_layout
      default_dir = File.expand_path("../data/maps", __dir__)
      default_dir = Dir.pwd unless Dir.exist?(default_dir)

      dialog = Wx::FileDialog.new(self, 'Загрузить layout.bin', default_dir, '', 'Binary layout (*.bin)|*.bin', Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST)
      return unless dialog.show_modal == Wx::ID_OK
      path = dialog.path
      begin
        data = File.binread(path)
        if data.size == ROWS * COLS * 2
          vals = data.unpack('v*')
          idx = 0
          ROWS.times do |r|
            COLS.times do |c|
              @map_canvas.map_grid[r][c] = vals[idx]
              idx += 1
            end
          end
          @status.set_label('layout.bin загружен!')
          @map_canvas.refresh
        else
          Wx.message_box("Неверный размер файла! Ожидалось #{ROWS * COLS * 2} байт.", "Ошибка", Wx::OK | Wx::ICON_ERROR, self)
        end
      rescue => e
        Wx.message_box("Ошибка загрузки: #{e.message}", "Ошибка", Wx::OK | Wx::ICON_ERROR, self)
      end
    end

    # ИСПРАВЛЕНО: "../data/maps"
    def load_collision
      default_dir = File.expand_path("../data/maps", __dir__)
      default_dir = Dir.pwd unless Dir.exist?(default_dir)

      dialog = Wx::FileDialog.new(self, 'Загрузить collision.bin', default_dir, '', 'Binary collision (*.bin)|*.bin', Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST)
      return unless dialog.show_modal == Wx::ID_OK
      path = dialog.path
      begin
        data = File.binread(path)
        if data.size == ROWS * COLS
          vals = data.unpack('c*')
          idx = 0
          ROWS.times do |r|
            COLS.times do |c|
              @map_canvas.collision_grid[r][c] = vals[idx]
              idx += 1
            end
          end
          @status.set_label('collision.bin загружен!')
          @map_canvas.refresh
        else
          Wx.message_box("Неверный размер файла! Ожидалось #{ROWS * COLS} байт.", "Ошибка", Wx::OK | Wx::ICON_ERROR, self)
        end
      rescue => e
        Wx.message_box("Ошибка загрузки: #{e.message}", "Ошибка", Wx::OK | Wx::ICON_ERROR, self)
      end
    end

    # ИСПРАВЛЕНО: "../assets_game/tilesets"
    def load_tileset
      default_dir = File.expand_path("../assets_game/tilesets", __dir__)
      default_dir = Dir.pwd unless Dir.exist?(default_dir)

      dialog = Wx::FileDialog.new(self, 'Загрузить tileset.png', default_dir, '', 'PNG image (*.png)|*.png', Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST)
      return unless dialog.show_modal == Wx::ID_OK
      path = dialog.path

      success = @map_canvas.load_tileset_image(path)

      if success
        image = Wx::Image.new(path, Wx::BitmapType::BITMAP_TYPE_ANY)
        @palette_canvas.set_tileset(Wx::Bitmap.new(image))
        @status.set_label('Тайлсет загружен!')
      else
        Wx.message_box('Не удалось открыть изображение.', 'Ошибка', Wx::OK | Wx::ICON_ERROR, self)
      end
    end

    # ИСПРАВЛЕНО: "../data/maps"
    def save_layout
      default_dir = File.expand_path("../data/maps", __dir__)
      default_dir = Dir.pwd unless Dir.exist?(default_dir)

      dialog = Wx::FileDialog.new(self, 'Сохранить layout.bin', default_dir, 'layout.bin', 'Binary layout (*.bin)|*.bin', Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT)
      return unless dialog.show_modal == Wx::ID_OK
      path = dialog.path
      path += '.bin' unless path.downcase.end_with?('.bin')
      flat = @map_canvas.map_grid.flatten
      File.binwrite(path, flat.pack('v*'))
      @status.set_label('layout.bin сохранен!')
    end

    # ИСПРАВЛЕНО: "../data/maps"
    def save_collision
      default_dir = File.expand_path("../data/maps", __dir__)
      default_dir = Dir.pwd unless Dir.exist?(default_dir)

      dialog = Wx::FileDialog.new(self, 'Сохранить collision.bin', default_dir, 'collision.bin', 'Binary collision (*.bin)|*.bin', Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT)
      return unless dialog.show_modal == Wx::ID_OK
      path = dialog.path
      path += '.bin' unless path.downcase.end_with?('.bin')
      flat = @map_canvas.collision_grid.flatten
      File.binwrite(path, flat.pack('c*'))
      @status.set_label('collision.bin сохранен!')
    end

    def clear_collisions
      ROWS.times do |r|
        COLS.times do |c|
          @map_canvas.collision_grid[r][c] = 1
        end
      end
      @map_canvas.refresh
      @status.set_label('Коллизии очищены!')
    end
  end
end

Wx::App.run do
  MapEditor::MainFrame.new.show
end