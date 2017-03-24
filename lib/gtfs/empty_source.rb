require 'fileutils'

module GTFS
  class EmptySource < Source
    def valid?
      true
    end

    def cache(filename, &block)
      FileUtils.touch(filename) unless File.exists?(filename)
      super
    end
  end
end
