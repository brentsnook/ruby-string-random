# -*- mode: ruby; coding: utf-8 -*-

# = strrand.rb: Generates a random string from a pattern
#
# Author:: Tama <repeatedly@gmail.com>
#
# StringRandom is derived from the String::Random written in Perl.
# See http://search.cpan.org/~steve/String-Random-0.22/

class StringRandom
  Upper  = ('A'..'Z').to_a
  Lower  = ('a'..'z').to_a
  Digit  = ('0'..'9').to_a
  Punct  = [33..47, 58..64, 91..96, 123..126].map do |range|
    range.map { |val| val.chr }
  end.flatten
  Any    = Upper | Lower | Digit | Punct
  Salt   = Upper | Lower | Digit | ['.', '/']
  Binary = (0..255).map { |val| val.chr }

  # These are the regex-based patterns.
  Pattern = {
    # These are the regex-equivalents.
    '.'  => Any,
    '\d' => Digit,
    '\D' => Upper | Lower | Punct,
    '\w' => Upper | Lower | Digit | ['_'],
    '\W' => Punct.reject { |val| val == '_' },
    '\s' => [' ', "\t"],
    '\S' => Upper | Lower | Digit | Punct,

    # These are translated to their double quoted equivalents.
    '\t' => ["\t"],
    '\n' => ["\n"],
    '\r' => ["\r"],
    '\f' => ["\f"],
    '\a' => ["\a"],
    '\e' => ["\e"]
  }
  # What's important is how they relate to the pattern characters.
  # These are the old patterns for rand_pattern.
  OldPattern = {
    'C' => Upper,
    'c' => Lower,
    'n' => Digit,
    '!' => Punct,
    '.' => Any,
    's' => Salt,
    'b' => Binary
  }

  def initialize(max = 10)
    @max   = max
    @old   = OldPattern.clone
    @regch = {
      "\\" => method(:regch_slash),
      '.'  => method(:regch_dot),
      '['  => method(:regch_bracket),
      '*'  => method(:regch_asterisk),
      '+'  => method(:regch_plus),
      '?'  => method(:regch_question),
      '{'  => method(:regch_brace)
    }
  end

  def rand_regex(patterns)
    return _rand_regex(patterns) unless patterns.instance_of?(Array)

    results = []
    patterns.each do |pattern|
      results << _rand_regex(pattern)
    end
    results
  end

  def [](key)
    @old[key]
  end

  def []=(key, val)
    @old[key] = val
  end

  def rand_pattern(pattern)

  end

  private

  def _rand_regex(pattern)
    string = []
    chars  = pattern.split(//)
    non_ch = /[\$\^\*\(\)\+\{\}\]\|\?]/  # not supported chars

    while ch = chars.shift
      if @regch.has_key?(ch)
        @regch[ch].call(ch, chars, string)
      else
        warn "'#{ch}' not implemented. treating literally." if ch =~ non_ch
        string << ch
      end
    end

    result = ''
    string.each do |ch|
      result << ch[rand(ch.size)]
    end
    result
  end

  # These characters are treated specially in randregex.
  def regch_slash(ch, chars, string)
    raise "regex not terminated" if chars.empty?

    tmp = chars.shift
    if tmp == 'x'
      # This is supposed to be a number in hex, so
      # there had better be at least 2 characters left.
      tmp = chars.shift + chars.shift
      string << tmp.hex.chr
    elsif tmp =~ /[0-7]/
      warn "octal parsing not implemented. treating literally."
      string << tmp
    elsif Pattern.has_key?(ch + tmp)
      string << Pattern[ch + tmp]
    else
      warn "'\\#{tmp}' being treated as literal '#{tmp}'"
      string << tmp
    end
  end

  def regch_dot(ch, chars, string)
    string << Pattern[ch]
  end

  def regch_bracket(ch, chars, string)
    tmp = []
    while ch = chars.shift and ch != ']'
      if ch == '-' and !chars.empty? and !tmp.empty?
        ch  = chars.shift
        num = tmp.last[0]
        max = ch[0]
        while num < max
          num += 1
          tmp << num.chr
        end
      else
        warn "${ch}' will be treated literally inside []" if ch =~ /\W/
        tmp << ch
      end
    end

    raise "unmatched []" if ch != ']'
    string << tmp
  end

  def regch_asterisk(ch, chars, string)
    chars.unshift("{0,}".split(""))
  end

  def regch_plus(ch, chars, string)
    chars.unshift("{1,}".split(""))
  end

  def regch_question(ch, chars, string)
    chars.unshift("{0,1}".split(""))
  end

  def regch_brace(ch, chars, string)
    # { isn't closed, so treat it literally.
    return string << ch unless chars.include?('}')

    tmp = ''
    while ch = chars.shift and ch != '}'
      raise "'#{ch}' inside {} not supported" unless ch =~ /[\d,]/
      tmp << ch
    end

    if tmp =~ /,/
      raise "malformed range {#{tmp}}" unless tmp =~ /^(\d*),(\d*)$/

      p local_variables
      p self.instance_variable_get("@max")
      min = $1.length.nonzero? ? $1.to_i : 0
      max = $2.length.nonzero? ? $2.to_i : @max
      puts "#{min.class} : #{max.class}"
      raise "bad range {#{tmp}}" if min > max

      tmp = (min == max ? min : min + rand(max - min + 1))
    else
      tmp = tmp.to_i
    end

    if tmp.nonzero?
      last = string.last
      (tmp - 1).times do
        string << last
      end
    else
      string.pop
    end
  end
end
