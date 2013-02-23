module Movier

  # pick a movie using IMDB.com and its file name on disk
  def self.pick_movie(movie)
    pick = false
    movie = sanitize(movie)

    search = search_movie(movie[:name], movie[:year])
    search.each_with_index do |m, i|
      search[i] = info(m["imdbID"])
      search[i]["imdbVotes"] = search[i]["imdbVotes"].delete(",").to_i
      search[i]["imdbRating"] = search[i]["imdbRating"].to_f
      search[i]["imdbWeight"] = search[i]["imdbVotes"] * search[i]["imdbRating"]
    end

    # sort our movies
    search.sort_by {|m| m["imdbWeight"] }

    # make an intelligent guess
    if search.count > 1
      guessable = search[1]["imdbVotes"] < 5000 && search[0]["imdbVotes"] > 100000
      guessable ||= search[0]["imdbWeight"] > 40 * search[1]["imdbWeight"]
    end
    pick = search[0] if search.count == 1 || guessable

    # if we only have one movie, use it
    unless pick
      Movier.show_info "Please, choose the correct movie title below:"
      choose do |menu|
        search.each do |m|
          # next if m["imdbVotes"] < 500
          menu.choice("#{m["Title"]} [#{m["Year"]}] | " +
                      "Rated: #{m["imdbRating"]} with #{m["imdbVotes"]} votes" +
                      "\n\tPlot: #{m["Plot"]}\n\tActors: #{m["Actors"]}") do
            pick = m
          end
        end
        menu.choice("[Use IMDB ID]") do
          id = ask("IMDB.com ID for the given title? ")
          pick = info(id)
        end
        menu.choice("[Ignore]") { return false }
      end
    end
    movie[:imdb] = pick
    pick ? movie : false
  end

  # organize the movie
  def self.organize(path, options = [])
    path  = path.first
    path  = Dir.pwd if not path or path.empty?
    path += '/' if path[-1] != '/'

    movies = Dir.glob("#{path}**/*")
    movies = movies.select{ |f| File.size(f) >= 100*2**20 }

    Movier.say_success "Nothing to do." if movies.empty?

    movies.each_with_index do |movie, index|
      next if File.exists?(File.join(File.dirname(movie), "imdb.txt"))
      Movier.say_with_status "Organizing..", movie, :information
      movie = pick_movie movie
      next unless movie
      Movier.say_rated "Found",
        "#{movie[:imdb]["Title"]} [#{movie[:imdb]["Year"]}] with rating: #{movie[:imdb]['imdbRating']}",
      movie[:imdb]["imdbRating"]
      lang = options[:lang] || ask("What language this movie is in? ") {|res| res.default = "english" }
      set_language_and_rearrange(movie, options[:dir], lang)
    end
  end

  def self.set_language_and_rearrange(movie, path, lang = "english")
    lang = case lang.downcase
           when "en", "eng", "english" then "English"
           when "hi", "hindi" then "Hindi"
           when "fr", "french" then "French"
           else lang.titlecase
           end

    nice_name = (movie[:imdb]["Title"] + " [" + movie[:imdb]["Year"] + "]").gsub(/(\\|\/|\:)/, ' - ')
    movie_path = File.join(path, lang, movie[:imdb]["imdbRating"].to_i.to_s + "+", nice_name)

    # TODO: skip copying the file if this movie already exists
    FileUtils.mkdir_p movie_path
    Dir.chdir(movie_path) do
      FileUtils.mv movie[:path], nice_name + File.extname(movie[:path])
      File.open("imdb.txt", "w") {|f| f.puts movie.to_yaml}
      `wget #{movie[:imdb]["Poster"]} -qO poster#{File.extname(movie[:imdb]["Poster"])}`
    end
  end

  def self.sanitize(path)
    movie = capture_movie(path)
    movie[:name] = movie[:name].gsub(".", " ").strip
    movie[:parent] = File.basename(File.dirname(path))
    movie[:path] = path
    movie
  end

  def self.capture_movie(path)
    movie = File.basename(path, File.extname(path))

    # try for: movie name [year] something.something
    regex = /(.*)\[(\d{4})\].*/
    match = movie.match regex
    return {type: 1, name: match[1], year: match[2]} if match

    # try for: movie name (year) something.something
    regex = /(.*)\((\d{4})\).*/
    match = movie.match regex
    return {type: 2, name: match[1], year: match[2]} if match

    # try for: movie name year something.something
    regex = /(.*)(\d{4}).*/
    match = movie.match regex
    return {type: 3, name: match[1], year: match[2]} if match

    # go generic
    movie = movie.gsub(/(BR|DVD)Rip/i, "")
    return {type: 0, name: movie }
  end

  def self.can_handle?(path)
    can_handle = false
    regexes = [/.*\[\d{4}\].*/, /.*\(\d{4}\).*/, /.*\d{4}.*/]
    movie = File.basename(path)
    regexes.each do |re|
      if movie =~ re
        can_handle = true
        name = ask("Name of this movie? ") {|x| x.default = movie }
        puts name.inspect
        break
      end
    end
    can_handle
  end

  def self.rating(keyword, options)
    movies = search_movie(keyword, options[:year])
    movies.each do |m|
      m = self.info m["imdbID"]
      next if m["imdbVotes"].delete(",").to_i < 1000
      Movier.say_with_status("Movie", m["Title"] + " [" + m["Year"] + "]", :information)
      Movier.say_rated("Rating", m["imdbRating"], m["imdbRating"])
      if options[:detailed]
        Movier.say_rated("Plot", m["Plot"], m["imdbRating"])
        Movier.say_rated("Actors", m["Actors"], m["imdbRating"])
        Movier.say_rated("Runtime", m["Runtime"], m["imdbRating"])
        Movier.say_rated("Genre", m["Genre"], m["imdbRating"])
      end
      puts
    end
  end

  def self.search_movie(keyword, year = nil, ask_user = false)
    begin
      search = search(keyword, year, "Movie")
      search = search(keyword, nil, "Movie") if search.empty?
      raise "Movie not found!" if search.empty?
    rescue RuntimeError => e
      if e.message == "Movie not found!"
        if not ask_user
          keyword = keyword.split
          keyword = keyword.count == 1 ? keyword[0] : keyword[0] + " " + keyword[1]
          Movier.show_info "Searching with keywords: #{keyword}"
          begin
            search = search(keyword, nil, "Movie")
            raise "Movie not found!" if search.empty?
          rescue RuntimeError => e
            ask_user = true if e.message == "Movie not found!"
          end
        end

        if ask_user
          keyword = ask("Please, provide keywords to search with: ")
          search = search_movie(keyword, nil, true)
        end
      end
    end
    search
  end

  def self.search(keyword, year = nil, type = "Movie")
    response = omdbapi({ s: keyword })["Search"]
    response = response.select{ |m| m["Type"].downcase == type.downcase } unless type.downcase == "all"
    response = response.select{ |m| m["Year"] == year } if year
    response
  end

  def self.info(id)
    omdbapi({ i: id })
  end

  def self.omdbapi(params)
    query = ""
    params.each { |k, v| query += "#{k}=#{v}" }
    response = HTTParty.get("http://omdbapi.com/?#{URI::encode(query)}")
    Movier.show_error response.response unless response.success?
    response = JSON.parse(response.parsed_response)
    Movier.show_error response["Error"] if response["Error"]
    response
  end
end
