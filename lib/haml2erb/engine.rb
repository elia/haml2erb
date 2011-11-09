require 'haml'

module Haml2Erb

  # puts RUBY_VERSION

  class Engine < Haml::Engine
    def push_silent(text, can_suppress = false)
      flush_merged_text
      return if can_suppress && options[:suppress_eval]
      # WAS:
      # @precompiled << "#{resolve_newlines}#{text}\n"
      # @output_line += text.count("\n") + 1

      push_script(text,
        :preserve_script => @node.value[:preserve],
        :escape_html => @node.value[:escape_html],
        :silent => true)
    end

    def compile_haml_comment
      text = @node.value[:text]
      return if text.empty?

      push_script(text,
        :preserve_script => @node.value[:preserve],
        :escape_html => @node.value[:escape_html],
        :silent => true, :comment => true)
    end

    def compile_silent_script
      return if @options[:suppress_eval]
      keyword = @node.value[:keyword]
      @output_tabs -= 1 if Haml::Parser::MID_BLOCK_KEYWORDS.include?(keyword)

      push_silent(@node.value[:text])
      ruby_block = block_given? && !keyword


      if block_given?
        # Store these values because for conditional statements,
        # we want to restore them for each branch
        @node.value[:dont_indent_next_line] = @dont_indent_next_line
        @node.value[:dont_tab_up_next_text] = @dont_tab_up_next_text

        @output_tabs += 1
        yield
        @output_tabs -= 1

        push_silent("end", :can_suppress) unless @node.value[:dont_push_end]
      elsif keyword == "end"
        if @node.parent.children.last.equal?(@node)
          # Since this "end" is ending the block,
          # we don't need to generate an additional one
          @node.parent.value[:dont_push_end] = true
        end
        # Don't restore dont_* for end because it isn't a conditional branch.
      elsif Haml::Parser::MID_BLOCK_KEYWORDS.include?(keyword)
        @output_tabs += 1

        # Restore dont_* for this conditional branch
        @dont_indent_next_line = @node.parent.value[:dont_indent_next_line]
        @dont_tab_up_next_text = @node.parent.value[:dont_tab_up_next_text]
      end
    end

    def push_script text, opts={}
      tag_lead = opts[:silent] ? '' : '='
      tag_lead << '#' if opts[:comment]
      erb_tag = "<%#{tag_lead} #{text.strip} %>"

      # USED TO START HERE:
      return if options[:suppress_eval]

      args = %w[preserve_script in_tag preserve_tag escape_html nuke_inner_whitespace]
      args.map! {|name| opts[name.to_sym]}
      args << !block_given? << @options[:ugly]

      no_format = @options[:ugly] &&
        !(opts[:preserve_script] || opts[:preserve_tag] || opts[:escape_html])
      output_expr = "(#{text}\n)"
      static_method = "_hamlout.#{static_method_name(:format_script, *args)}"

      # Prerender tabulation unless we're in a tag
      push_merged_text '' unless opts[:in_tag]

      unless block_given?
        # WAS: push_generated_script(no_format ? "#{text}\n" : "#{static_method}(#{output_expr});")
        push_generated_script(erb_tag.inspect)

        concat_merged_text("\n") unless opts[:in_tag] || opts[:nuke_inner_whitespace]

        # push_generated_script(erb_tag.inspect)
        # 
        # concat_merged_text("\n") unless opts[:in_tag] || opts[:nuke_inner_whitespace]

        # @output_tabs += 1
        return
      end

      flush_merged_text
      push_silent "haml_temp = #{text}"

      @output_tabs += 1 unless opts[:nuke_inner_whitespace]
      yield
      @output_tabs -= 1 unless opts[:nuke_inner_whitespace]

      push_silent('end', :can_suppress) unless @node.value[:dont_push_end]
      # COMMENTED: @precompiled << "_hamlout.buffer << #{no_format ? "haml_temp.to_s;" : "#{static_method}(haml_temp);"}"
      concat_merged_text("\n") unless opts[:in_tag] || opts[:nuke_inner_whitespace] || @options[:ugly]
    end

    def to_erb(scope = Object.new, locals = {}, &block)
      buffer = Haml::Buffer.new(scope.instance_variable_get('@haml_buffer'), options_for_buffer)

      if scope.is_a?(Binding) || scope.is_a?(Proc)
        scope_object = eval("self", scope)
        scope = scope_object.instance_eval{binding} if block_given?
      else
        scope_object = scope
        scope = scope_object.instance_eval{binding}
      end

      set_locals(locals.merge(:_hamlout => buffer, :_erbout => buffer.buffer), scope, scope_object)

      scope_object.instance_eval do
        extend Haml::Helpers
        @haml_buffer = buffer
      end

      eval(precompiled + ";" + precompiled_method_return_value,
        scope, @options[:filename], @options[:line])
    ensure
      # Get rid of the current buffer
      scope_object.instance_eval do
        @haml_buffer = buffer.upper if buffer
      end
    end

  end

end
