require 'csv'
require 'fileutils'
require 'json'
require 'terminal-table'
require 'text-table'

require_relative 'modules'

# Auxiliary methods

def time
  Time.now.strftime("%Y%m%d%H%M%S") # %N for nanoseconds
end

def short_time
  Time.now.strftime("%Y%m%d")
end

def format_time
  Time.now.strftime("[%Y-%m-%d %H:%M:%S] ")
end

def filename
  CONFIG['json'].remove(".json").concat(".json")
end

def backup_filename
  filename.remove(".json").concat("_%s.json" % [time])
end

def autobackup_filename
  filename.remove(".json").concat("_%s.json" % [short_time])
end

def message(type, text)
  format_time + type.upcase + ": " + text + "\n"
end

# File manipulation methods

def backup(auto = false)
  begin
    old = (auto ? autobackup_filename : backup_filename)
    if File.file?(filename) then FileUtils.cp(filename, old) end
  rescue
    log("ERROR", "Realizando la copia de seguridad de la base de datos.")
  ensure
    return old
  end
end

def autobackup
  backup(true) if CONFIG['autobackup'] && !File.file?(autobackup_filename)
rescue
  log("ERROR", "Realizando la copia de seguridad automática.")
else
  log("INFO", "Copia de seguridad automática realizada.")
end

def save
  backup_name = backup
  begin
    File.delete(filename) if File.file?(filename)
    File.open(filename, "w") do |f|
      f.write($movies.to_json)
    end
  rescue
    File.delete(filename) if File.file?(filename)
    File.rename(backup_name, filename) if File.file?(backup_name)
    log("ERROR", "Guardando la base de datos.")
  else
    File.delete(backup_name) if File.file?(backup_name)
  end
end

def access
  File.file?(filename) ? $movies = JSON.parse(File.read(filename), :symbolize_names => true) : $movies = JSON.parse("[]")
rescue
  log("ERROR", "Cargando la base de datos.")
else
  log("INFO", "Base de datos cargada, hay %i películas." % [$movies.size])
end

def emdb(emdb_filename = "emdb.dat")
  backup_name = backup
  $films = File.file?(emdb_filename) ? File.binread(emdb_filename).scan(/./).delete_if{ |s| s == "\x00" }.join.split("\x0D\x1D\x0D") : []
  if $films.blank?
    log("ERROR", "Cargando la base de datos desde EMBD, el fichero no existe.")
  else
    $names = $films.last
    $names = $names.split("]")[1..-2].map{ |s| s.split("[")[0].split("\r").delete_if{ |r| r.blank? } }
    $names = {actors: $names[0], directors: $names[1], writers: $names[2], composers: $names[3]}
    $films = $films[1..-2].map{ |s| s.split("\x1E") }
    $films = $films[0..39].map{ |s|
      {
        title: s[0].to_s,
        original_title: s[1].to_s,
        companies: s[2].to_s.split(","),
        year: s[4].split("\r")[1].to_i,
        directors: $names[:directors][s[5].to_i].to_s.split(","),
        duration: s[6].to_i,
        countries: s[7].to_s.split(","),
        vista: s[13].to_i % 2 == 1 ? true : false,
        deseada: s[13].to_i % 4 == 2 ? true : false,
        propia: s[13].to_i % 8 == 4 ? true : false,
        favorita: s[13].to_i % 16 == 8 ? true : false,
        color: [s[15].to_s],
        emdb_id: s[18].to_s,
        writers: $names[:writers][s[19].to_i].to_s.split(","),
        genres: s[20].split("\r")[1].scan(/./).map{ |g|
          case g
          when "A" then "Action"
          when "C" then "Animation"
          when "D" then "Drama"
          when "F" then "Fantasy"
          when "f" then "Film-Noir"
          when "G" then "History"
          when "g" then "Game-Show"
          when "H" then "Horror"
          when "I" then "Family"
          when "K" then "Comedy"
          when "M" then "Music"
          when "m" then "Musical"
          when "N" then "News"
          when "O" then "War"
          when "P" then "Sport"
          when "R" then "Romance"
          when "r" then "Reality-TV"
          when "S" then "Sci-Fi"
          when "s" then "Short"
          when "T" then "Thriller"
          when "t" then "Talk-Show"
          when "U" then "Documentary"
          when "V" then "Adventures"
          when "W" then "Western"
          when "X" then "Adult"
          when "Y" then "Mistery"
          when "!" then "Crime"
          when "@" then "Biography"
          else "Other"
          end
        },
        imdb_id: s[21].to_s,
        date_added: s[22][0..3].to_s + "-" + s[22][4..5].to_s + "-" + s[22][6..7].to_s,
        certification: s[23].to_s.to_sym,
        trailer_url: s[27].to_s,
        date_viewed: s[28].to_s.split("\r")[0],
        filmaffinity_synopsis: s[32].split("\r")[1].to_s,
        imdb_votes: s[39].to_i
      }
    }
    $films.each{ |f|
      matches = $movies.each_with_index.select{ |s, i| s[:id][:imdb] == f[:imdb_id] }
      if matches.count == 0
        search(f[:title], "filmaffinity", output: false)
        id = $search[0..-2].select{ |s| s[2] == f[:year].to_s }
        if !id.blank? && !id[0].blank? && !id[0][0].blank?
          id = id[0][0].to_s
          matches = $movies.each_with_index.select{ |s, i| s[:id][:filmaffinity] == id }
          if matches.count == 0
            add_movie(idImdb: f[:imdb_id], idFilmAffinity: id, dual: true)
            $movies.last[:dates][:added] = f[:date_added] # TODO: poner la funcion "modify" cuando este hecha (en vez de acceder a $movies directamente)
            if f[:vista] then $movies.last[:dates][:viewed] << f[:date_viewed][0..3] + "-" + f[:date_viewed][4..5] + "-" + f[:date_viewed][6..7] end
          else
            log("INFO", "EMDB - La película %s ya está en la base de datos (Índices %s)" % [matches[0][0][:title], matches.map{ |s, i| i }.join(", ")])
          end
        else
          log("ERROR", "EMDB - Problema cargando película %s índice %i" % [f[:title], f[:emdb_id]])
        end
      else
        log("INFO", "EMDB - La película %s ya está en la base de datos (Índices %s)" % [matches[0][0][:title], matches.map{ |s, i| i }.join(", ")])
      end
    }
  end
