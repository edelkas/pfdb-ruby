require 'cgi'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'rails'
require 'terminal-table'
require 'text-table'
require 'yaml'

CONFIG_ENV = 'production'
CONFIG = YAML.load_file('config.yml')[CONFIG_ENV]

module FilmAffinity
  def self.lang
    CONFIG['language'].downcase
  end

  QUERY = {
    genre: 'genre=%s&',
    country: 'country=%s&',
    from_year: 'fromyear=%i&',
    to_year: 'toyear=%i&',
    no_doc: 'nodoc&',
    no_tv: 'notvse&'
  }

  URLS = {
    top: "https://www.filmaffinity.com/#{lang}/topgen.php%s",
    search: "https://www.filmaffinity.com/#{lang}/search.php?stext=%s&stype=title",
    movie: "https://www.filmaffinity.com/#{lang}/film%s.html",
    relations: "https://www.filmaffinity.com/#{lang}/movie-relations.php?movie-id=%s"
  }

  TAGS = {
    EN: {
      title: '#main-title span',
      original_title: 'dt:contains("Original title")',
      year: 'dd[itemprop="datePublished"]',
      duration: 'dd[itemprop="duration"]',
      countries: '#country-img',
      directors: 'a[itemprop="url"]',
      composers: 'dt:contains("Music")',
      companies: 'dt:contains("Producer")',
      writers: 'dt:contains("Screenwriter")',
      cinematographers: 'dt:contains("Cinematography")',
      cast: 'span[itemprop="actor"]',
      cast_each: 'span[itemprop="name"]',
      genres: 'dt:contains("Genre")',
      synopsis: 'dd[itemprop="description"]',
      rating: 'div[itemprop="ratingValue"]',
      votes: 'span[itemprop="ratingCount"]',
      poster: 'img[itemprop="image"]',
      poster_big: 'a[class="lightbox"]',
      relations: 'a[title="Related Movies"]',
      relations_type: 'div[class="rel-type"]',
      relations_each: 'div[class="movie-card movie-card-0"]',
      search: 'div[class="movie-card movie-card-1"]'
    },
    ES: {
      title: '#main-title span',
      original_title: 'dt:contains("Título original")',
      year: 'dd[itemprop="datePublished"]',
      duration: 'dd[itemprop="duration"]',
      countries: '#country-img',
      directors: 'dd[class="directors"]',
      composers: 'dt:contains("Música")',
      companies: 'dt:contains("Productora")',
      writers: 'dt:contains("Guion")',
      cinematographers: 'dt:contains("Fotografía")',
      cast: 'span[itemprop="actor"]',
      cast_each: 'span[itemprop="name"]',
      genres: 'dt:contains("Género")',
      synopsis: 'dd[itemprop="description"]',
      rating: 'div[itemprop="ratingValue"]',
      votes: 'span[itemprop="ratingCount"]',
      poster: 'img[itemprop="image"]',
      poster_big: 'a[class="lightbox"]',
      relations: 'a[title="Relaciones"]',
      relations_type: 'div[class="rel-type"]',
      relations_each: 'div[class="movie-card movie-card-0"]',
      search: 'div[class="movie-card movie-card-1"]'
    }
  }

  RELS = {
    EN: {
      remake_of: 'Remake of',
      remakes: 'Remake',
      sequel_of: 'Sequel of',
      sequel: 'Sequel',
      prequel_of: 'Prequel of',
      prequel: 'Prequel',
      spinoff_of: 'Spin-off of',
      spinoff: 'Spin-off',
      doc_of: 'Documentary about',
      doc: 'Related Documentary',
      related_with: 'Related to',
      related: 'Related to'
    },
    ES: {
      remake_of: 'Es remake de',
      remakes: 'tiene remake',
      sequel_of: 'es secuela de',
      sequel: 'tiene secuela',
      prequel_of: 'es precuela de',
      prequel: 'tiene precuela',
      spinoff_of: 'Es spin-off de',
      spinoff: 'tiene spin-off',
      doc_of: 'Documental de',
      doc: 'documental asociado',
      related_with: 'Relacionada con',
      related: 'está relacionada con'
    }
  }

  def tag(type)
    TAGS[CONFIG['language'].to_sym][type]
  end

  def rel(type)
    RELS[CONFIG['language'].to_sym][type]
  end

  class Movie
    include FilmAffinity

    def initialize(id, title = nil)
      @attrs = {}
      @attrs[:filmaffinity_id] = id
      @doc = Nokogiri::HTML(open(URLS[:movie] % @attrs[:filmaffinity_id]))
      @attrs[:title] = @doc.at(tag(:title)).content.strip rescue ""
      @attrs[:original_title] = @doc.at(tag(:original_title)).next_element.content.to_s.squish rescue ""
      @attrs[:year] = @doc.at(tag(:year)).content[/\d+/].to_i rescue 0
      @attrs[:duration] = @doc.at(tag(:duration)).content[/\d+/].to_i rescue 0
      @attrs[:countries] = [@doc.at(tag(:countries)).next_sibling.content.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, '')] rescue []
      @attrs[:directors] = @doc.at(tag(:directors)).children
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:composers] = @doc.at(tag(:composers)).next_element.children[0].children
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:companies] = @doc.at(tag(:companies)).next_element.children[0].children
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:writers] = @doc.at(tag(:writers)).next_element.children[0].children
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:cinematographers] = @doc.at(tag(:cinematographers)).next_element.children[0].children
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:cast] = @doc.search(tag(:cast)).map{ |a| a.at(tag(:cast_each)).content.to_s.squish }
        .take(CONFIG['cast_amount'].to_i) rescue []
      @attrs[:genres] = @doc.at(tag(:genres)).next_element.search('a')
        .map{ |s| s.content.to_s.squish.remove(",") }.reject{ |s| s.blank? } rescue []
      @attrs[:filmaffinity_synopsis] = @doc.at(tag(:synopsis)).content.squish.remove("(FILMAFFINITY)") rescue ""
      @attrs[:filmaffinity_rating] = @doc.at(tag(:rating)).content.to_s.strip.tr(',', '.').to_f  rescue 0.0
      @attrs[:filmaffinity_votes] = @doc.at(tag(:votes)).content.to_s.squish.remove('.', ',').to_i rescue 0
      @attrs[:relations] = (!!@doc.at(tag(:relations)) ? parse_relations : {}) rescue {}
    end

    def parse_relations
      source = Nokogiri::HTML(open(URLS[:relations] % @attrs[:filmaffinity_id]))
      relations = source.search(tag(:relations_type)).map{ |s| [s.content.to_s.squish.remove(":"),
        s.parent.search(tag(:relations_each)).map{ |r| r['data-movie-id'][/\d+/].to_i }] }.to_h
      relations.map{ |k, v| [RELS[CONFIG['language'].to_sym].invert[k], v] }.to_h
    end

    def to_hash
      @attrs
    end

    def to_json
      self.to_hash.to_json
    end
  end

  class Search
    include FilmAffinity

    def initialize(query)
      @query = query
      @movies = []
      @doc = Nokogiri::HTML(open(URLS[:search] % CGI.escape(@query)))
      if !@doc.at('.z-movie').nil?
        id = @doc.at('meta[property="og:url"]')['content'][/film\d+/][/\d+/]
        title = @doc.at(tag(:title)).content.strip
        year = @doc.at(tag(:year)).content.to_s[/\d+/]
        @movies = [[id, title, year]]
      else
        @movies = @doc.search('div[class="se-it mt "]').map{ |s|
          [s.at('div[class="movie-card movie-card-1"]')['data-movie-id'][/\d+/],
          s.at('a')['title'].to_s.squish,
          s.at('div[class="ye-w"]').content.to_s[/\d+/]]
        }
      end
    end

    def result
      @movies
    end

    def show_result
      rows = []
      rows << ["ID", "Título", "Año"]
      rows << :separator
      @movies.each_with_index{ |s, i| rows << [i.to_s, @movies[i][1].truncate(80), @movies[i][2]] }
      table = Terminal::Table.new(title: "Resultado de la búsqueda \"#{@query}\" en FilmAffinity.", rows: rows)
      print(table)
    end
  end
