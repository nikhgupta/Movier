module Movier

  # Fetch information about a movie from IMDB.com
  #
  # * *Args*    :
  #   - +id+ -> IMDB.com id for the movie
  # * *Returns* :
  #   - hash of movie information
  # * *Raises* :
  #   - +RuntimeError+ -> error that occurred when making a request to the API
  #
  def self.fetch_details(id)
    response           = omdbapi({ i: id })
    response["votes"]  = response["imdbVotes"].delete(",").to_i
    response["rating"] = response["imdbRating"].to_f
    response["weight"] = response["votes"] * response["rating"]
    response
  end

  # Search for a title on IMDB.com
  #
  # * *Args*    :
  #   - +keyword+ -> keywords to search with
  #   - +year+ -> (optional) year in which the title was released
  #   - +type+ -> (default: movie) type of the title to return
  # * *Returns* :
  #   - hash with the information about movie titles found
  # * *Raises* :
  #   - +RuntimeError+ -> error that occurred when making a request to the API
  #
  def self.search(keyword, year = nil, type = "Movie")
    response = omdbapi({ s: keyword })["Search"]
    response = response.select{ |m| m["Type"].downcase == type.downcase } unless type.downcase == "all"
    response = response.select{ |m| m["Year"] == year } if year
    response
  end

  # Make a request to OMDBApi.com
  #
  # * *Args*    :
  #   - +params+ -> hash of params to pass with this request
  # * *Returns* :
  #   - hash of response received
  # * *Raises* :
  #   - +RuntimeError+ -> error that occurred when making a request to the API
  #
  def self.omdbapi(params)
    query = ""; params.each { |k, v| query += "#{k}=#{v}" }
    response = HTTParty.get("http://omdbapi.com/?#{URI::encode(query)}")
    failed_with response.response unless response.success?
    response = response.parsed_response if response.is_a?(String)
    failed_with response["Error"] if response["Error"]
    response
  end

end
