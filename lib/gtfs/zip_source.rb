module GTFS
  class ZipSource < Source
    def load_archive(source)
      source_file, _, fragment = source.partition('#')
      tmpdir = create_tmpdir
      self.class.extract_nested(source_file, fragment, tmpdir)
      # Return unzipped path and source zip file
      return tmpdir, source_file
    rescue Zip::Error => e
      raise InvalidZipException.new(e.message)
    rescue StandardError => e
      raise InvalidSourceException.new(e.message)
    end

    def self.extract_nested(filename, source, tmpdir)
      # Recursively extract GTFS CSV files from (possibly nested) Zips.
      source, _, fragment = source.partition('#')
      source = "." if source == ""
      source = URI::decode(source)
      Zip::File.open(filename) do |zip|
        zip.entries.each do |entry|
          entry_dir, entry_name = File.split(entry.name)
          entry_ext = File.extname(entry_name)
          if entry_dir == source && SOURCE_FILES.key?(entry_name)
            entry.extract(File.join(tmpdir, entry_name))
          elsif entry.name == source && entry_ext == '.zip'
            extract_entry_zip(entry) do |tmppath|
              extract_nested(tmppath, fragment, tmpdir)
            end
          end
        end
      end
      tmpdir
    end

    def self.find_gtfs_paths(filename)
      # Find internal paths to valid GTFS data inside (possibly nested) Zips.
      dirs = find_paths(filename)
        .select { |dir, files| required_files_present?(files) }
        .keys
    end

    def self.exists?(source)
      source, _, fragment = source.partition('#')
      File.exists?(source)
    end

    private

    def self.find_paths(filename, basepath: nil, limit: 1000, count: 0)
      # Recursively inspect a Zip archive, returning a directory index.
      # Nested zip files will have the form:
      #   nested.zip#inner_path
      dirs = {}
      # Build paths manually, to avoid extra / at end
      Zip::File.open(filename) do |zip|
        zip.entries.each do |entry|
          raise Exception.new("Too many files") if count > limit
          count += 1
          entry_dir, entry_name = File.split(entry.name)
          entry_dir = "" if entry_dir == "."
          entry_dir = (basepath + entry_dir) if basepath
          entry_ext = File.extname(entry_name)
          dirs[entry_dir] ||= Set.new
          if entry_ext == '.zip'
            extract_entry_zip(entry) do |tmppath|
              result = find_paths(
                tmppath,
                basepath: (basepath || "") + entry.name + '#',
                limit: limit,
                count: count
              )
              dirs = dirs.merge(result)
            end
          else
            dirs[entry_dir] << entry_name
          end
        end
      end
      dirs
    end

    def self.extract_entry_zip(entry)
      # Extract a Zip entry to a temporary file.
      entry_dir, entry_name = File.split(entry.name)
      Tempfile.open(entry_name) do |tmpfile|
        tmpfile.binmode
        tmpfile.write(entry.get_input_stream.read)
        tmpfile.close
        yield tmpfile.path
        tmpfile.unlink
      end
    end
  end

  # Backwards compatibility
  class LocalSource < ZipSource
  end

end
