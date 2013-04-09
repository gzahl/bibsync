module BibSync
  class Entry
    include Enumerable
    extend Forwardable

    attr_accessor :bibliography, :type
    attr_reader :key
    def_delegators :@fields, :empty?, :size, :each

    def self.parse(text)
      Entry.new.tap {|e| e.parse(text) }
    end

    def initialize(fields = {})
      self.key = fields.delete(:key) if fields.include?(:key)
      self.type = fields.delete(:type) if fields.include?(:type)
      @fields = fields
    end

    def key=(key)
      key = key.to_s
      raise 'Key cannot be empty' if key.empty?
      if bib = bibliography
        bib.delete(self)
        @key = key
        bib << self
      else
        @key = key
      end
    end

    def file=(file)
      raise 'No bibliography set' unless bibliography
      file =~ /\.(\w+)\Z/
      self[:file] = ":#{bibliography.relative_path(file)}:#{$1.upcase}" # JabRef file format "description:path:type"
      file
    end

    def file
      if self[:file]
        raise 'No bibliography set' unless bibliography
        _, file, type = self[:file].split(':', 3)
        path = File.join(File.absolute_path(File.dirname(bibliography.file)), file)
        { name: File.basename(path), type: type.upcase.to_sym, path: path }
      end
    end

    def [](key)
      @fields[convert_key(key)]
    end

    def []=(key, value)
      if value
        key = convert_key(key)
        value = Literal === value ? Literal.new(value.to_s.strip) : value.to_s.strip
        if @fields[key] != value || @fields[key].class != value.class
          @fields[key] = value
          dirty!
        end
      else
        delete(key)
      end
    end

    def delete(key)
      key = convert_key(key)
      if @fields.include?(key)
        @fields.delete(key)
        dirty!
      end
    end

    def comment?
      type.to_s.downcase == 'comment'
    end

    def dirty!
      bibliography.dirty! if bibliography
    end

    def to_s
      s = "@#{type}{"
      if comment?
        s << self[:comment]
      else
        s << "#{key},\n" << to_a.map {|k,v| Literal === v ? "  #{k} = #{v}" : "  #{k} = {#{v}}" }.join(",\n") << "\n"
      end
      s << "}\n"
    end

    def parse(text)
      raise 'Unexpected token' if text !~ /\A\s*@(\w+)\s*\{/
      self.type = $1
      text = $'

      if comment?
        text, self[:comment] = parse_field(text)
      else
        raise 'Expected entry key' if text !~ /([^,]+),\s*/
        self.key = $1.strip
        text = $'

        until text.empty?
          case text
          when /\A(\s+|%[^\n]+\n)/
            text = $'
          when /\A\s*(\w+)\s*=\s*/
            text, key = $', $1
            if text =~ /\A\{/
              text, self[key] = parse_field(text)
            else
              text, value = parse_field(text)
              self[key] = Literal.new(value)
            end
          else
            break
          end
        end
      end

      raise 'Expected closing }' unless text =~ /\A\s*\}/
      $'
    end

    private

    def parse_field(text)
      value = ''
      count = 0
      until text.empty?
        case text
        when /\A\{/
          text = $'
          value << $& if count > 0
          count += 1
        when /\A\}/
          break if count == 0
          count -= 1
          text = $'
          value << $& if count > 0
        when /\A,/
          text = $'
          break if count == 0
          value << $&
        when /\A[^\}\{,]+/
          text = $'
          value << $&
        else
          break
        end
      end

      raise 'Expected closing }' if count != 0

      return text, value
    end

    def convert_key(key)
      key.to_s.downcase.to_sym
    end
  end
end
