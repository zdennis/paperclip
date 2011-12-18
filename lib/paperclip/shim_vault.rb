# This is a shim to bridge the new vault infrastructure with the old :storage
# module infrastructure.
# Any methods that magically appear in this class come from a module that is
# dynamically loaded. The two queue i-vars are used by the dynamically-loaded
# module. Hence, the shim and new vault infrastructure.
module Paperclip
  class ShimVault
    def initialize(attachment, options)
      @queued_for_write = {}
      @queued_for_delete = []
      @options = options
      @attachment = attachment

      initialize_storage
    end

    def store(key, filehandle)
      @queued_for_write[key] = filehandle
    end

    def save
      flush_deletes unless @options[:keep_old_files]
      flush_writes
      true
    end

    def clear(styles)
      styles_with_paths = style_path_map(styles)
      @queued_for_delete += [:original, *styles_with_paths.keys].uniq.map do |style|
        styles_with_paths[style] if exists?(style)
      end.compact
      @queued_for_write = {}
    end

    def destroy(styles)
      clear(styles)
      save
    end

    def path(style_name = default_style)
      if file_attached?
        path = interpolate(path_option, style_name)
        path.respond_to?(:unescape) ? path.unescape : path
      else
        nil
      end
    end

    # also responds to #to_file

    private

    def file_attached?
      !@attachment.original_filename.nil?
    end

    def initialize_storage
      storage_class_name = @options[:storage].to_s.downcase.camelize
      begin
        storage_module = Paperclip::Storage.const_get(storage_class_name)
      rescue NameError
        raise StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
      end
      self.extend(storage_module)
    end

    def path_option
      @options[:path].respond_to?(:call) ? @options[:path].call(self) : @options[:path]
    end

    def interpolate(pattern, style_name)
      @options[:interpolator].interpolate(pattern, self, style_name)
    end

    def style_path_map(styles)
      styles.inject({:original => path(:original)}) do |result, (style_name, _)|
        result.merge(style_name => path(style_name))
      end
    end

    def log(*a)
      @attachment.__send__(:log,*a)
    end

    def hash(*a)
      @attachment.hash(*a)
    end

    def method_missing(method_name, *arguments)
      if @attachment.respond_to?(method_name)
        @attachment.__send__(method_name, *arguments)
      else
        super
      end
    end

    def respond_to?(method_name)
      @attachment.respond_to?(method_name) || super
    end
  end
end
