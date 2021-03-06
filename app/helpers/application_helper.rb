module ApplicationHelper

  def page_title
    title = ""
    title += content_for(:page_title) + " - " if content_for?(:page_title)
    title += "LittleSis"
    title
  end

	def centered_content(id=nil, &block)
		content_id = (id.nil? ? nil : id.to_s + "_content")
		str = content_tag("div", 
			content_tag("div", 
				"\n" + capture(&block) + "\n", 
				{ :class => "centered_content", :id => content_id },
				false
			), 
			{ :class => "centered", :id => id },
			false
		)			
		raw str
	end

  def excerpt(text, length=30)
    if text
      break_point = text.index(/[\s.,:;!?-]/, length-5)
      break_point = break_point ? break_point : length + 1
      text[0..break_point-1] + (text.length > break_point - 1 ? "..." : "")
    end
  end

  def more_link(content, max=nil, id=nil, make_raw=true)
  	splitter = "<!-- more -->"
  	if content.include? splitter or max.present?
	  	id = SecureRandom.hex(8) if id.blank?

      if content.include? splitter
    		preview, remainder = content.split(splitter)
      else
        full = strip_tags(content)
        preview = truncate(full, length: max, separator: ' ', escape: false, omission: '')
        remainder = full.gsub(preview, "")
      end

      if remainder.present?
    		str = "<span id='#{id}_preview'>"
    		str << preview
    		str << "</span><span style='display: none;' id='#{id}_remainder'>"
    		str << remainder
    		str << "</span>"
    		str << " <a class='more_link' data-target='#{id}' href='javascript:void(0);'>more &raquo;</a>"
      else
        str = preview
      end
    else
      str = content
  	end

    make_raw ? raw(str) : str
  end

  def show_link(content, id=nil)
    str = "<span id='#{id}_preview'>"
    str << "</span><span style='display: none;' id='#{id}_remainder'>"
    str << content
    str << "</span>"
    str << " <a class='more_link' data-target='#{id}' href='javascript:void(0);'>more &raquo;</a>"
  end

  def yes_or_no(value)
  	value ? "yes" : "no"
  end

  def check_mark(value=true)
		value ? raw("&#x2713;") : nil
  end

  def header_action(text, path)
    raw "<span class='btn btn-link btn-sm'>#{link_to text, path}</span>"
  end

  def notice_if_notice
    raw "<div class='alert alert-success'>#{notice}</div>" if notice
  end

  def dismissable_alert(id, &block)
    unless session[:dismissed_alerts].kind_of?(Array)
      session[:dismissed_alerts] = []
    end

    unless session[:dismissed_alerts].include? id
      content_tag("div", id: id, class: "alert alert-info alert-dismissable") do
        content_tag("button", raw("&times;"), class: "close", 'data-dismiss-id' => id) + capture(&block)
      end
    end
  end

  def legacy_login_path
    "/login"
  end

  def legacy_logout_path
    "/logout"
  end

  def legacy_signup_path
    "/join"
  end

  def home_groups_path
    "/home/groups"
  end

  def home_edits_path
    "/home/edits"
  end

  def home_settings_path
    "/home/settings"
  end

  def contact_path
    "/contact"
  end

  def tinymce_on_document_ready
    str = '<script type="text/javascript">'
    str += '$(document).ready(function() {'
    # str += "tinyMCE.init({ mode: 'textareas', theme: 'advanced' });"
    str += tinymce.gsub("<script>", "").gsub('</script>', '')
    str += '});'
    str += '</script>'
    raw(str)
  end

  def current_username
    return nil if current_user.nil?
    current_user.username
  end

  def has_legacy_permission(permission)
    current_user and current_user.has_legacy_permission(permission)
  end
end
