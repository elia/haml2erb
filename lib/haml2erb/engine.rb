require 'haml'
require 'haml2erb/attributes_parser'


module Haml2Erb
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
      push_generated_script erb_tag.inspect
      concat_merged_text("\n") unless opts[:in_tag] || opts[:nuke_inner_whitespace]
      
      # push_silent text

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


    def compile_tag
      t = @node.value

      # Get rid of whitespace outside of the tag if we need to
      rstrip_buffer! if t[:nuke_outer_whitespace]

      dont_indent_next_line =
        (t[:nuke_outer_whitespace] && !block_given?) ||
        (t[:nuke_inner_whitespace] && block_given?)

      if @options[:suppress_eval]
        object_ref = "nil"
        parse = false
        value = t[:parse] ? nil : t[:value]
        attributes_hashes = {}
        preserve_script = false
      else
        object_ref = t[:object_ref]
        parse = t[:parse]
        value = t[:value]
        attributes_hashes = t[:attributes_hashes]
        preserve_script = t[:preserve_script]
      end

      # Check if we can render the tag directly to text and not process it in the buffer
      if object_ref == "nil" && attributes_hashes.empty? && !preserve_script
        tag_closed = !block_given? && !t[:self_closing] && !parse

        open_tag = prerender_tag(t[:name], t[:self_closing], t[:attributes])
        if tag_closed
          open_tag << "#{value}</#{t[:name]}>"
          open_tag << "\n" unless t[:nuke_outer_whitespace]
        elsif !(parse || t[:nuke_inner_whitespace] ||
            (t[:self_closing] && t[:nuke_outer_whitespace]))
          open_tag << "\n"
        end

        push_merged_text(open_tag,
          tag_closed || t[:self_closing] || t[:nuke_inner_whitespace] ? 0 : 1,
          !t[:nuke_outer_whitespace])

        @dont_indent_next_line = dont_indent_next_line
        return if tag_closed
      else
        if attributes_hashes.empty?
          attributes_hashes = ''
        elsif attributes_hashes.size == 1
          attributes_hashes = ", #{attributes_hashes.first}"
        else
          attributes_hashes = ", (#{attributes_hashes.join(").merge(")})"
        end

        push_merged_text "<#{t[:name]}", 0, !t[:nuke_outer_whitespace]

        # WAS:
        # push_generated_script(
        #   "_hamlout.attributes(#{inspect_obj(t[:attributes])}, #{object_ref}#{attributes_hashes})")
        # NOW: attempt a simplistic parse of the attributes
        concat_merged_text AttributesParser.hash_to_html(t[:attributes])+
                           AttributesParser.new(attributes_hashes).to_html

        concat_merged_text(
          if t[:self_closing] && xhtml?
            " />" + (t[:nuke_outer_whitespace] ? "" : "\n")
          else
            ">" + ((if t[:self_closing] && html?
                      t[:nuke_outer_whitespace]
                    else
                      !block_given? || t[:preserve_tag] || t[:nuke_inner_whitespace]
                    end) ? "" : "\n")
          end)

        if value && !parse
          concat_merged_text("#{value}</#{t[:name]}>#{t[:nuke_outer_whitespace] ? "" : "\n"}")
        else
          @to_merge << [:text, '', 1] unless t[:nuke_inner_whitespace]
        end

        @dont_indent_next_line = dont_indent_next_line
      end

      return if t[:self_closing]

      if value.nil?
        @output_tabs += 1 unless t[:nuke_inner_whitespace]
        yield if block_given?
        @output_tabs -= 1 unless t[:nuke_inner_whitespace]
        rstrip_buffer! if t[:nuke_inner_whitespace]
        push_merged_text("</#{t[:name]}>" + (t[:nuke_outer_whitespace] ? "" : "\n"),
          t[:nuke_inner_whitespace] ? 0 : -1, !t[:nuke_inner_whitespace])
        @dont_indent_next_line = t[:nuke_outer_whitespace]
        return
      end

      if parse
        push_script(value, t.merge(:in_tag => true))
        concat_merged_text("</#{t[:name]}>" + (t[:nuke_outer_whitespace] ? "" : "\n"))
      end
    end

  end
end
