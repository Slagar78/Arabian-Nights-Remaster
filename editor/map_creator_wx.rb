# frozen_string_literal: true
# Arabian Nights - Map to Tileset/Binary Converter
# Desktop rewrite of map-creator.html for Ruby + wxRuby3.
# Tested for syntax only in this environment; run it with the wxRuby3 installed on your Windows PC.

require 'wx'

module MapCreator
  APP_TITLE = 'Arabian Nights — Map Creator'
  DEFAULT_TILE_SIZE = 64
  DEFAULT_COLUMNS = 8
  ID_OPEN = 5101
  ID_PROCESS = 5102
  ID_EXPORT_ALL = 5103
  ID_SAVE_TILESET = 5104
  ID_SAVE_BINARY = 5105
  ID_SAVE_TEXT = 5106
  ID_TILE_SIZE = 5110
  ID_COLUMNS = 5111

  class PreviewPanel < Wx::Panel
    attr_reader :image

    def initialize(parent, show_grid: false, checkerboard: true)
      super(parent)
      @image = nil
      @show_grid = show_grid
      @checkerboard = checkerboard
      @tile_size = DEFAULT_TILE_SIZE
      set_background_colour(Wx::Colour.new(29, 32, 37))
      evt_paint do |_event|
        paint_buffered do |dc|
          dc.clear
          paint_preview(dc)
        end
      end
    end

    def set_image(image)
      @image = image
      refresh
    end

    def tile_size=(value)
      @tile_size = [value.to_i, 1].max
      refresh
    end

    def show_grid=(value)
      @show_grid = value
      refresh
    end

    private

    def paint_preview(dc)
      client = get_client_size
      cw = client.width
      ch = client.height
      return if cw < 4 || ch < 4

      unless @image && @image.ok?
        dc.set_text_foreground(Wx::Colour.new(145, 151, 160))
        dc.draw_text('Загрузите изображение карты', 18, 18)
        dc.draw_text('PNG или JPEG', 18, 42)
        return
      end

      iw = @image.width
      ih = @image.height
      return if iw <= 0 || ih <= 0

      max_w = [cw - 28, 1].max
      max_h = [ch - 28, 1].max
      scale = [max_w.to_f / iw, max_h.to_f / ih, 2.0].min
      scale = 0.01 if scale <= 0
      dw = [(iw * scale).round, 1].max
      dh = [(ih * scale).round, 1].max
      shown_image = if dw == iw && dh == ih
                      @image
                    else
                      @image.scale(dw, dh, Wx::ImageResizeQuality::IMAGE_QUALITY_NEAREST)
                    end
      bitmap = Wx::Bitmap.new(shown_image)
      dx = (cw - dw) / 2
      dy = (ch - dh) / 2

      draw_checkerboard(dc, dx, dy, dw, dh) if @checkerboard
      dc.draw_bitmap(bitmap, dx, dy, true)
      draw_grid(dc, dx, dy, dw, dh, scale) if @show_grid && @tile_size > 0
    rescue StandardError => e
      dc.set_text_foreground(Wx::Colour.new(255, 130, 130))
      dc.draw_text("Ошибка предпросмотра: #{e.message}", 12, 12)
    end

    def draw_checkerboard(dc, x, y, width, height)
      cell = 12
      light = Wx::Colour.new(51, 55, 61)
      dark = Wx::Colour.new(40, 44, 49)
      row = 0
      py = y
      while py < y + height
        col = 0
        px = x
        while px < x + width
          colour = (row + col).even? ? light : dark
          dc.set_pen(Wx::Pen.new(colour, 1))
          dc.set_brush(Wx::Brush.new(colour))
          dc.draw_rectangle(px, py, [cell, x + width - px].min, [cell, y + height - py].min)
          px += cell
          col += 1
        end
        py += cell
        row += 1
      end
    end

    def draw_grid(dc, x, y, width, height, scale)
      pen = Wx::Pen.new(Wx::Colour.new(245, 73, 73), 1)
      dc.set_pen(pen)
      image_width = @image.width
      image_height = @image.height
      col_count = image_width / @tile_size
      row_count = image_height / @tile_size
      1.upto(col_count) do |col|
        px = x + (col * @tile_size * scale).round
        dc.draw_line(px, y, px, y + height) if px < x + width
      end
      1.upto(row_count) do |row|
        py = y + (row * @tile_size * scale).round
        dc.draw_line(x, py, x + width, py) if py < y + height
      end
    end
  end

  class MainFrame < Wx::Frame
    def initialize
      super(nil, title: APP_TITLE, size: Wx::Size.new(1360, 860))
      set_min_size(Wx::Size.new(900, 620))

      @source_image = nil
      @source_path = nil
      @unique_tiles = []
      @map_grid = []
      @tileset_image = nil
      @last_export_dir = nil

      build_menu
      build_interface
      create_status_bar(2)
      status_bar.set_status_widths([-1, 250])
      update_status('Готово. Загрузите карту PNG или JPEG.', 'Ожидание')
      centre
    end

    private

    def build_menu
      menu_bar = Wx::MenuBar.new
      file_menu = Wx::Menu.new
      file_menu.append(ID_OPEN, "Открыть карту...\tCtrl+O")
      file_menu.append(ID_PROCESS, "Разбить на тайлы\tCtrl+T")
      file_menu.append_separator
      file_menu.append(ID_EXPORT_ALL, "Экспортировать всё...\tCtrl+E")
      file_menu.append_separator
      file_menu.append(Wx::ID_EXIT, "Выход\tAlt+F4")
      menu_bar.append(file_menu, '&Файл')
      set_menu_bar(menu_bar)

      evt_menu(ID_OPEN) { open_image }
      evt_menu(ID_PROCESS) { process_map }
      evt_menu(ID_EXPORT_ALL) { export_all }
      evt_menu(Wx::ID_EXIT) { close }
    end

    def build_interface
      root_panel = Wx::Panel.new(self)
      root_sizer = Wx::BoxSizer.new(Wx::VERTICAL)

      # Header and controls
      header = Wx::Panel.new(root_panel)
      header_sizer = Wx::BoxSizer.new(Wx::VERTICAL)
      title = Wx::StaticText.new(header, label: 'MAP CREATOR')
      subtitle = Wx::StaticText.new(header, label: 'Конвертер карты в тайлсет и бинарную раскладку')
      header_sizer.add(title, 0, Wx::BOTTOM, 2)
      header_sizer.add(subtitle, 0, Wx::BOTTOM, 8)

      toolbar = Wx::BoxSizer.new(Wx::HORIZONTAL)
      @open_button = Wx::Button.new(header, ID_OPEN, '📂  Открыть карту')
      @process_button = Wx::Button.new(header, ID_PROCESS, 'Разбить на тайлы')
      @export_button = Wx::Button.new(header, ID_EXPORT_ALL, 'Экспортировать всё…')
      toolbar.add(@open_button, 0, Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 8)

      toolbar.add(Wx::StaticText.new(header, label: 'Размер тайла:'), 0, Wx::LEFT | Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 4)
      @tile_size_ctrl = Wx::SpinCtrl.new(header, ID_TILE_SIZE, DEFAULT_TILE_SIZE.to_s,
                                         Wx::DEFAULT_POSITION, Wx::Size.new(78, -1),
                                         Wx::SP_ARROW_KEYS, 8, 256, DEFAULT_TILE_SIZE)
      toolbar.add(@tile_size_ctrl, 0, Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 12)

      toolbar.add(Wx::StaticText.new(header, label: 'Колонки тайлсета:'), 0, Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 4)
      @columns_ctrl = Wx::SpinCtrl.new(header, ID_COLUMNS, DEFAULT_COLUMNS.to_s,
                                       Wx::DEFAULT_POSITION, Wx::Size.new(68, -1),
                                       Wx::SP_ARROW_KEYS, 1, 64, DEFAULT_COLUMNS)
      toolbar.add(@columns_ctrl, 0, Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 12)
      toolbar.add(@process_button, 0, Wx::RIGHT | Wx::ALIGN_CENTER_VERTICAL, 8)
      toolbar.add_stretch_spacer(1)
      toolbar.add(@export_button, 0, Wx::ALIGN_CENTER_VERTICAL)

      header_sizer.add(toolbar, 0, Wx::EXPAND)
      header.set_sizer(header_sizer)
      root_sizer.add(header, 0, Wx::EXPAND | Wx::ALL, 12)

      separator = Wx::StaticLine.new(root_panel)
      root_sizer.add(separator, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT, 12)

      # Two main preview panels
      workspace = Wx::BoxSizer.new(Wx::HORIZONTAL)
      source_panel = build_preview_group(root_panel, '1. Исходная карта', 'Сетка показывает границы тайлов размером в пикселях.')
      output_panel = build_preview_group(root_panel, '2. Сгенерированный тайлсет', 'Повторяющиеся тайлы объединяются; нумерация начинается с 1.')
      @source_preview = PreviewPanel.new(source_panel, show_grid: true, checkerboard: true)
      @tileset_preview = PreviewPanel.new(output_panel, show_grid: false, checkerboard: true)
      source_sizer = source_panel.sizer
      output_sizer = output_panel.sizer
      source_sizer.add(@source_preview, 1, Wx::EXPAND | Wx::ALL, 8)
      output_sizer.add(@tileset_preview, 1, Wx::EXPAND | Wx::ALL, 8)
      @source_stats = Wx::StaticText.new(source_panel, label: 'Изображение не загружено')
      @tileset_stats = Wx::StaticText.new(output_panel, label: 'Уникальных тайлов: 0')
      source_sizer.add(@source_stats, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 8)
      output_sizer.add(@tileset_stats, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 8)
      workspace.add(source_panel, 1, Wx::EXPAND | Wx::ALL, 7)
      workspace.add(output_panel, 1, Wx::EXPAND | Wx::ALL, 7)
      root_sizer.add(workspace, 1, Wx::EXPAND | Wx::ALL, 5)

      # Export actions
      export_row = Wx::BoxSizer.new(Wx::HORIZONTAL)
      @save_tileset_button = Wx::Button.new(root_panel, ID_SAVE_TILESET, 'Сохранить tileset.png')
      @save_binary_button = Wx::Button.new(root_panel, ID_SAVE_BINARY, 'Сохранить layout.bin')
      @save_text_button = Wx::Button.new(root_panel, ID_SAVE_TEXT, 'Сохранить map.txt')
      export_row.add(@save_tileset_button, 0, Wx::RIGHT, 8)
      export_row.add(@save_binary_button, 0, Wx::RIGHT, 8)
      export_row.add(@save_text_button, 0, Wx::RIGHT, 8)
      export_row.add_stretch_spacer(1)
      export_row.add(Wx::StaticText.new(root_panel, label: 'BIN: 16 бит · little-endian · ID тайла с 1'), 0, Wx::ALIGN_CENTER_VERTICAL)
      root_sizer.add(export_row, 0, Wx::EXPAND | Wx::LEFT | Wx::RIGHT | Wx::BOTTOM, 14)

      root_panel.set_sizer(root_sizer)

      @open_button.evt_button(ID_OPEN) { open_image }
      @process_button.evt_button(ID_PROCESS) { process_map }
      @export_button.evt_button(ID_EXPORT_ALL) { export_all }
      @save_tileset_button.evt_button(ID_SAVE_TILESET) { save_tileset_as }
      @save_binary_button.evt_button(ID_SAVE_BINARY) { save_binary_as }
      @save_text_button.evt_button(ID_SAVE_TEXT) { save_text_as }
      @tile_size_ctrl.evt_spinctrl(ID_TILE_SIZE) do
        @source_preview.tile_size = @tile_size_ctrl.value
        update_source_stats
        invalidate_results
        status_bar&.set_status_text('Размер изменён — нажмите «Разбить на тайлы» для пересборки.', 1)
      end
      @columns_ctrl.evt_spinctrl(ID_COLUMNS) do
        invalidate_results
        update_tileset_layout_hint
      end
      update_export_controls
    end

    def build_preview_group(parent, heading, description)
      panel = Wx::Panel.new(parent)
      sizer = Wx::BoxSizer.new(Wx::VERTICAL)
      title = Wx::StaticText.new(panel, label: heading)
      hint = Wx::StaticText.new(panel, label: description)
      sizer.add(title, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 8)
      sizer.add(hint, 0, Wx::LEFT | Wx::RIGHT | Wx::TOP, 8)
      panel.set_sizer(sizer)
      panel
    end

    def open_image
      dialog = Wx::FileDialog.new(
        self,
        'Выберите изображение карты',
        '',
        '',
        'Изображения PNG/JPEG (*.png;*.jpg;*.jpeg)|*.png;*.jpg;*.jpeg|Все файлы (*.*)|*.*',
        Wx::FD_OPEN | Wx::FD_FILE_MUST_EXIST
      )
      return unless dialog.show_modal == Wx::ID_OK

      path = dialog.path
      image = Wx::Image.new(path, Wx::BitmapType::BITMAP_TYPE_ANY)
      unless image.ok?
        Wx.message_box('Не удалось открыть изображение. Проверьте формат файла.', 'Ошибка загрузки', Wx::OK | Wx::ICON_ERROR, self)
        return
      end

      @source_image = image
      @source_path = path
      @unique_tiles = []
      @map_grid = []
      @tileset_image = nil
      @tileset_preview.set_image(nil)
      @tileset_stats.set_label('Сначала нажмите «Разбить на тайлы».')
      update_export_controls
      @source_preview.tile_size = @tile_size_ctrl.value
      @source_preview.set_image(@source_image)

      tile_size = @tile_size_ctrl.value
      cols = image.width / tile_size
      rows = image.height / tile_size
      remainder_x = image.width % tile_size
      remainder_y = image.height % tile_size
      remainder_text = if remainder_x.zero? && remainder_y.zero?
                         'без остатка'
                       else
                         "отбросится справа #{remainder_x}px, снизу #{remainder_y}px"
                       end
      @source_stats.set_label("#{File.basename(path)}  ·  #{image.width}×#{image.height}px  ·  сетка #{cols}×#{rows}  ·  #{remainder_text}")
      update_status("Карта загружена: #{image.width}×#{image.height}", 'Изображение готово')
    rescue StandardError => e
      show_error('Не удалось загрузить карту', e)
    end

    def process_map
      unless @source_image && @source_image.ok?
        Wx.message_box('Сначала загрузите изображение карты.', 'Нет карты', Wx::OK | Wx::ICON_INFORMATION, self)
        return
      end

      tile_size = @tile_size_ctrl.value
      max_columns = @columns_ctrl.value
      cols = @source_image.width / tile_size
      rows = @source_image.height / tile_size
      if cols < 1 || rows < 1
        Wx.message_box("Размер изображения меньше одного тайла #{tile_size}×#{tile_size}.", 'Недостаточный размер', Wx::OK | Wx::ICON_WARNING, self)
        return
      end

      update_status('Обработка карты…', 'Выполняется')
      @process_button.enable(false)
      @export_button.enable(false)
      @unique_tiles = []
      @map_grid = Array.new(rows) { Array.new(cols, 0) }
      @tileset_image = nil
      @tileset_preview.set_image(nil)
      update_export_controls
      seen = {}
      has_alpha = @source_image.has_alpha?
      can_read_alpha = @source_image.respond_to?(:get_alpha)

      rows.times do |row|
        cols.times do |col|
          tile = @source_image.get_sub_image(Wx::Rect.new(col * tile_size, row * tile_size, tile_size, tile_size))
          key = tile_key(tile, tile_size, has_alpha, can_read_alpha)
          unless seen.key?(key)
            if @unique_tiles.length >= 65_535
              raise 'Обнаружено больше 65 535 уникальных тайлов — формат layout.bin поддерживает ID только до 65 535.'
            end
            seen[key] = @unique_tiles.length
            @unique_tiles << tile
          end
          @map_grid[row][col] = seen[key] + 1
        end
      end

      build_tileset(tile_size, max_columns)
      @source_preview.tile_size = tile_size
      @tileset_preview.tile_size = tile_size
      @tileset_preview.set_image(@tileset_image)
      sheet_cols = [max_columns, @unique_tiles.length].min
      sheet_rows = (@unique_tiles.length.to_f / sheet_cols).ceil
      @tileset_stats.set_label("Уникальных тайлов: #{@unique_tiles.length}   ·   Тайлсет: #{sheet_cols}×#{sheet_rows}   ·   Карта: #{cols}×#{rows}")
      update_export_controls
      @source_stats.set_label("#{File.basename(@source_path)}  ·  #{@source_image.width}×#{@source_image.height}px  ·  #{cols}×#{rows} тайлов")
      update_status("Готово: #{@unique_tiles.length} уникальных тайлов", 'Обработка завершена')
    rescue StandardError => e
      show_error('Не удалось разбить карту на тайлы', e)
      update_status('Обработка завершилась ошибкой', 'Ошибка')
    ensure
      @process_button.enable(true) if @process_button
      update_export_controls if @save_tileset_button
    end

    def tile_key(tile, size, image_has_alpha, can_read_alpha)
      # wxRuby exposes pixel reads through Wx::Image. Packing all channel values
      # for one tile creates a deterministic binary key; transparency is included.
      bytes = []
      size.times do |y|
        size.times do |x|
          bytes << tile.get_red(x, y)
          bytes << tile.get_green(x, y)
          bytes << tile.get_blue(x, y)
          if image_has_alpha
            if can_read_alpha
              bytes << tile.get_alpha(x, y)
            else
              # Compatibility fallback for builds where GetAlpha isn't wrapped.
              bytes << (tile.is_transparent(x, y) ? 0 : 255)
            end
          end
        end
      end
      bytes.pack('C*')
    end

    def build_tileset(tile_size, max_columns)
      sheet_columns = [max_columns, @unique_tiles.length].min
      sheet_rows = (@unique_tiles.length.to_f / sheet_columns).ceil
      sheet = Wx::Image.new(sheet_columns * tile_size, sheet_rows * tile_size)
      sheet.init_alpha if @source_image.has_alpha?
      @unique_tiles.each_with_index do |tile, index|
        x = (index % sheet_columns) * tile_size
        y = (index / sheet_columns) * tile_size
        sheet.paste(tile, x, y, Wx::ImageAlphaBlendMode::IMAGE_ALPHA_BLEND_OVER)
      end
      @tileset_image = sheet
    end

    def export_all
      unless export_ready?
        Wx.message_box('Сначала загрузите карту и нажмите «Разбить на тайлы».', 'Нет данных для экспорта', Wx::OK | Wx::ICON_INFORMATION, self)
        return
      end

      default_dir = @last_export_dir || (@source_path ? File.dirname(@source_path) : Dir.pwd)
      dialog = Wx::DirDialog.new(self, 'Выберите папку для экспорта', default_dir, Wx::DD_DEFAULT_STYLE)
      return unless dialog.show_modal == Wx::ID_OK

      dir = dialog.path
      paths = write_all_files(dir)
      @last_export_dir = dir
      Wx.message_box("Экспорт завершён. Созданы файлы:\n\n#{paths.join("\n")}", 'Экспорт готов', Wx::OK | Wx::ICON_INFORMATION, self)
      update_status("Файлы сохранены в #{dir}", 'Экспорт готов')
    rescue StandardError => e
      show_error('Ошибка экспорта', e)
    end

    def write_all_files(dir)
      tile_path = File.join(dir, 'tileset.png')
      binary_path = File.join(dir, 'layout.bin')
      text_path = File.join(dir, 'map.txt')
      save_tileset(tile_path)
      File.binwrite(binary_path, @map_grid.flatten.pack('v*'))
      File.write(text_path, map_text, mode: 'w:UTF-8')
      [tile_path, binary_path, text_path]
    end

    def save_tileset(path)
      raise 'Тайлсет ещё не создан.' unless @tileset_image && @tileset_image.ok?
      ok = @tileset_image.save_file(path, Wx::BitmapType::BITMAP_TYPE_PNG)
      raise "wxWidgets не смог сохранить PNG: #{path}" unless ok
      path
    end

    def save_tileset_as
      return unless export_ready?
      dialog = Wx::FileDialog.new(self, 'Сохранить тайлсет', @last_export_dir || '', 'tileset.png',
                                  'PNG image (*.png)|*.png', Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT)
      return unless dialog.show_modal == Wx::ID_OK
      path = ensure_extension(dialog.path, '.png')
      save_tileset(path)
      @last_export_dir = File.dirname(path)
      update_status("Сохранено: #{path}", 'PNG сохранён')
    rescue StandardError => e
      show_error('Ошибка сохранения PNG', e)
    end

    def save_binary_as
      return unless export_ready?
      dialog = Wx::FileDialog.new(self, 'Сохранить бинарную карту', @last_export_dir || '', 'layout.bin',
                                  'Binary layout (*.bin)|*.bin', Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT)
      return unless dialog.show_modal == Wx::ID_OK
      path = ensure_extension(dialog.path, '.bin')
      File.binwrite(path, @map_grid.flatten.pack('v*'))
      @last_export_dir = File.dirname(path)
      update_status("Сохранено: #{path}", 'BIN сохранён')
    rescue StandardError => e
      show_error('Ошибка сохранения BIN', e)
    end

    def save_text_as
      return unless export_ready?
      dialog = Wx::FileDialog.new(self, 'Сохранить текстовую карту', @last_export_dir || '', 'map.txt',
                                  'Text map (*.txt)|*.txt', Wx::FD_SAVE | Wx::FD_OVERWRITE_PROMPT)
      return unless dialog.show_modal == Wx::ID_OK
      path = ensure_extension(dialog.path, '.txt')
      File.write(path, map_text, mode: 'w:UTF-8')
      @last_export_dir = File.dirname(path)
      update_status("Сохранено: #{path}", 'TXT сохранён')
    rescue StandardError => e
      show_error('Ошибка сохранения TXT', e)
    end

    def map_text
      @map_grid.map { |row| row.join(' ') }.join("\n") + "\n"
    end

    def ensure_extension(path, extension)
      path.downcase.end_with?(extension) ? path : path + extension
    end

    def export_ready?
      !!(@tileset_image && @tileset_image.ok? && !@map_grid.empty? && !@unique_tiles.empty?)
    end

    def invalidate_results
      @unique_tiles = []
      @map_grid = []
      @tileset_image = nil
      @tileset_preview.set_image(nil) if @tileset_preview
      @tileset_stats.set_label('Настройки изменены. Нажмите «Разбить на тайлы».') if @tileset_stats
      update_export_controls
    end

    def update_export_controls
      ready = export_ready?
      [@save_tileset_button, @save_binary_button, @save_text_button, @export_button].compact.each do |button|
        button.enable(ready)
      end
    end

    def update_source_stats
      return unless @source_image && @source_path
      tile_size = @tile_size_ctrl.value
      cols = @source_image.width / tile_size
      rows = @source_image.height / tile_size
      rx = @source_image.width % tile_size
      ry = @source_image.height % tile_size
      suffix = (rx.zero? && ry.zero?) ? 'без остатка' : "обрезка краёв: справа #{rx}px, снизу #{ry}px"
      @source_stats.set_label("#{File.basename(@source_path)}  ·  #{@source_image.width}×#{@source_image.height}px  ·  сетка #{cols}×#{rows}  ·  #{suffix}")
    end

    def update_tileset_layout_hint
      return unless @tileset_image && @tileset_image.ok?
      # The actual layout is rebuilt when processing is run again.
      status_bar&.set_status_text("Колонки тайлсета: #{@columns_ctrl.value} (нажмите «Разбить на тайлы» для пересборки)", 1)
    end

    def update_status(message, state)
      status_bar&.set_status_text(message, 0)
      status_bar&.set_status_text(state, 1)
    end

    def show_error(title, error)
      Wx.message_box("#{error.class}: #{error.message}", title, Wx::OK | Wx::ICON_ERROR, self)
    end
  end
end

Wx::App.run do
  MapCreator::MainFrame.new.show
end
