module Puppet::Parser::Functions
  newfunction(
    :guess_es_version,
    :type => :rvalue,
    :doc => <<-'ENDHEREDOC') do |args|
      Given a number of arguments, attempt to determine which version of
      Elasticsearch is defined in the first string that can be parsed.

      Example:

        guess_es_version('unused', 'version/string/2.4.1.ext')
        # Would return: "2.4.1"
    ENDHEREDOC

    if args.length < 1
      raise Puppet::ParseError, ("guess_es_version(): wrong number of arguments (#{args.length}; must be at least 1)")
    end

    # Father, forgive me
    regex = /-?(?<version>[0-9]+(?:[.](?:[0-9]+|[a-z]))*)(?:-[0-9]+)?(?:[.](?=[a-z])[0-9a-z]+)*$/

    args.each do |str|
      next unless str.is_a? String

      if (m = regex.match str)
        return m[1] if not m[1].nil?
      end
    end

    raise Puppet::ParseError, 'could not determine Elasticsearch version'
  end
end