rescue
  log("ERROR", "Cargando la base de datos desde EMDB.")
else
  File.delete(backup_name) if File.file?(backup_name)
  save
  log("INFO", "Base de datos de EMDB cargada, hay %i películas." % [$films.size])
end

def log(type, text, output = true)
  print(message(type, text)) if output
  if CONFIG['autolog'] || CONFIG['autolog'] == nil
    begin
      File.file?("log.txt") ? FileUtils.cp("log.txt", "log_backup.txt") : new_log = true
      File.open("log.txt", "a") do |f|
        f.write(message("info", "Creado nuevo fichero de log de PFDB, versión v1.0.\n\n")) if new_log
        f.write(message(type, text))
      end
    rescue
      if File.file?("log.txt") && File.file?("log_backup.txt")
        File.delete("log.txt")
        File.rename("log_backup.txt", "log.txt")
      end
      print(message("error", "Actualizando el log."))
    else
      File.delete("log_backup.txt") if File.file?("log_backup.txt")
    end
  end
end

# TODO: Completar añadiendo mas formatos, quiza añadir separaciones no printables para mayor seguridad, quiza añadir mas estilos (tipo tabla, ascii art, etc)
# NOTA: La sinopsis entre 3 dobles comillas, como hay comas separamos con puntos y comas
def export(preset: :normal, output: :csv, style: :text)
  preset = preset.to_sym
  output = output.to_sym
  result = []
  case preset
  when :minimal
    header = ["IMDb ID", "FilmAffinity ID"]
    result = $movies.map{ |s| [s[:id][:imdb], s[:id][:filmaffinity]] }
  when :simple
    header = ["IMDb ID", "FilmAffinity ID", "Title", "Year", "Duration", "Directors", "Dates viewed"]
    result = $movies.map{ |s|
      [
        s[:id][:imdb].to_s,
        s[:id][:filmaffinity].to_s,
        s[:title].to_s,
        s[:year].to_s,
        s[:duration].to_s,
        s[:directors].join(","),
        s[:dates][:viewed].join(",")
      ]
    }
  when :normal
    header = ["IMDb ID", "FilmAffinity ID", "Title", "Original title", "Year", "Duration", "Genres", "Countries", "Directors", "Cast", "Synopsis", "Dates viewed"]
    result = $movies.map{ |s|
      [
        s[:id][:imdb].to_s,
        s[:id][:filmaffinity].to_s,
        s[:title].to_s,
        s[:original_title].to_s,
        s[:year].to_s,
        s[:duration].to_s,
        s[:genres].join(","),
        s[:countries].join(","),
        s[:directors].join(","),
        s[:cast].map{ |k, v| k }.join(","),
        s[:synopsis][:filmaffinity].to_s.remove("\n", "*"),
        s[:dates][:viewed].join(",")
      ]
    }
  when :complete
    header = ["IMDb ID", "FilmAffinity ID", "Title", "Original title", "Year", "Duration", "Genres", "Countries", "Directors", "Cast", "Synopsis", "Dates viewed"]
    result = $movies.map{ |s|
      [
        s[:id][:imdb].to_s,
        s[:id][:filmaffinity].to_s,
        s[:title].to_s,
        s[:original_title].to_s,
        s[:year].to_s,
        s[:duration].to_s,
        s[:genres].join(","),
        s[:countries].join(","),
        s[:directors].join(","),
        s[:cast].map{ |k, v| k }.join(","),
        s[:synopsis][:filmaffinity].to_s.remove("\n", "*"),
        s[:dates][:viewed].join(",")
      ]
    }
  else
    log("ERROR", "Exportando la base de datos. El preset debe ser 'minimal', 'simple', 'normal' o 'complete'.")
    return
  end
  result.insert(0,header)

  case output
  when :csv
    result = result.map{ |s| s.join("*") }.join("\n")
    File.open(filename.remove(".json") + "_export_" + time + ".csv", "w") do |f|
      f.write(result)
    end
  when :txt
    result = result.map{ |s| s.join("\n") }.join("\n\n")
    File.open(filename.remove(".json") + "_export_" + time + ".txt", "w") do |f|
      f.write(result)
    end
  else
    log("ERROR", "Exportando la base de datos. El formato debe ser 'csv' o 'txt'.")
  end
