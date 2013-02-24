module Movier
  # say something in a nicely formatted way
  #
  # * *Args*    :
  #   - +status+ -> status for this message
  #   - +message+ -> actual message
  #   - +colorscheme+ -> color scheme to be used for this message
  def self.say_with_status(status, message, colorscheme = nil, do_break = false)
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
    status += " " * (20 - status.length)
    message = message.gsub("'", %q(\\\'))
    if do_break
      message = message.split.each_slice(10).map{|x| x.join(" ") }
      message = message.join("\n" + " " * 25)
    end
    say("<%= color('    #{status} #{message}', '#{colorscheme}') %>")
  end

  def self.tip_now(message, status="Information", do_break = false)
    say_with_status status, message, :information, do_break
  end

  def self.passed_with(message, do_break = false)
    say_with_status "Success", message, :success, do_break
  end

  def self.warn_with(message, do_break = false)
    say_with_status "Warning", message, :warning, do_break
  end

  def self.failed_with(message, do_break = false)
    say_with_status "ERROR", message, :error, do_break
    raise message
  end
end
