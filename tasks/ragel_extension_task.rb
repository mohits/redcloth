module Rake
  class RagelExtensionTask < ExtensionTask
    RAGEL_INCLUDE_PATTERN = /include \w+ "([^"]+)";/
    
    attr_accessor :source_files
    attr_accessor :rl_dir
    
    def init(name = nil, gem_spec = nil)
      super
      
      @lang     = "c"
      @rl_dir = "ragel"
      define_tasks
    end
    
    def source_files
      @source_files = ["#{@ext_dir}/redcloth_scan.c", "#{@ext_dir}/redcloth_inline.c", "#{@ext_dir}/redcloth_attributes.c"]
      
      # @source_files ||= FileList["#{@ext_dir}/#{@source_pattern}"]
    end
    
    def define_tasks
      %w(scan inline attributes).each do |machine|
        file target(machine) => [*ragel_sources(machine)] do
          mkdir_p(File.dirname(target(machine))) unless File.directory?(File.dirname(target(machine)))
          ensure_ragel_version(target(machine)) do
            sh "ragel #{flags} #{lang_ragel(machine)} -o #{target(machine)}"
          end
        end
        
        file extconf => [target(machine)]
      end
    end

    def target(machine)
      {
        'scan' => {
          'c'    => "#{@ext_dir}/redcloth_scan.c",
          'java' => "#{@ext_dir}/RedclothScanService.java",
          'rb'   => "#{@ext_dir}/redcloth_scan.rb"
        },
        'inline' => {
          'c'    => "#{@ext_dir}/redcloth_inline.c",
          'java' => "#{@ext_dir}/RedclothInline.java",
          'rb'   => "#{@ext_dir}/redcloth_inline.rb"
        },
        'attributes' => {
          'c'    => "#{@ext_dir}/redcloth_attributes.c",
          'java' => "#{@ext_dir}/RedclothAttributes.java",
          'rb'   => "#{@ext_dir}/redcloth_attributes.rb"
        }
      }[machine][@lang]
    end

    def lang_ragel(machine)
      "#{@rl_dir}/redcloth_#{machine}.#{@lang}.rl"
    end

    def ragel_sources(machine)
      deps = [lang_ragel(machine), ragel_file_dependencies(lang_ragel(machine))].flatten.dup
      deps += ["#{@ext_dir}/redcloth.h"] if @lang == 'c'
      deps
      # FIXME: merge that header file into other places so it can be eliminated?
    end
    
    def ragel_file_dependencies(ragel_file)
      found = find_ragel_includes(ragel_file)
      found + found.collect {|file| ragel_file_dependencies(file)}
    end
    
    def find_ragel_includes(file)
      File.open(file).grep(RAGEL_INCLUDE_PATTERN) { $1 }.map do |file|
        "#{@rl_dir}/#{file}"
      end
    end

    def flags
      # FIXME: reinstate @code_style being passed from optimize rake task?
      code_style_flag = preferred_code_style ? " -" + preferred_code_style : ""
      "-#{host_language_flag}#{code_style_flag}"
    end

    def host_language_flag
      {
        'c'      => 'C',
        'java'   => 'J',
        'rb'     => 'R'
      }[@lang]
    end

    def preferred_code_style
      {
        'c'      => 'T0',
        'java'   => nil,
        'rb'     => 'F1'
      }[@lang]
    end

    def ensure_ragel_version(name)
      @ragel_v ||= `ragel -v`[/(version )(\S*)/,2].split('.').map{|s| s.to_i}
      if @ragel_v[0] > 6 || (@ragel_v[0] == 6 && @ragel_v[1] >= 3)
        yield
      else
        STDERR.puts "Ragel 6.3 or greater is required to generate #{name}."
        exit(1)
      end
    end
    
  end
end