end

# TODO: Implementar esta funcion
def import

end

# Methods for manipulating the database

def modify(index, field, value)
  bool = index < $movies.size && $movies[index].key?(field) # TODO: Comprobar también que el tipo/clase de value es correcto.
  bool ? $movies[index][field] = value : raise("La película o el campo introducido no existe.")
rescue
  log("ERROR", "Modificando el campo \"%s\" de la película \"%s\"." % [field, $movies[index][:title]])
end

def add_movie(id: "0068646", web: :imdb, dual: false, idImdb: "0068646", idFilmAffinity: "809297")
  if web.is_a?(String) then web = web.to_sym end
  movie = !dual ? Movie.new(id: id, web: web) : Movie.new(idImdb: idImdb, idFilmAffinity: idFilmAffinity, dual: true)
  $movies << movie.to_hash if !movie.nil?
  save if CONFIG['autosave']
  log("info", "Añadida película \"%s\" (ID %s en %s) a la base de datos." % [movie.to_hash[:title], id, web.to_s])
rescue
  log("ERROR", "Añadiendo película a la base de datos.")
end

def delete_by_index(index, indexb = nil)
  if index.is_a?(Integer) && index > -1 && index < $movies.size
    if indexb == nil
      name = $movies[index][:title]
      $movies.delete_at(index)
      log("INFO", "Eliminada película %s de la base de datos." % [name])
    else
      if indexb.is_a?(Integer) && indexb > -1 && indexb < $movies.size
        if index <= indexb
          (1..(indexb-index+1)).each{ |s| $movies.delete_at(index) }
          log("INFO", "Eliminadas películas %s a %s de la base de datos." % [index.to_s, indexb.to_s])
        else
          (1..(index-indexb+1)).each{ |s| $movies.delete_at(indexb) }
          log("INFO", "Eliminadas películas %s a %s de la base de datos." % [indexb.to_s, index.to_s])
        end
      else
        print("La película introducida no existe.")
      end
    end
  else
    print("La película introducida no existe.")
  end
end

def delete_by_title(title)
  index = $movies.find_index{ |m| m[:title].downcase == title.downcase }
  !index.nil? ? delete_by_index(index) : print("Película no encontrada en la base de datos.")
end

def delete(thing, thing2 = nil)
  thing.is_a?(Integer) ? delete_by_index(thing, thing2) : (thing.is_a?(String) ? delete_by_title(thing) : raise)
  save if CONFIG['autosave']
