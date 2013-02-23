module Movier
  def self.say_with_status(status, message, colorscheme = nil)
    # Create a color scheme, naming color patterns with symbol names.
    ft = HighLine::ColorScheme.new do |cs|
      cs[:regular]     = [ ]
      cs[:above8]      = [:bold, :green]
      cs[:above6]      = [:bold, :yellow]
      cs[:below6]      = [:red]
      cs[:information] = [ :bold, :cyan ]
      cs[:success]     = [ :green ]
      cs[:error]       = [ :bold, :red]
      cs[:warning]     = [ :bold, :yellow ]

    end

    # Assign that color scheme to HighLine...
    HighLine.color_scheme = ft

    # default color scheme
    colorscheme ||= :regular

    status += " " * (15 - status.length)
    message = message.gsub("'", %q(\\\')).split.each_slice(10).map{|x| x.join(" ") }
    message = message.join("\n" + " " * 20)
    say("<%= color('    #{status} #{message}', '#{colorscheme}') %>")

  end

  def self.say_rated(status, message, rating)
    rating = rating.to_f
    scheme = :below6 if rating < 6
    scheme = :above6 if rating >= 6
    scheme = :above8 if rating >= 8
    say_with_status status, message, scheme
  end

  def self.show_info(message)
    # message += "\n" + "=" * message.length
    say_with_status "Information", message, :information
  end

  def self.say_success(message)
    say_with_status "Success", message, :success
  end

  def self.say_warning(message)
    say_with_status "Warning", message, :warning
  end

  def self.show_error(message)
    say_with_status "ERROR", message, :error
    raise message
  end
end
