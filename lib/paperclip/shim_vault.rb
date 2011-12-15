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
      @queued_for_delete += [:original, *styles.keys].uniq.map do |style|
        styles[style] if exists?(style)
      end.compact
      @queued_for_write = {}
    end

    def destroy(styles)
      clear(styles)
      save
    end

    private

    def initialize_storage
      storage_class_name = @options[:storage].to_s.downcase.camelize
      begin
        storage_module = Paperclip::Storage.const_get(storage_class_name)
      rescue NameError
        raise StorageMethodNotFound, "Cannot load storage module '#{storage_class_name}'"
      end
      #puts "about to extend #{self.class.name} with #{storage_module.inspect}"
      self.extend(storage_module)
    end

    def path(*a)
      @attachment.path(*a)
    end

    def original_filename
      @attachment.original_filename
    end

    def log(*a)
      @attachment.__send__(:log,*a)
    end

    def default_style
      @attachment.default_style
    end
  end
end
