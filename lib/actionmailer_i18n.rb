module ActionMailer
  class Base
    # Make translate method available
    def translate(key, options = {})
      I18n.translate(key, options.merge(:locale => self.locale))
    end
    alias_method :t, :translate

    # Make localize method available
    def localize(key, options = {})
      I18n.localize(key, options.merge(:locale => self.locale))
    end
    alias_method :l, :localize

    # setter/getter for locale
    def locale
      @locale
    end

    def locale=(locale)
      @locale = locale
    end

    # overwrite the create! method to add localization awareness
    def create!(method_name, *parameters) #:nodoc:
      initialize_defaults(method_name)
      __send__(method_name, *parameters)
      
      # If an explicit, textual body has not been set, we check assumptions.
      unless String === @body
        # First, we look to see if there are any likely templates that match,
        # which include the content-type in their file name (i.e.,
        # "the_template_file.text.html.erb", etc.). Only do this if parts
        # have not already been specified manually.
        if @parts.empty?
          # Start find with name.content-type.locale.*
          dg = Dir.glob("#{template_path}/#{@template}.*.#{@locale}.*")
          # Continue find withouth content-type
          dg = Dir.glob("#{template_path}/#{@template}.#{@locale}.*") unless dg.any?
          # Finally go for just the name
          dg = Dir.glob("#{template_path}/#{@template}.*") unless dg.any?
          dg.each do |path|
            template = template_root["#{mailer_name}/#{File.basename(path)}"]

            # Skip unless template has a multipart format
            next unless template && template.multipart?

            @parts << Part.new(
              :content_type => template.content_type,
              :disposition => "inline",
              :charset => charset,
              :body => render_message(template, @body)
            )
          end
          unless @parts.empty?
            @content_type = "multipart/alternative" if @content_type !~ /^multipart/
            @parts = sort_parts(@parts, @implicit_parts_order)
          end
        end

        # Then, if there were such templates, we check to see if we ought to
        # also render a "normal" template (without the content type). If a
        # normal template exists (or if there were no implicit parts) we render
        # it.
        localised_template_exists = false
        template_exists = @parts.empty?
        if template_exists
          # render the localised template if available
          localised_template_exists = template_root["#{mailer_name}/#{@template}.#{@locale}"]
          @body = render_message("#{@template}.#{@locale}", @body) if localised_template_exists
        end
        template_exists ||= template_root["#{mailer_name}/#{@template}"]
        @body = render_message(@template, @body) if template_exists unless localised_template_exists

        # Finally, if there are other message parts and a textual body exists,
        # we shift it onto the front of the parts and set the body to nil (so
        # that create_mail doesn't try to render it in addition to the parts).
        if !@parts.empty? && String === @body
          @parts.unshift Part.new(:charset => charset, :body => @body)
          @body = nil
        end
      end

      # If this is a multipart e-mail add the mime_version if it is not
      # already set.
      @mime_version ||= "1.0" if !@parts.empty?

      # build the mail object itself
      @mail = create_mail
    end
  end
end