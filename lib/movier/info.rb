module Movier
  # Find and return information about a movie with the given keywords
  #
  # * *Args*    :
  #   - +keyword+ -> keywords to search for in movie title
  #   - +options+ -> hash that alters the behavior of the search
  #                  if +:year+ key is specified, restricts search to that year
  #                  if +:detailed+ key is specified, shows detailed results
  def self.info(keyword, options)
    lmdb = Movier::LMDB.new
    movies = search(keyword, options[:year], options[:all] ? "all" : "movie")
    movies.each do |m|
      m = fetch_details m["imdbID"]
      nice_name = m["Title"] + " [" + m["Year"] + "]"
      next if m["votes"] < 1000 && !options[:all]
      if options[:detailed]
        tip_now nice_name, titleize(m["Type"])
        rating = "#{m["Rated"]} at #{m["imdbRating"]} points with #{m["imdbVotes"]} votes"
        say_rated "Rating", rating, m["rating"]
        say_rated "Plot", m["Plot"], m["rating"], true
        say_rated "Actors", m["Actors"], m["rating"], true
        say_rated "Runtime", m["Runtime"], m["rating"]
        say_rated "Genre", m["Genre"], m["rating"]
        puts
      else
        message = "#{nice_name} @ #{m["imdbRating"]} ( #{m["imdbVotes"]} votes )"
        type = lmdb.lookup(m["imdbID"]) ? "Available Movie" : "Movie"
        say_rated titleize(type), message, m["rating"]
      end
    end
  end
end
