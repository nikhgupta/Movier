module Movier

  # ask a user for a directory path, until we find one
  #
  # * *Args*    :
  #   - +message+ -> question to show to the user
  # * *Returns* :
  #   - path to the provided directory
  #
  def self.ask_for_directory(message = nil)
    message ||= "Please, provide a directory path to use. "
    dir = nil
    until dir && File.directory?(dir)
      warn_with "Found no such directory!" if dir
      dir = ask(message) { |x| x.default = ENV['HOME'] }
    end
    dir
  end

  # colorize output based on a movie's rating
  #
  # * *Args*    :
  #   - +status+ -> status for this message
  #   - +message+ -> actual message
  #   - +rating+ -> rating for this movie
  #
  def self.say_rated(status, message, rating, do_break = false)
    rating = rating.to_f
    scheme = :below6 if rating < 6
    scheme = :above6 if rating >= 6
    scheme = :above8 if rating >= 8
    say_with_status status, message, scheme, do_break
  end

  # titleize a string
  #
  # * *Args*    :
  #   - +string+ -> string that will be titleized
  # * *Returns* :
  #   - titleized string
  #
  def self.titleize(string)
    string.gsub(/\w+/) { |word| word.capitalize }
  end

  # find the imdb.txt file for a given movie path
  # this file is created by Movier, once the movie has been parsed
  #
  # * *Args*    :
  #   - +movie_path+ -> path to the movie being checked
  # * *Returns* :
  #   - path to the imdb.txt file for the given movie path
  #
  def self.imdb_file_for(movie_path)
    File.join(File.dirname(movie_path), "imdb.txt")
  end

  # check whether the movie with given path has already been organized
  #
  # * *Args*    :
  #   - +movie_path+ -> path to the movie being checked
  # * *Returns* :
  #   - true, if the movie has been organized. false, otherwise
  #
  def self.organized?(movie_path)
    File.exists?(imdb_file_for(movie_path))
  end

  def self.read_yaml(file)
    YAML.load_file(file)
  end

  def self.write_yaml(file, data)
    File.open(file, "w") {|f| f.puts data.to_yaml }
  end

end
