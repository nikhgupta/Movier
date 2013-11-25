module Movier
  class LMDB
    DataFolder = File.join(ENV['HOME'], ".movier")
    DataFile = File.join(DataFolder, "data.yaml")

    attr_reader :movies, :boxes

    def initialize
      FileUtils.mkdir_p DataFolder
      FileUtils.touch DataFile unless File.exists?(DataFile)
      read_data
    end

    def read_data
      data    = Movier.read_yaml(DataFile)
      @boxes  = data ? data[:boxes]  : []
      @movies = data ? data[:movies] : []
    end

    def write_data(movies = nil, boxes = nil)
      boxes ||= @boxes; movies ||= @movies;
      data = { boxes: boxes, movies: movies }
      Movier.write_yaml DataFile, data
      read_data
    end

    def find_persons(kind = :actors)
      invalid_kind = @movies.first && !@movies.first.has_key?(kind.to_sym)
      raise "I don't have any info about #{Movier.titleize(kind.to_s)}" if invalid_kind
      persons = @params[kind.to_sym]
      if persons
        persons.split(",").each do |person|
          @movies.select!{ |movie| movie[kind.to_sym].join(", ").downcase.include? person.downcase.strip}
        end
      end
    end

    def genre
      genre = [ "Action", "Adventure", "Animation", "Biography", "Comedy",
                "Crime", "Documentary", "Drama", "Family", "Fantasy",
                "Film-Noir", "Game-Show", "History", "Horror", "Music",
                "Musical", "Mystery", "News", "Reality-TV", "Romance",
                "Sci-Fi", "Sport", "Talk-Show", "Thriller", "War", "Western" ]
      Movier.tip_now "Listing all IMDB.com defined genre"
      puts " " * 20 + "=" * 20
      genre.each_slice(6) do |g|
        puts " "*20 + g.join(", ")
      end

    end

    def lookup(id)
      @movies.each do |movie|
        return movie if movie[:id] == id
      end
      false
    end

    def find(params)
      # TODO: add support for "find in a box" and "exclude boxes"
      read_data; @params = params; @params[:verbose] = true if @params[:shuffle]
      raise "Please, add some movie boxes, before searching in the local movie database" unless @movies.any?

      @movies.select!{|movie| movie[:title].downcase.include? @params[:keywords].downcase} if @params[:keywords]
      [:directors, :writers, :actors, :genre, :tags].each { |kind| find_persons(kind) }
      @movies.select!{|movie| movie[:rated] == @params[:rated] } if @params[:rated]
      @movies.select!{|movie| movie[:rating] >= @params[:points].to_f } if @params[:points]

      # filter on tag exclusion
      tags = @params[:exclude_tags]
      if tags
        tags.split(",").each do |tag|
          @movies.reject!{ |movie| movie[:tags].join(", ").downcase.include? tag.downcase.strip}
        end
      end
      @movies.reject!{|movie| movie[:tags].join(", ").downcase.include? "watched"} unless @params[:tags] &&
        @params[:tags].include?("watched")

      sort_movies
      @movies = @movies.slice(0, @params[:limit].to_i) if @params[:limit].to_i > 0
      @movies = [ @movies.shuffle.first ] if @params[:shuffle]

      counter = 1
      @movies.each do |movie|
        nice_name = "#{movie[:title]} [#{movie[:year]}]"
        if @params[:verbose]
          Movier.tip_now "%03d" % counter + ") " + nice_name, Movier.titleize(movie[:type])
          Movier.tip_now movie[:path], "Path"
          rating = "#{movie[:rated]} at #{movie[:rating]} points."
          Movier.say_rated "Rating", rating, movie[:rating]
          Movier.say_rated "Votes", "#{movie[:votes]} IMDB.com votes", movie[:rating]
          Movier.say_rated "Genre", movie[:genre].join(", "), movie[:rating], true
          Movier.say_rated "Runtime", movie[:runtime], movie[:rating]
          Movier.say_rated "Directors", movie[:directors].join(", "), movie[:rating], true
          Movier.say_rated "Actors", movie[:actors].join(", "), movie[:rating], true
          Movier.say_rated "Writers", movie[:writers].join(", "), movie[:rating], true if @params[:writer]
          Movier.say_rated "Plot", movie[:plot], movie[:rating], true
          Movier.say_rated "Tags", movie[:tags].join(", "), movie[:rating] if movie[:tags].any?
        else
          message = "#{"%03d" % counter}) #{nice_name}"
          Movier.say_rated Movier.titleize(movie[:type]), message, movie[:rating]
          rating = "#{movie[:rated]} at #{movie[:rating]} points with #{movie[:votes]} votes."
          Movier.say_rated "Rating", rating, movie[:rating]
          Movier.say_rated "Directors", movie[:directors].join(", "), movie[:rating], true if @params[:directors]
          Movier.say_rated "Actors", movie[:actors].join(", "), movie[:rating], true
          Movier.say_rated "Tags", movie[:tags].join(", "), movie[:rating] if movie[:tags].any?
        end
        puts
        counter += 1
      end
      return if @movies.empty?
      filtered = @movies

      # add some tags to this search
      if @params[:add_tags]
        tags = @params[:add_tags].split(",").map{|t| Movier.titleize(t.strip)}
        read_data
        filtered.each do |f|
          @movies.each_with_index do |m,i|
            @movies[i][:tags] |= tags if m[:id] == f[:id]
          end
        end
        write_data
        Movier.tip_now "Added tags: '#{tags.join(", ")}' to this search!"
      end

      # TODO: remove tags?

      message = "Do you want me to play #{@params[:shuffle] ? "this" : "some"} movie for you? [enter number from above] "
      begin; open = ask(message) {|x| x.default = "no" }; rescue Exception; end
      if open == "no" && @params[:shuffle]
        find @params
      elsif open && open.to_i > 0
        movie = filtered[open.to_i - 1]
        # TODO: fix this to use a pure ruby implementation
        require 'shellwords'
        nice_name = "#{movie[:title]} [#{movie[:year]}]"
        movie_dir = Shellwords.escape(movie[:path])
        movie_file = `find #{movie_dir} -type f`.strip.split("\n")
        movie_file = movie_file.select{|f| File.size(f) > 100 * 2**20}.first
        Movier.tip_now "Opening: #{nice_name} with VLC Player"
        `open '#{movie_file}' -a VLC &`
      end
    end

    def sort_movies
      @movies = @movies.sort_by {|movie| movie[:weight] }.reverse
    end

    # Update the local movie database,
    # by revisiting all tracked directories,
    # and building the database from there.
    #
    def update_itself
      message  = "Found no movie box in the local database.\n"
      message += "Please, run `movier add` to add some movie boxes, before updating me!"
      raise message if @boxes.empty?
      @movies = []
      write_data
      @boxes.each { |box| add(box) }
    end

    # Add a given directory to the local movie database.
    # The directory should be pre-organized using the Organize command.
    #
    # * *Args*    :
    #   - +dir+ -> directory to add to the local movie database
    #
    def add(dir = nil)
      dir = File.expand_path dir
      raise "No such directory!" unless File.directory?(dir)

      imdb = Dir.glob("#{dir}/**/imdb.txt")
      raise 'You should first run `movier organize` on this directory!' unless imdb.count > 0

      count = 0
      imdb.each do |file|
        movie = Movier.read_yaml file
        if in_database?(movie)
          # TODO: add the path with a "dup" key
          Movier.warn_with "#{movie[:imdb]["Title"]} - # #{movie[:imdb]["imdbRating"]} -  already exists in database!"
        elsif !in_database?(movie)
          @movies.push sanitize(movie, dir, file)
          count += 1
        end
      end

      @boxes.push dir unless @boxes.include? dir
      write_data

      Movier.passed_with "Added #{"%4d" % count} new movies in LMDB from: #{dir}"
      Movier.tip_now "LMDB now contains #{"%4d" % @movies.count} movies."
    end

    def sanitize(movie, dir, imdb_file)
      imdb = movie[:imdb]
      nice_name = "#{imdb["Title"]} [#{imdb["Year"]}]"
      hash = (Digest::MD5.new << nice_name).to_s.slice(0,8)
      data = {
        title:      imdb["Title"],
        year:       imdb["Year"],
        rated:      imdb["Rated"],
        released:   imdb["Released"],
        runtime:    imdb["Runtime"],
        genre:      make_parts(imdb["Genre"]),
        directors:  make_parts(imdb["Director"]),
        writers:    make_parts(imdb["Writer"]),
        actors:     make_parts(imdb["Actors"]),
        plot:       imdb["Plot"],
        poster:     imdb["Poster"],
        _poster:    File.join(dir, nice_name, "poster#{File.extname(imdb["Poster"])}"),
        rating:     imdb["imdbRating"].to_f,
        votes:      imdb["imdbVotes"].to_s.delete(",").to_i,
        type:       imdb["Type"],
        id:         imdb["imdbID"],
        hash:       hash.force_encoding("UTF-8"),
        tags:       [],
        box:        dir,
        path:       File.dirname(imdb_file)
      }
      data[:weight] = (data[:rating] * data[:votes]).to_i
      data
    end

    def make_parts(string, delimiter = ",")
      string.split(delimiter).map{|x| x.strip}
    end

    def in_database?(movie)
      @movies.select{|m| m[:id] == movie[:imdb]["imdbID"]}.any?
    end
  end

  def self.read_yaml(file)
    YAML.load_file(file)
  end

  def self.write_yaml(file, data)
    File.open(file, "w") {|f| f.puts data.to_yaml }
  end
end