end

module Imdb
  URLS = {
    top: "https://www.imdb.com/chart/top",
    search: "http://www.imdb.com/find?q=%s&s=tt&ttype=ft",
    advanced_search: "https://www.imdb.com/search/title?title=%s&view=simple&count=%s",
    movie: "http://www.imdb.com/title/tt%s/reference",
    prizes: "https://www.imdb.com/title/tt%s/awards"
  }

  TAGS = {
    title: 'meta[name="title"]',
    year: 'a[itemprop="url"]',
    cast: 'table[class="cast_list"]',
    header: 'h4[class="ipl-header__content ipl-list-title"]',
    directors: 'h4[name="directors"]',
    writers: 'h4[name="writers"]',
    producers: 'h4[name="producers"]',
    composers: 'h4[name="composers"]',
    cinematographers: 'h4[name="cinematographers"]',
    editors: 'h4[name="editors"]',
    castings: 'h4[name="casting_directors"]',
    overview: 'section[class="titlereference-section-overview"]',
    additional: 'section[class="titlereference-section-additional-details"]',
    storyline: 'section[class="titlereference-section-storyline"]',
    box_office: 'section[class="titlereference-section-box-office"]',
    imdb_rating: 'span[class="ipl-rating-star__rating"]',
    imdb_votes: 'span[class="ipl-rating-star__total-votes"]',
    imdb_ranking: 'a[href="/chart/top"]',
    bottom_ranking: 'a[href="/chart/bottom"]'
  }

  def tag(type)
    TAGS[type]
  end

  class Movie
    include Imdb
    def initialize(id, title = nil)

      @attrs = {}
      @attrs[:imdb_id] = id
      @doc = Nokogiri::HTML(open(URLS[:movie] % @attrs[:imdb_id]))

      # read and parse Imdbs main reference tables as hashes
      additional_details = parse_imdb_table(:additional, false) rescue {}
      storyline = parse_imdb_table(:storyline, false) rescue {}
      box_office = parse_imdb_table(:box_office, true) rescue {}
      credits = @doc.search(tag(:header)).map{ |s| [s.content.to_s.squish, s] }.to_h

      # overview information

      title = @doc.at(tag(:title))['content'].to_s.remove(" - IMDb")
      @attrs[:title] = /\(\d{4}\)/.match?(title[-7..-1]) ? title[0..-7].squish : title rescue ""
      @attrs[:original_title] = @doc.at(tag(:title)).next.content.to_s.squish rescue ""
      @attrs[:year] = @doc.at(tag(:year)).content[/\d+/].to_i rescue 0
      @attrs[:imdb_rating] = @doc.at(tag(:imdb_rating)).content.to_s.squish.tr(",", ".").to_f rescue 0.0
      @attrs[:imdb_votes] = @doc.at(tag(:imdb_votes)).content.to_s.squish.scan(/\d+/).join.to_i rescue 0
      @attrs[:imdb_ranking] = @doc.at(tag(:imdb_ranking)).content[/\d+/].to_i rescue 0
      #@imdb_attrs[:bottom_ranking'] = @doc.at(:bottom_ranking).content[/\d+/].to_i rescue 0
      @attrs[:imdb_synopsis] = @doc.at(tag(:overview)).children[1].content.to_s.remove("See more »").squish rescue ""

      # cast
      @attrs[:cast] = parse_cast rescue {}

      # subsequent sections (h4 header sections)
      #oldold
      #@director = @doc.at(tag(:overview)).children[5].children[1].content.to_s.squish[/(\w|\s|,)+/].to_s.remove(" See more ").split(", ") rescue []
      #@script = @doc.at(tag(:overview)).children[7].children[1].content.to_s.squish[/(\w|\s|,)+/].to_s.remove(" See more ").split(", ")
      #old
      #@directors = parse_imdb_header(:directors) rescue []
      #@writers = parse_imdb_header(:writers) rescue []
      #new
      @attrs[:directors] = parse_imdb_header(credits['Directed by']) rescue []
      @attrs[:writers] = parse_imdb_header(credits['Written by']) rescue []
      @attrs[:producers] = parse_imdb_header(credits['Produced by']) rescue []
      @attrs[:composers] = parse_imdb_header(credits['Music by']) rescue []
      @attrs[:cinematographers] = parse_imdb_header(credits['Cinematography by']) rescue []
      @attrs[:editors] = parse_imdb_header(credits['Film Editing by']) rescue []
      @attrs[:castings] = parse_imdb_header(credits['Casting By']) rescue []
      @attrs[:companies] = parse_imdb_header_simple(credits['Production Companies']) rescue []

      # final tables
      @attrs[:genres] = storyline['Genres'] rescue []
      @attrs[:duration] = additional_details['Runtime'][0][/\d+/].to_i rescue 0
      @attrs[:countries] = additional_details['Country'] rescue []
      @attrs[:color] = additional_details['Color'] rescue ""
      @attrs[:languages] = additional_details['Language'] rescue []
      @attrs[:budget] = box_office['Budget'] rescue 0
      @attrs[:gross] = box_office['Cumulative Worldwide Gross'] rescue 0

      @attrs[:prizes] = {}
      parse_prizes
    end

    def parse_cast
      @doc.at(tag(:cast)).children.map{ |s|
        names = s.content.to_s.remove("(uncredited)").remove("Rest of cast listed alphabetically:").squish.split(" ... ")
        names.map!{ |r| r.squish }
        case names.count
        when 1
          names.concat([""])
        when 2
          names
        else
          ""
        end
      }.delete_if{ |s| s.empty? }.take(CONFIG['cast_amount'].to_i).to_h
    end

    def parse_imdb_table(sym, box)
      @doc.at(tag(sym)).children[3].children
        .map{ |s|
          if !s.children.empty?
            name = s.children[1].content.to_s.squish
            values = (box ? s.children[3].content[/(\d|,|\.)+/].scan(/\d/).join.to_i : s.children[3].children[1].children
              .map{ |c| c.content.to_s.squish }.delete_if{ |c| c.empty? || !!c[/See more/] })
          else
            name = ""
            values = []
          end
          [name, values]
        }
        .delete_if{ |s| s[0].empty? }.to_h
    end

    def parse_imdb_header(node)
      node.parent.parent.next.next.children[1].children.map{ |s| s.content.to_s.split("...")[0].squish }.delete_if{ |s| s.empty? }.uniq
    end

    def parse_imdb_header_simple(node)
      node.parent.parent.next.next.search('a').map{ |s| s.content.to_s.squish }.uniq
    end

    def parse_prizes
      source = Nokogiri::HTML(open(URLS[:prizes] % @attrs[:imdb_id]))
      prizes = source.search('table[class="awards"]').map{ |s|
        prize = s.previous_element.content.to_s.squish
        types = []
        amounts = []
        s.search('td[class="title_award_outcome"]').each{ |outcome|
          types << outcome.at('b').content.to_s.squish
          amounts << outcome['rowspan'][/\d+/].to_i
        }
        amounts = amounts.each_with_index.map{ |e, i| i == 0 ? 0...amounts[0] :amounts[0..i-1].sum...amounts[0..i].sum }
        dual = [types, amounts].transpose.to_h
        awards = s.search('td[class="award_description"]').map{ |award|
          name = !award.children[0].nil? ? award.children[0].content.to_s.squish : ""
          recipient = !award.at('a').nil? ? award.at('a').content.to_s.squish : ""
          [name, recipient]
        }
        award_hash = dual.map{ |k, v| [k, awards[v].to_h] }.to_h
        [prize, award_hash]
      }.to_h
      oscars = prizes.find{ |k, v| k =~ /Academy Awards/i }
      golden = prizes.find{ |k, v| k =~ /Golden Globes/i }
      baftas = prizes.find{ |k, v| k =~ /BAFTA/i }
      goyas = prizes.find{ |k, v| k =~ /Goya/i }
      grammys = prizes.find{ |k, v| k =~ /Grammy/i }
      sags = prizes.find{ |k, v| k =~ /Screen Actors Guild/i }
      cannes = prizes.find{ |k, v| k =~ /Cannes/i } # palme d'or
      berlin = prizes.find{ |k, v| k =~ /Berlin/i } # golder bear
      venice = prizes.find{ |k, v| k =~ /Venice/i } # golden lion
      guild = prizes.find{ |k, v| k =~ /Writers Guild of America/i }
      @attrs[:prizes][:oscars] = (!oscars.nil? ? oscars[1] : {})
      @attrs[:prizes][:golden_globes] = (!golden.nil? ? golden[1] : {})
      @attrs[:prizes][:baftas] = (!baftas.nil? ? baftas[1] : {})
      @attrs[:prizes][:goyas] = (!goyas.nil? ? goyas[1] : {})
      @attrs[:prizes][:grammys] = (!grammys.nil? ? grammys[1] : {})
      @attrs[:prizes][:writers_guild] = (!guild.nil? ? guild[1] : {})
    end

    def to_hash
      @attrs
    end

    def to_json
      self.to_hash.to_json
    end
  end

  class Search # TODO: Use advanced search instead, as it sorts by relevance
    include Imdb

    def initialize(query)
      @query = query
      @doc = Nokogiri::HTML(open(URLS[:search] % CGI.escape(@query)))
      if !@doc.at("table[@id='title-overview-widget']").nil? # this might be wrong
        id = @doc.at('meta[property="og:url"]')['content'][/tt\d+/][/\d+/]
        title = @doc.at('meta[name="title"]')['content'].remove("- IMDb").squish
        @movies = [[id, title]]
      else
        @movies = @doc.at('table[class="findList"]').search('td[class="result_text"]').map{ |n|
          [n.at('a')['href'][/tt\d+/][/\d+/],
          n.at('a').content.to_s.squish,
          n.xpath('text()').map{ |s| s.content.to_s.squish }.join[/\((\d+)\)/,1]]
        }.take(CONFIG['search_limit'].to_i)
      end
    end

    def result
      @movies
    end

    def show_result
      rows = []
      rows << ["ID", "Título", "Año"]
      rows << :separator
      @movies.each_with_index{ |s, i| rows << [i.to_s, @movies[i][1].truncate(80), @movies[i][2]] }
      table = Terminal::Table.new(title: "Resultado de la búsqueda \"#{@query}\" en IMDb.", rows: rows)
      print(table)
    end
  end
