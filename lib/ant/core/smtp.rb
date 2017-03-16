require 'net/smtp'

module Net
  module_function

  # args
  #   admin
  #   authtype
  #   bcc
  #   cc
  #   file
  #   html
  #   port
  #   password
  #   subject
  #   text
  #   username
  def send_smtp address, from_address, to_address, args = nil
    if not $sendmail
      return true
    end

    address ||= $smtp_address
    from_addr ||= $smtp_fromaddress

    args = {
      :username => $smtp_username,
      :password => $smtp_password,
      :cc       => $smtp_cc,
      :admin    => $smtp_admin
    }.merge (args || {})

    args[:port] ||= 25
    args[:authtype] ||= :login

    begin
      SMTP.start address, args[:port], '127.0.0.1', args[:username], args[:password], args[:authtype] do |smtp|
        mail = MailFactory.new
        mail.from = from_address.to_s
        mail.subject = args[:subject].to_s

        if not args[:text].nil?
          mail.text = args[:text].to_s
        end

        if not args[:html].nil?
          mail.html = args[:html].to_s
        end

        addrs = []

        if not to_address.nil?
          addrs += to_address.to_array
          mail.to = to_address.to_array.join ', '
        else
          if not args[:admin].nil?
            addrs = args[:admin].to_array
            mail.to = args[:admin].to_array.join ', '
          end
        end

        if not args[:cc].nil?
          addrs += args[:cc].to_array
          mail.cc = args[:cc].to_array.join ', '
        end

        if not args[:bcc].nil?
          addrs += args[:bcc].to_array
          mail.bcc = args[:bcc].to_array.join ', '
        end

        addrs.uniq!

        if addrs.empty?
          return true
        end

        if not args[:file].nil?
          args[:file].to_array.each do |file|
            mail.attach file.locale
          end
        end

        if block_given?
          yield mail
        end

        begin
          smtp.open_message_stream from_address, addrs do |file|
            file.puts mail.to_s
          end

          LOG_INFO 'send mail to %s' % addrs.join(', ')

          true
        rescue
          LOG_ERROR 'send mail to %s fail' % addrs.join(', ')
          LOG_EXCEPTION $!

          if not args[:admin].nil?
            smtp.open_message_stream from_addr, args[:admin].to_array do |file|
              file.puts mail.to_s
            end
          end

          false
        end
      end
    rescue
      LOG_EXCEPTION $!

      false
    end
  end
end

# A simple to use module for generating RFC compliant MIME mail
# ---
# = Usage:
#
#   mail = MailFactory.new
#   mail.to = 'test@test.com'
#   mail.from = 'sender@sender.com'
#   mail.subject = 'Here are some files for you!'
#   mail.text = 'This is what people with plain text mail readers will see'
#   mail.html = 'A little something <b>special</b> for people with HTML readers'
#   mail.attach '/etc/fstab'
#   mail.attach '/some/other/file'
#
#   Net::SMTP.start 'smtp1.testmailer.com', 25, 'mail.from.domain', fromaddress, password, :cram_md5 do |smtp|
#     mail.to = toaddress
#     smtp.send_message mail.to_s, fromaddress, toaddress
#   end

module MIME
  class Types
    def Types::type_for filename
      ''
    end
  end
end