rescue
  log("ERROR", "Eliminando película de la base de datos.")
end

def modify_movie(index, field, value)
  modify(index, field, value)
  save if CONFIG['autosave']
  log("INFO", "Modificada película %s de la base de datos. Actualizado campo %s a valor %s" % [$movies[index][:title], field.to_s, value.to_s])
end

def search_from_web(query, web = :imdb, output = true)
  search = []
  case web
  when :imdb
    search = Imdb::Search.new(query)
  when :filmaffinity
    search = FilmAffinity::Search.new(query)
  else
    print("ERROR: Web incorrecta.")
    return
  end
  $search = search.result + [web]
  $searches[web] = search.result
  search.show_result if output
rescue
  log("ERROR", "Realizando una búsqueda en la web %s." % [web.to_s.capitalize])
end

def search_from_database(query, order: nil, reverse: false, web: :imdb)
  movie = $movies.each_with_index.select{ |m, i| m[:title] =~ /#{query}/i }
  !movie.blank? ? (movie.count > 1 ? list(set: movie, order: order, reverse: reverse, web: web) : view_movie(movie[0][0])) : print("No se encontró ningún resultado.")
rescue
  log("ERROR", "Realizando una búsqueda en la base de datos.")
end

def search_dual(query, output = true) # TODO: Añadir comprobacion de ID's para evitar repetidos, tener en cuenta que quiero poder usarlo de forma desatendida (no lanzar una excepcion, solo un mensaje)
  $searches[:imdb] = Imdb::Search.new(query).result
  $searches[:filmaffinity] = FilmAffinity::Search.new(query).result
  rows = []
  rows << [{value: "IMDb", colspan: 3, alignment: :center}, {value: "FilmAffinity", colspan: 3, alignment: :center}]
  rows << :separator
  rows << ["ID", "Título", "Año"] + ["ID", "Título", "Año"]
  rows << :separator
  (0..(CONFIG['search_limit'].to_i - 1)).each{ |s|
    if !$searches[:imdb][s].nil? || !$searches[:filmaffinity][s].nil?
      imdb = !$searches[:imdb][s].nil? ? [s.to_s, $searches[:imdb][s][1].truncate(50), $searches[:imdb][s][2]] : ["", "", ""]
      fa = !$searches[:filmaffinity][s].nil? ? [s.to_s, $searches[:filmaffinity][s][1].truncate(50), $searches[:filmaffinity][s][2]] : ["", "", ""]
      rows << imdb + fa
    end
  }
  table = Terminal::Table.new(title: "Resultado de la búsqueda \"#{query}\".", rows: rows)
  print(table)
  print("\n")
rescue
  log("ERROR", "Realizando una búsqueda dual en internet.")
end

def search(query, web = nil, order: nil, reverse: false, output: true)
  !web.nil? ? (!!web[/dual/i] ? search_dual(query, output) : search_from_web(query, web.to_sym, output)) : search_from_database(query, order: order, reverse: reverse, web: web)
end

def add_single(index)
  if $search.blank?
    print("ERROR: Aún no has hecho ninguna búsqueda.")
  else
    if index.is_a?(Integer) && index > -1 && index < $search.size - 1 # careful, the last element is the web
      id = $search[index][0]
      web = $search.last
      !$movies.map{ |s| s[:id][web.to_sym] }.include?(id) ? add_movie(id: id, web: web) : print("Esta película ya está en la lista.")
    else
      print("ERROR: ID incorrecta.")
    end
  end
end

def add_dual(index1, index2) # TODO: Proporcionar opcion configurable para decidir que hacer en caso de que la peli ya este en la base de datos (ignorar, sustituir, etc)
  if $searches[:imdb].blank? || $searches[:filmaffinity].blank?
    print("ERROR: Aún no has hecho ninguna búsqueda.")
  else
    if index1.is_a?(Integer) && index1 > -1 && index1 < $searches[:imdb].size && index2.is_a?(Integer) && index2 > -1 && index2 < $searches[:filmaffinity].size
      idImdb = $searches[:imdb][index1][0]
      idFilmAffinity = $searches[:filmaffinity][index2][0]
      name = $searches[:imdb][index1][1]
      imdbMatches = $movies.each_with_index.select{ |s, i| s[:id][:imdb] == idImdb }
      filmaffinityMatches = $movies.each_with_index.select{ |s, i| s[:id][:filmaffinity] == idFilmAffinity }
      matches = imdbMatches + filmaffinityMatches
      if matches.count == 0
        add_movie(idImdb: idImdb, idFilmAffinity: idFilmAffinity, dual: true)
      else
        log("INFO", "La película %s ya está en la lista (Índices %s)." % [name, matches.map{ |s, i| i }.uniq.join(", ")])
      end
    else
      print("ERROR: Alguna ID es incorrecta.")
    end
  end
end

def add(index1, index2 = nil)
  index2.nil? ? add_single(index1) : add_dual(index1, index2)
end

def clean
  $movies.delete_if{ |m| m[:title].blank? && m[:year] == 0 && m[:duration] == 0 && m[:cast].blank? && m[:genres].blank? }
  $movies = $movies.select{ |m| m[:id][:imdb].to_s.blank? } + $movies.select{|m| !m[:id][:imdb].to_s.blank? }.uniq{ |m| m[:id][:imdb].to_s }
  $movies = $movies.select{ |m| m[:id][:filmaffinity].to_s.blank? } + $movies.select{|m| !m[:id][:filmaffinity].to_s.blank? }.uniq{ |m| m[:id][:filmaffinity].to_s }
  save if CONFIG['autosave']
  log("INFO", "Base de datos limpiada de entradas vacías y duplicados.")
end

def autoclean
  clean if CONFIG['autoclean']
end

# TODO: Complete this
def rate

end

# Methods for viewing the database

def multirow(text: "", cols: 1, length: 10)
  text.scan(/.{1,#{length}}/).map{ |t| [{colspan: cols, value: t}] }
end

def delimitate(num)
  num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
end

# TODO: añadir prevencion de blanks a todos, los dos ultimos no funcionan, añadir el resto de atributos
def order_list(list: nil, order: nil, reverse: false, web: :imdb)
  if order.is_a?(String) then order = order.to_sym end
  case order
  when :title, :original_title, :duration, :year, :budget, :gross
    list.sort!{ |a, b| !a[0][order].blank? && !b[0][order].blank? ? a[0][order] <=> b[0][order] : !a[0][order].blank? ? -1 : 1 }
  when :countries, :genres, :directors, :writers, :producers, :composers, :cinematographers, :editors, :castings, :languages, :color
    list.sort!{ |a, b| a[0][order].join <=> b[0][order].join }
  when :id, :rating, :votes, :ranking
    list.sort!{ |a, b| a[0][order][web] <=> b[0][order][web] }
  else
    print("ERROR: Clave introducida incorrecta.")
  end
  reverse ? list.reverse : list
end

def list(show: CONFIG['list_limit'].to_i, set: nil, order: nil, reverse: false, web: :imdb)
  if order.is_a?(String) then order = order.to_sym end
  header = ["Id", "Año", "Título", "Dur", "Director/es", "País/es", "Vista"]
  films = (set.nil? ? $movies.each_with_index.take(show) : set.take(show))
  films = !order.nil? ? order_list(list: films, order: order, reverse: reverse, web: web) : films
  table = films.map{ |m, i|
           [i.to_s,
            m[:year].truncate(4),
            m[:title].truncate(30),
            m[:duration].truncate(3),
            m[:directors].join(", ").truncate(30),
            m[:countries].join(", ").truncate(30),
            m[:dates][:viewed].last == "" ? "No" : m[:dates][:viewed].last
           ]
          }.insert(0, header)
  sep = CONFIG['list_separation'].to_i + 1
  while sep < table.count - 1
    table.insert(sep, :separator)
    sep += CONFIG['list_separation'].to_i + 1
  end
  print(table.to_table(:first_row_is_head => true).align_column(1, :right).align_column(4, :right))
rescue
  log("ERROR", "Listando las películas de la base de datos.")
end

def order(show: CONFIG['list_limit'].to_i, set: nil, order: nil, reverse: false, web: :imdb)
  list(show: show, set: set, order: order, reverse: reverse, web: web)
end

def sort(show: CONFIG['list_limit'].to_i, set: nil, order: nil, reverse: false, web: :imdb)
  list(show: show, set: set, order: order, reverse: reverse, web: web)
end

def view_movie(movie)
  width = [CONFIG['movie_card_width'].to_i, 0].max
  field_width = [((width - 1) / 5) - 3, 0].max
  field_length = [width - field_width - 7, 0].max
  limit = [CONFIG['movie_card_field_length_limit'].to_i, 0].max
  rows = []
  rating = !movie[:id][:imdb].blank? ? movie[:rating][:imdb].to_s : movie[:rating][:filmaffinity].to_s
  votes = !movie[:id][:imdb].blank? ? movie[:votes][:imdb].to_s : movie[:votes][:filmaffinity].to_s
  rows << [(movie[:year].to_s).truncate(field_width),
                (movie[:duration].to_s + " minutos").truncate(field_width),
                (rating.to_s + " (" + votes.to_s + " votos)").truncate(field_width),
                movie[:genres].join(", ").truncate(field_width),
                movie[:countries].join(", ").truncate(field_width)]
  rows << :separator
  rows << [movie[:color][0].to_s.truncate(field_width),
                movie[:languages].join(", ").truncate(field_width),
                movie[:companies][0].to_s.truncate(field_width),
                (delimitate(movie[:budget]) + "$").truncate(field_width),
                (delimitate(movie[:gross]) + "$").truncate(field_width)]
  rows << :separator
  if !movie[:directors].blank? then rows << ["Dirección"] + [{colspan: 4, value: movie[:directors].join(", ").truncate(field_length)}] end
  if !movie[:writers].blank? then rows << ["Guión"] + [{colspan: 4, value: movie[:writers].join(", ").truncate(field_length)}] end
  if !movie[:producers].blank? then rows << ["Producción"] + [{colspan: 4, value: movie[:producers].join(", ").truncate(field_length)}] end
  if !movie[:cinematographers].blank? then rows << ["Cinematografía"] + [{colspan: 4, value: movie[:cinematographers].join(", ").truncate(field_length)}] end
  if !movie[:composers].blank? then rows << ["Música"] + [{colspan: 4, value: movie[:composers].join(", ").truncate(field_length)}] end
  if !movie[:editors].blank? then rows << ["Edición"] + [{colspan: 4, value: movie[:editors].join(", ").truncate(field_length)}] end
  rows << :separator
  text = movie[:cast].map{ |k, v| k.to_s + (!v.blank? ? " (" + v.to_s + ")" : "") }.take(CONFIG['cast_list'].to_i).join(", ").truncate(limit)
  multirow(text: text, cols: 4, length: field_length).each_with_index{ |r, i|
    if i == 0 then rows << ["Cast"] + r
    else rows << [""] + r end
  }
  rows << :separator
  text = !movie[:id][:imdb].blank? ? movie[:synopsis][:imdb] : movie[:synopsis][:filmaffinity]
  if !text.blank?
    multirow(text: text.truncate(limit), cols: 4, length: field_length).each_with_index{ |r, i|
      if i == 0 then rows << ["Sinopsis"] + r
      else rows << [""] + r end
    }
  end
  table = Terminal::Table.new(title: movie[:title].truncate(40).upcase + " (" + movie[:original_title].truncate(40).upcase + ")", rows: rows)
  print(table)
  print("\n")
end

def view(movie, order: nil, reverse: false, web: :imdb)
  case movie.class.to_s
  when "Integer"
    if movie > -1 && movie < $movies.count
      view_movie($movies[movie])
    else
      print("ERROR: ID incorrecta.")
    end
  when "String"
    result = $movies.each_with_index.select{ |m, i| m[:title] =~ /#{movie}/i }
    !result.blank? ? (result.count > 1 ? list(set: result, order: order, reverse: reverse, web: web) : view_movie(result[0][0])) : print("No se encontró ningún resultado.")
  else
    print("ERROR: Debes introducir un entero (índice de la película) o una cadena de texto (título de la película).")
  end
rescue
  log("ERROR", "Visualizando películas de la base de datos.")
end

def filter(mode: :intersection, order: nil, reverse: false, web: :imdb, **fields) # TODO: do extensive testing, finish it, add remaining fields, maybe more modes and flexibility
  if mode.is_a?(String) then mode = mode.to_sym end
  bool = false
  case mode
  when :intersection
    result = $movies.each_with_index
    fields.each{ |k, v|
      if [:title, :original_title].include?(k)
        result = result.select{ |m, i| m[k] =~ /#{v}/i }
        bool = true
      elsif [:countries, :genres, :directors, :writers, :producers, :composers, :cinematographers, :editors, :castings, :companies, :languages, :color].include?(k)
        result = result.select{ |m, i| m[k].join("|") =~ /#{v}/i }
        bool = true
      elsif [:year, :duration, :budget, :gross].include?(k)
        result = result.select{ |m, i| m[k] >= v[0] && m[k] <= v[1] }
        bool = true
      else
        print("ERROR: La clave %s no existe.\n" % [k])
      end
    }
    (!result.blank? && bool == true) ? (result.count > 1 ? list(set: result, order: order, reverse: reverse, web: web) : view_movie(result[0][0])) : print("No se encontró ningún resultado.")
  when :union
    result = []
    fields.each{ |k, v|
      if [:title, :original_title].include?(k)
        result = result | $movies.each_with_index.select{ |m, i| m[k] =~ /#{v}/i }
      elsif [:countries, :genres, :directors, :writers, :producers, :composers, :cinematographers, :editors, :castings, :companies, :languages, :color].include?(k)
        result = result | $movies.each_with_index.select{ |m, i| m[k].join("|") =~ /#{v}/i }
      elsif [:year, :duration, :budget, :gross].include?(k)
        result = result | $movies.each_with_index.select{ |m, i| m[k] >= v[0] && m[k] <= v[1] }
      else
        print("ERROR: La clave %s no existe." % [k])
      end
    }
    !result.blank? ? (result.count > 1 ? list(set: result, order: order, reverse: reverse, web: web) : view_movie(result[0][0])) : print("No se encontró ningún resultado.")
  else
    print("ERROR: El modo %s no es válido. Los modos válidos son \"intersection\" y \"union\"." % [mode])
  end
rescue
  log("ERROR", "Filtrando la base de datos.")
end

def awards_movie(movie)
  table = Text::Table.new
  titulo = movie[:title].truncate(40).upcase + " ("
  titulo << [movie[:original_title].truncate(40), movie[:year], movie[:directors].join(", ").truncate(40)].reject{ |s| s.blank? }.join(", ") + ")"
  table.rows << [{align: :center, colspan: 2, value: titulo}]
  movie[:prizes].select{ |k, v| !v.blank? }.each{ |prize, prizes|
    table.rows << :separator
    table.rows << [{colspan: 2, value: prize.to_s.titlecase.upcase, align: :center}]
    table.rows << :separator
    prizes.each{ |outcome, list|
      table.rows << [{colspan: 2, align: :center, value: outcome.to_s.capitalize + " (" + list.count.to_s + ")"}]
      list.each{ |award, winner|
        table.rows << [award.to_s.truncate(60), winner.to_s.truncate(40)]
      }
    }
  }
  print(table)
end

def awards(movie)
  if movie.is_a?(Integer)
    if movie > -1 && movie < $movies.count
      awards_movie($movies[movie])
    else
      print("ERROR: ID incorrecta.")
    end
  else
    if movie.is_a?(String)
      movie = $movies.each_with_index.select{ |m, i| m[:title] =~ /#{movie}/i }
      !movie.blank? ? (movie.count > 1 ? list(set: movie) : awards_movie(movie[0])) : print("No se encontró ningún resultado.")
    else
      raise
    end
  end
rescue
  log("ERROR", "Buscando premios de una película en la base de datos.")
end

# TODO: Reelaborar todo esto del comment.
def add_comment(index, *reasons) # TODO: Terminar y testear este metodo, añadir mas razones
  movie = $movies[index]
  reasons.each{ |reason|
    if reason.is_a?(String)
      case reason
      when reason =~ /premi/i || reason =~ /oscar/i then movie[:personal_comment] << :premiada
      when reason =~ /relevancia/i || reason =~ /hist.ri/i || reason =~ /cultura/i then movie[:personal_comment] << :relevante
      when reason =~ /personal/i then movie[:personal_comment] << :personal
      else movie[:personal_comment] << reason end
    else
      print("ERROR: Cada razón debe ser una cadena de texto.")
    end
  }
end

def comment(index) # TODO: Elaborar este metodo

end

def startup
  log("", "----------------------------------------------------------", false)
  print("\n")
  print(format_time + "x============================x===========================x\n")
  print(format_time + "|                       PFDB v1.0                        |\n")
  print(format_time + "x============================x===========================x\n")
  log("INFO", "Programa ejecutado.")
  access
  autobackup
  autoclean
  print(format_time + "x============================x===========================x\n")
end

$movies = []
$search = []
$searches = {}
$names = []
$films = []
startup
