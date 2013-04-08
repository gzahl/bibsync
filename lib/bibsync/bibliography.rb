module BibSync
  class Bibliography
    include Enumerable

    attr_reader :file
    attr_accessor :save_hook

    def initialize(file = nil)
      @entries, @save_hook = {}, nil
      load(file)
    end

    def dirty?
      @dirty
    end

    def dirty!
      @dirty = true
    end

    def empty?
      @entries.empty?
    end

    def size
      @entries.size
    end

    def [](key)
      @entries[key.to_s]
    end

    def delete(entry)
      if @entries.include?(entry.key)
        @entries.delete(entry.key)
        entry.bibliography = nil
        dirty!
      end
    end

    def clear
      unless @entries.empty?
        @entries.clear
        dirty!
      end
    end

    def relative_path(file)
      raise 'No filename given' unless @file
      bibpath = File.absolute_path(File.dirname(@file))
      Pathname.new(file).realpath.relative_path_from(Pathname.new(bibpath)).to_s
    end

    def each(&block)
      @entries.each_value(&block)
    end

    def save(file = nil)
      if file
        @file = file
        @parent_path = nil
        dirty!
      end

      raise 'No filename given' unless @file
      if @dirty
        @save_hook.call(self) if @save_hook
        File.open("#{@file}.tmp", 'w') {|f| f.write(self) }
        File.rename("#{@file}.tmp", @file)
        @dirty = false
        true
      else
        false
      end
    end

    def <<(entry)
      raise 'Entry has no key' if !entry.key || entry.key.empty?
      raise 'Entry is already existing' if @entries.include?(entry.key)
      entry.bibliography = self
      @entries[entry.key] = entry
      dirty!
    end

    def load(file)
      parse(File.read(file)) if file && File.exists?(file)
      @file = file
      @dirty = false
    end

    def load!(file)
      parse(File.read(file))
      @file = file
      @dirty = false
    end

    def parse(text)
      until text.empty?
        case text
        when /\A(\s+|%[^\n]+\n)/
          text = $'
        else
          entry = Entry.new
          text = entry.parse(text)
          entry.key ||= "entry#{@entries.size}" # Number of entries for comment id
          self << entry
        end
      end
    end

    def to_s
      "% #{DateTime.now}\n% Encoding: UTF8\n\n" <<
        @entries.values.join("\n") << "\n"
    end
  end
end
