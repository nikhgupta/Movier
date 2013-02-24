module Movier

  # Organize a given folder of movies
  #
  # * *Args*    :
  #   - +path+ -> path to the folder with movies that need to be organized
  #
  def self.organize(path, options = {})
    # path where files that need to be organized are.
    path = path.first
    path = Dir.pwd if not path or path.empty?
    path = File.expand_path(path)

    # select files that are larger than 100 MB and not yet, organized.
    movies = Dir.glob("#{path}/**/*")
    movies = movies.select{ |f| File.size(f) >= 100*2**20 }
    movies = movies.reject{ |f| organized?(f) }

    # if we can't find such files, let the user know so.
    # otherwise, display how many files, we have found
    if movies.count > 0
      tip_now("Found approx. #{movies.count} movies")

      # ask user where the organized files will be put up?
      tip_now "Movies will be saved as: <organized>/<Language>/<rating>+/<movie_name> [<year>]"
      options[:dir] = ask_for_directory("Where should I put the organized files? ")

      # organize movies one by one
      movies.each { |movie_path| organize_movie movie_path, options }

      # show that we are done
      passed_with("All movies were organized!")
    else
      passed_with("All movies have already been organized.")
    end
  end

  private

  # Organize a single movie, given a path
  #
  # * *Args*    :
  #   - +movie_path+ -> path of the movie that will be organized
  #
  def self.organize_movie(movie_path, options)
    movie_path = File.expand_path(movie_path)
    # let the user know which movie we are parsing..
    tip_now movie_path, "Checking.."

    # pick a target movie from IMDB.com based on the file path
    movie = pick_movie movie_path, options[:guess]

    # if we were unable to find the movie, or it was ignored, move ahead
    return unless movie

    # let the user know, which target was selected
    imdb  = movie[:imdb]
    selected  = "#{imdb["Title"]} [#{imdb["Year"]}"
    selected += " at #{imdb["imdbRating"]} points with #{imdb["imdbVotes"]} votes"
    say_rated "Selected", selected, imdb["imdbRating"]

    # since, we can't find movie's language, ask user for it.
    lang = options[:lang] || ask("What language this movie is in? ") {|x| x.default = "en" }

    # rearrange/reorganize the movie
    set_language_and_rearrange(movie, options[:dir], lang)
  end

  # pick a target movie from IMDB.com based on the movie's file path
  #
  # * *Args*    :
  #   - +movie+ -> path to the movie
  # * *Returns* :
  #   - hash of information about the selected movie target
  #
  def self.pick_movie(movie_path, guess = true)
    # pick -> our selected target from IMDB.com
    pick = false

    # get whatever information we can get from movie's path
    movie = sanitize_and_get_information_from movie_path

    # search for movies with this information
    search = search_movie(movie[:name], movie[:year])

    # get information from IMDB.com for each movie found
    search.map!{ |mov| fetch_details mov["imdbID"] }
    # sort our movies
    search.sort_by {|m| m["weight"] }

    # can we make an intelligent guess ?
    guessable = guess &&
                search.count > 1 && (
                search[1]["votes"]  < 5000   &&
                search[0]["votes"]  > 100000 ) || (
                search[0]['votes']  > 10000  &&
                search[0]["weight"] > 40 * search[1]["weight"] )

    # pick if only one movie was found, or if search is guessable
    pick = search[0] if search.count == 1 || guessable

    # let the user pick a movie otherwise from given options
    unless pick
      tip_now "Please, choose the correct movie title below:"
      choose do |menu|
        # let the user pick from found movie titles
        search.each do |m|
          m["details"]  = "#{m["Title"]} [#{m["Year"]}] at "
          m["details"] += "#{m["imdbRating"]} points "
          m["details"] += "with #{m["imdbVotes"]} votes.\n\t"
          m["details"] += "Plot: #{m["Plot"]}\n\t"
          m["details"] += "Actors: #{m["Actors"]}\n"
          menu.choice(m["details"]) { pick = m }
        end
        # let the user provide an IMDB ID
        menu.choice("[ Use IMDB ID ]") do
          id = ask("IMDB.com ID for the given title? ")
          pick = fetch_details id
        end
        menu.choice("[ Use another keyword ]") do
          keyword = ask("Keyword to search with? ")
          pick_movie keyword
        end
        # let the user ignore this movie for organizing purposes
        menu.choice("[ Ignore ]") { return false }
      end
    end

    # return our pick or false for skipping this movie
    movie[:imdb] = pick
    pick ? movie : false
  end

  # Search a movie given some keywords, and optionally, an year.
  # Loop until we have a target movie from IMDB.com.
  # If need arises, ask user to provide us some keywords or an IMDB.com ID.
  #
  # * *Args*    :
  #   - +keyword+ -> keywords for the search
  #   - +year+ -> (optional) year of this movie
  #   - +ask_user+ -> if true, asks a user for movie name/id
  # * *Returns* :
  #   - hash of search results
  #
  def self.search_movie(keyword, year = nil, ask_user = false)
    search = []; counter = 1
    until search.any?
      # on first search, it will search with keyword being passed
      # on second search, will search with initial two words in the keyword
      # on third search and onwards, will ask user for keywords/id
      tip_now "Using keywords: #{keyword}", "Searching.." if counter > 1
      begin; search = search(keyword, year, "movie"); rescue; end
      begin; search = search(keyword, nil, "Movie") if year and not search.any?; rescue; end

      if counter == 1
        keyword = keyword.split
        keyword = keyword.count == 1 ? keyword[0] : "#{keyword[0]} #{keyword[1]}"
      elsif not search.any?
        keyword = ask("Please, provide keywords/IMDB ID to search with: ")
        return [{ "imdbID" => keyword }] if keyword =~ /tt\d{7}/
      end

      counter += 1;
    end
    search
  end

  # Set language for a movie, and then rearrange/reorganize it on the disk
  #
  # * *Args*    :
  #   - +movie+ -> hash of information about this movie
  #   - +path+ -> directory where the organized movies will be kept
  #   - +lang+ -> language of this movie
  #
  def self.set_language_and_rearrange(movie, org_path, lang = "en")
    # get the language for this movie
    lang = case lang.downcase
           when "en", "eng", "english" then "English"
           when "hi", "hindi" then "Hindi"
           when "fr", "french" then "French"
           else lang.titlecase
           end

    # set the directory path for this movie
    # directory structure is:
    #   <org_path>/<language>/<rating>+/<movie name> [<year>]/
    # e.g. for the Top Gun movie:
    #   /Volumes/JukeBox/Movies/English/6+/Top Gun [1986]/
    imdb = movie[:imdb]
    nice_name = "#{imdb["Title"]} (#{imdb["Year"]})".gsub(/(\\|\/|\:)/, ' - ')
    movie_path = File.join(org_path, lang, "#{imdb["imdbRating"]}+", nice_name)
    FileUtils.mkdir_p movie_path

    Dir.chdir(movie_path) do
      # move the movie to this folder
      # TODO: skip copying the file if this movie already exists
      FileUtils.mv movie[:path], nice_name + File.extname(movie[:path])
      # create imdb.txt file inside this folder
      File.open("imdb.txt", "w") {|f| f.puts movie.to_yaml}
      # download the movie posted to this folder
      `wget #{imdb["Poster"]} -qO poster#{File.extname(imdb["Poster"])}` unless
        imdb["Poster"] == "N/A"
    end
  end

  # Sanitize whatever information we got from movie's path
  #
  # * *Args*    :
  #   - +path+ -> path to the movie
  # * *Returns* :
  #   - hash of sanitized information about the movie
  #
  def self.sanitize_and_get_information_from(path)
    movie = capture_movie(path)
    movie[:name] = movie[:name].gsub(/(BR|DVD|[a-z]*)Rip/i, "")
    movie[:name] = movie[:name].gsub(/divx/i, "")
    movie[:name] = movie[:name].gsub(/[._-]/, " ").strip
    movie[:parent] = File.basename(File.dirname(path))
    movie[:path] = path
    movie
  end

  # Capture information about the movie from its path
  #
  # * *Args*    :
  #   - +path+ -> path of this movie
  # * *Returns* :
  #   - hash of information about the movie
  #
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
    return {type: 0, name: movie }
  end
end