end

class Movie

  def initialize(id: "0068646", web: :imdb, dual: false, idImdb: "0068646", idFilmAffinity: "809297")
    @attrs = initializeHash
    !dual ? download_from_web(id, web) : download_from_webs(idImdb, idFilmAffinity)
    if @attrs[:original_title].nil? then @attrs[:original_title] = @attrs[:title] end
  end

  def initializeHash
    {
      id: { imdb: "",
            filmaffinity: "" },
      title: "",
      original_title: "",
      duration: 0,
      year: 0,
      countries: [],
      genres: [],
      cast: {},
      synopsis: { imdb: "",
                  filmaffinity: "" },
      directors: [],
      writers: [],
      producers: [],
      composers: [],
      cinematographers: [],
      editors: [],
      castings: [],
      companies: [],
      languages: [],
      color: [],
      budget: 0,
      gross: 0,
      relations: {},
      prizes: { oscars: {},
                golden_globes: {},
                baftas: {},
                goyas: {},
                grammys: {},
                writers_guild: {} },
      rating: { imdb: 0.0,
                filmaffinity: 0.0 },
      votes: { imdb: 0,
               filmaffinity: 0 },
      ranking: { imdb: 0,
                 filmaffinity: 0 },
      dates: { added: Time.now.strftime("%Y-%m-%d"),
               updated: Time.now.strftime("%Y-%m-%d"),
               viewed: [] },
      personal_comment: "",
      personal_rating: 0.0
    }
  end

  def download_from_web(id, web)
    case web
    when :imdb
      hash = Imdb::Movie.new(id).to_hash
    when :filmaffinity
      hash = FilmAffinity::Movie.new(id).to_hash
    else
      hash = {}
    end
    hash.each{ |k, v|
      if @attrs.key?(k) then @attrs[k] = v else
        key = k.to_s.split("_")[1..-1].join("_").to_sym
        website = k.to_s.split("_")[0].to_sym
        if @attrs.key?(key) then @attrs[key][website] = v end
      end
    }
  end

  def download_from_webs(idImdb, idFilmAffinity)
    hashImdb = Imdb::Movie.new(idImdb).to_hash
    hashFilmAffinity = FilmAffinity::Movie.new(idFilmAffinity).to_hash
    @attrs.each{ |k, v|
      if hashImdb.key?(("imdb_" + k.to_s).to_sym) then v[:imdb] = hashImdb[("imdb_" + k.to_s).to_sym] end
      if hashFilmAffinity.key?(("filmaffinity_" + k.to_s).to_sym) then v[:filmaffinity] = hashFilmAffinity[("filmaffinity_" + k.to_s).to_sym] end
    }
    @attrs = @attrs.map{ |k, v|
      if hashImdb.key?(k) then [k, hashImdb[k]]
      elsif hashFilmAffinity.key?(k) then [k, hashFilmAffinity[k]]
      else [k, v] end
    }.to_h
  end

  def to_hash
    @attrs
  end

end