# An easy class for creating a mail message
class MailFactory
  def initialize
    @headers = []
    @attachments = []
    @attachmentboundary = generate_boundary
    @bodyboundary = generate_boundary
    @html = nil
    @text = nil
    @charset = 'utf-8'
  end

  def add_header header, value
    if header == 'subject'
      value = quoted_printable_with_instruction value, @charset
    end

    if ['from', 'to', 'cc', 'bcc', 'reply-to'].include? header.downcase
      value = quote_address_if_necessary value, @charset
    end

    @headers << "#{header}: #{value}"
  end

  def remove_header header
    @headers.each_index do |i|
      if @headers[i] =~ /^#{Regexp.escape(header)}:/i
        @headers.delete_at i
      end
    end
  end

  def set_header header, value
    remove_header header
    add_header header, value
  end

  def replyto= newreplyto
    remove_header 'Reply-To'
    add_header 'Reply-To', newreplyto
  end

  def replyto
    get_header('Reply-To')[0]
  end

  def text= newtext
    @text = newtext
  end

  def html= newhtml
    @html = [
      '<html>',
      '  <head>',
      '    <meta content="text/html;charset=%s" http-equiv="Content-Type">' % @charset,
      '  </head>',
      '  <body bgcolor="#ffffff" text="#000000">',
      '  %s' % newhtml,
      '  </body>',
      '</html>'
    ].join "\n"
  end

  def rawhtml= newhtml
    @html = newhtml
  end

  def method_missing m, *args
    name = m.id2name

    if name =~ /_/
      name = name.gsub /_/, '-'
    elsif name =~ /[A-Z]/
      name = name.gsub /([a-zA-Z])([A-Z])/, '\1-\2'
    end

    if name =~ /=$/
      if args.length != 1
        super m, args
      end

      set_header name[/^(.*)=$/, 1], args[0]
    else
      if args.length != 0
        super m, args
      end

      headers = get_header name
      get_header name
    end
  end

  def get_header header
    headers = []
    headerregex = /^#{Regexp.escape(header)}:/i

    @headers.each do |h|
      if headerregex.match(h)
        headers << h[/^[^:]+:(.*)/i, 1].strip
      end
    end

    headers
  end

  def multipart?
    if @attachments.length > 0 or @html != nil
      true
    else
      false
    end
  end

  def construct options = {}
    if options[:date].nil?
      options[:date] = true
    end

    if options[:messageid]
      remove_header 'Message-ID'
      sendingdomain = get_header('from')[0].to_s[/@([-a-zA-Z0-9._]+)/,1].to_s
      add_header 'Message-ID', "<#{Time.now.to_f()}.#{Process.euid()}.#{String.new.object_id()}@#{sendingdomain}>"
    end

    if options[:date]
      if get_header('Date').length == 0
        add_header 'Date', Time.now.strftime('%a, %d %b %Y %H:%M:%S %z')
      end
    end

    if multipart?
      if get_header('MIME-Version').length == 0
        add_header 'MIME-Version', '1.0'
      end

      if get_header('Content-Type').length == 0
        if @attachments.length == 0
          add_header 'Content-Type', "multipart/alternative;boundary=\"#{@bodyboundary}\""
        else
          add_header 'Content-Type', "multipart/mixed; boundary=\"#{@attachmentboundary}\""
        end
      end
    end

    "#{headers_to_s}#{body_to_s}"
  end

  def to_s
    construct :messageid => true
  end

  def generate_boundary
    randomstring = []

    1.upto(25) do
      whichglyph = rand 100

      if whichglyph < 40
        randomstring << (rand(25) + 65).chr
      elsif whichglyph < 70
        randomstring << (rand(25) + 97).chr
      elsif whichglyph < 90
        randomstring << (rand(10) + 48).chr
      elsif whichglyph < 95
        randomstring << '.'
      else
        randomstring << '_'
      end
    end

    "----=_NextPart_#{randomstring.join}"
  end

  def add_attachment filename, type=nil, attachmentheaders = nil
    attachment = {}
    attachment['filename'] = Pathname.new(filename).basename

    if type.nil?
      attachment['mimetype'] = MIME::Types.type_for(filename).to_s
    else
      attachment['mimetype'] = type
    end

    File.open(filename, 'rb') do |fp|
      attachment['attachment'] = file_encode fp.read
    end

    if not attachmentheaders.nil?
      if not attachmentheaders.kind_of? Array
        attachmentheaders = attachmentheaders.split /\r?\n/
      end

      attachment['headers'] = attachmentheaders
    end

    @attachments << attachment
  end

  def add_attachment_as file, emailfilename, type = nil, attachmentheaders = nil
    attachment = {}
    attachment['filename'] = emailfilename

    if not type.nil?
      attachment['mimetype'] = type.to_s
    elsif file.kind_of?(String) or file.kind_of?(Pathname)
      attachment['mimetype'] = MIME::Types.type_for(file.to_s).to_s
    else
      attachment['mimetype'] = ''
    end

    if file.kind_of?(String) or file.kind_of?(Pathname)
      File.open(file.to_s, 'rb') do |fp|
        attachment['attachment'] = file_encode fp.read
      end
    elsif file.respond_to? :read
      attachment['attachment'] = file_encode file.read
    else
      raise Exception, 'file is not a supported type (must be a String, Pathnamem, or support read method)'
    end

    if not attachmentheaders.nil?
      if not attachmentheaders.kind_of? Array
        attachmentheaders = attachmentheaders.split /\r?\n/
      end

      attachment['headers'] = attachmentheaders
    end

    @attachments << attachment
  end

  alias attach add_attachment
  alias attach_as add_attachment_as

  protected

  def headers_to_s
    "#{@headers.join("\r\n")}\r\n\r\n"
  end

  def body_to_s
    body = []

    if !multipart?
      @text
    else
      body << "This is a multi-part message in MIME format.\r\n\r\n--#{@attachmentboundary}\r\nContent-Type: multipart/alternative; boundary=\"#{@bodyboundary}\""

      if @attachments.length > 0
        body << "#{buildbodyboundary("text/plain; charset=#{@charset}; format=flowed", 'quoted-printable')}\r\n\r\n#{quote_if_necessary(@text, @charset)}"

        if @html
          body << "#{buildbodyboundary("text/html; charset=#{@charset}", 'quoted-printable')}\r\n\r\n#{quote_if_necessary(@html, @charset)}"
        end

        body << "--#{@bodyboundary}--"

        if @attachments.length > 0
          @attachments.each do |attachment|
            body << "#{buildattachmentboundary(attachment)}\r\n\r\n#{attachment['attachment']}"
          end

          body << "\r\n--#{@attachmentboundary}--"
        end
      else
        body << "#{buildbodyboundary("text/plain; charset=#{@charset}; format=flowed", 'quoted-printable')}\r\n\r\n#{quote_if_necessary(@text, @charset)}"
        body << "#{buildbodyboundary("text/html; charset=#{@charset}", 'quoted-printable')}\r\n\r\n#{quote_if_necessary(@html, @charset)}"
        body << "--#{@bodyboundary}--"
      end

      body.join "\r\n\r\n"
    end
  end

  def buildattachmentboundary attachment
    disposition = "Content-Disposition: inline; filename=\"#{attachment['filename']}\""
    boundary = "--#{@attachmentboundary}\r\nContent-Type: #{attachment['mimetype']}; name=\"#{attachment['filename']}\"\r\nContent-Transfer-Encoding: base64\r\n#{disposition}"

    if attachment['headers']
      boundary = boundary + "\r\n#{attachment['headers'].join("\r\n")}"
    end

    boundary
  end

  def buildbodyboundary type, encoding
    "--#{@bodyboundary}\r\nContent-Type: #{type}\r\nContent-Transfer-Encoding: #{encoding}"
  end

  def file_encode str
    collection = []
    enc = [str].pack 'm'

    enc
  end

  def quoted_printable_with_instruction text, charset
    text = quoted_printable_encode_header text

    "=?#{charset}?Q?#{text}?="
  end

  def quoted_printable_encode text
    [text].pack('M').gsub(/\n/, "\r\n").chomp.gsub(/=$/, '')
  end

  def quoted_printable_encode_header text
    text = text.enum_for(:each_byte).map do |ord|
      if ord < 128 and ord != 61 # 61 is ascii '='
        ord.chr
      else
        '=%X' % ord
      end
    end.join('')

    text.chomp.gsub(/=$/,'').gsub('?', '=3F').gsub('_', '=5F').gsub(/ /, '_')
  end

  def quote_if_necessary text, charset, instruction = false
    if not text
      return
    end

    if text.respond_to? :force_encoding
      text = text.dup.force_encoding Encoding::ASCII_8BIT
    end

    if instruction
      quoted_printable_with_instruction text, charset
    else
      quoted_printable_encode text
    end
  end

  def quote_address_if_necessary address, charset
    if Array === address
      address.map { |a| quote_address_if_necessary a, charset }
    elsif address =~ /^(\S.*)\s+(<.*>)$/
      address = $2
      phrase = quote_if_necessary $1.gsub(/^['"](.*)['"]$/, '\1'), charset, true

      "\"#{phrase}\" #{address}"
    else
      address
    end
  end
end