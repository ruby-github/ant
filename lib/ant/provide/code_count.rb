module Provide
  class CodeCount
    attr_reader :counters

    def initialize
      @counters = []
    end

    def counter file
      counter_lines IO.readlines(file), File.extname(file)
    end

    def counter_lines lines, extname
      language extname

      @comment      = false
      @comment_flag = true
      @quote1       = false
      @quote2       = false

      @counters = []

      lines.each do |line|
        line = line.utf8

        @counters << [count_line(line), line]

        if not @continue_quote
          if @continue_line
            if line[-@continue_line.size..-1] != @continue_line
              @quote1 = false
              @quote2 = false
            end
          else
            @quote1 = false
            @quote2 = false
          end
        end
      end

      count
    end

    def count counters = nil
      counters ||= @counters

      total_lines = counters.size
      code_lines = 0
      comment_lines = 0
      empty_lines = 0

      counters.each do |x|
        case x.first
        when :code_line
          code_lines += 1
        when :comment_line
          comment_lines += 1
        when :code_comment_line
          code_lines += 1
          comment_lines += 1
        when :empty_line
          empty_lines += 1
        else
          code_lines += 1
        end
      end

      [total_lines, code_lines, comment_lines, empty_lines]
    end

    private

    def count_line line
      line.strip!

      if line.empty?
        if not @continue_quote
          @quote1 = false
          @quote2 = false
        end

        :empty_line
      else
        if @comment
          if @comment_flag
            comment_pos = line.index @comment_off
          else
            comment_pos = line.index @comment_off2
          end

          if comment_pos
            @comment = false

            line = line[comment_pos + @comment_off.size .. -1].strip

            if not line.empty?
              if [:code_line, :code_comment_line].include? count_line(line)
                return :code_comment_line
              end
            end
          end

          :comment_line
        else
          if @quote1 or @quote2
            if @quote1
              pos = line.index @quotation1

              if pos
                if @escape
                  if pos == 0 or line[pos - 1 .. pos - 1] != @escape
                    @quote1 = false
                  end
                else
                  @quote1 = false
                end

                line = line[pos + @quotation1.size .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? count_line(line)
                    return :code_comment_line
                  end
                end
              end
            else
              pos = line.index @quotation2

              if pos
                if @escape
                  if pos == 0 or line[pos - 1 .. pos - 1] != @escape
                    @quote2 = false
                  end
                else
                  @quote2 = false
                end

                line = line[pos + @quotation2.size .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? count_line(line)
                    return :code_comment_line
                  end
                end
              end
            end

            :code_line
          else
            comment_pos = nil
            comment_line_flag = false
            comment_len = 0

            if @line_comment and line.index(@line_comment)
              comment_pos = line.index @line_comment
              comment_line_flag = true
              comment_len = @line_comment.size
            end

            if @line_comment2 and line.index(@line_comment2)
              comment_pos = line.index @line_comment2
              comment_line_flag = true
              comment_len = @line_comment2.size
            end

            if @comment_on and line.index(@comment_on)
              tmp_comment_pos = line.index @comment_on

              if not comment_pos or tmp_comment_pos < comment_pos
                comment_pos = tmp_comment_pos
                @comment_flag = true
                comment_len = @comment_on.size
              end
            end

            if @comment_on2 and line.index(@comment_on2)
              tmp_comment_pos = line.index @comment_on2

              if not comment_pos or tmp_comment_pos < comment_pos
                comment_pos = tmp_comment_pos
                @comment_flag = false
                comment_len = @comment_on2.size
              end
            end

            quote_pos = nil
            quote1_flag = false
            quote_len = 0

            if @quotation1 and line.index(@quotation1)
              quote_pos = line.index @quotation1
              quote1_flag = true
              quote_len = @quotation1.size
            end

            if @quotation2 and line.index(@quotation2)
              tmp_quote_pos = line.index @quotation2

              if not quote_pos or tmp_quote_pos < quote_pos
                quote_pos = tmp_quote_pos
                quote1_flag = false
                quote_len = @quotation2.size
              end
            end

            if comment_pos
              if quote_pos and quote_pos < comment_pos
                if quote1_flag
                  @quote1 = true
                else
                  @quote2 = true
                end

                line = line[quote_pos + quote_len .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? count_line(line)
                    return :code_comment_line
                  end
                end

                :code_line
              else
                if not comment_line_flag
                  @comment = true

                  line = line[comment_pos + comment_len .. -1].strip

                  if not line.empty?
                    if [:code_line, :code_comment_line].include? count_line(line)
                      return :code_comment_line
                    end
                  end
                end

                if comment_pos > 0
                  :code_comment_line
                else
                  :comment_line
                end
              end
            else
              if quote_pos
                if quote1_flag
                  @quote1 = true
                else
                  @quote2 = true
                end

                line = line[quote_pos + quote_len .. -1].strip

                if not line.empty?
                  if [:comment_line, :code_comment_line].include? count_line(line)
                    return :code_comment_line
                  end
                end
              end

              :code_line
            end
          end
        end
      end
    end

    def language extname
      extname.downcase!

      @line_comment   = nil
      @line_comment2  = nil
      @comment_on     = nil
      @comment_off    = nil
      @comment_on2    = nil
      @comment_off2   = nil
      @quotation1     = nil
      @quotation2     = nil
      @continue_quote = false
      @continue_line  = nil
      @escape         = nil
      @case           = true

      case extname
      when
        # ASM
        '.asm'
        @line_comment   = ';'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = false
      when
        # C#
        '.cs',
        # C/C++
        '.c', '.cc', '.cpp', '.cxx', '.h', '.hh', '.hpp', '.hxx',
        # IDL
        '.idl', '.odl',
        # Java
        '.java',
        # JavaFX
        '.fx',
        # JavaScript
        '.es', '.js',
        # RC
        '.rc', '.rc2'
        @line_comment   = '//'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @continue_line  = '\\'
        @escape         = '\\'
        @case           = true
      when
        # HTML
        '.htm', '.html', '.shtml'
        @comment_on     = '<!--'
        @comment_off    = '-->'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = false
      when
        # Lua
        '.lua'
        @line_comment   = '--'
        @comment_on     = '--[['
        @comment_off    = ']]'
        @comment_on2    = '--[=['
        @comment_off2   = ']=]'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Pascal
        '.pas'
        @line_comment   = '//'
        @comment_on     = '(*'
        @comment_off    = '*)'
        @comment_on2    = '{'
        @comment_off2   = '}'
        @quotation1     = '\''
        @continue_quote = false
        @case           = false
      when
        # Perl
        '.pl', '.pm'
        @line_comment   = '--'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Python
        '.py', '.pyw'
        @line_comment   = '#'
        @comment_on     = '"""'
        @comment_off    = '"""'
        @comment_on2    = "'''"
        @comment_off2   = "'''"
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Ruby
        '.rake', '.rb', '.rbw'
        @line_comment   = '#'
        @comment_on     = '=begin'
        @comment_off    = '=end'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # SQL
        '.sql'
        @line_comment   = '--'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = false
      when
        # Tcl/Tk
        '.itcl', '.tcl'
        @line_comment   = '#'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @escape         = '\\'
        @case           = true
      when
        # VB
        '.bas', '.vb',
        # VBScript
        '.vbs'
        @line_comment   = '\''
        @line_comment2  = 'rem'
        @quotation1     = '"'
        @escape         = '\\'
        @case           = false
      when
        # VHDL
        '.vhd', '.vhdl'
        @line_comment   = '--'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = false
      when
        # Verilog
        '.v', '.vh'
        @line_comment   = '//'
        @comment_on     = '/*'
        @comment_off    = '*/'
        @quotation1     = '"'
        @continue_quote = false
        @escape         = '\\'
        @case           = true
      when
        # Windows Script Batch
        '.bat'
        @line_comment   = 'rem'
        @line_comment2  = '@rem'
        @quotation1     = '\''
        @quotation2     = '"'
        @continue_quote = false
        @case           = false
      when
        # XML
        '.axl', '.dtd', '.rdf', '.svg', '.xml', '.xrc', '.xsd', '.xsl', '.xslt', '.xul'
        @comment_on     = '<!--'
        @comment_off    = '-->'
        @quotation1     = '"'
        @quotation2     = '\''
        @continue_quote = true
        @case           = true
      end
    end
  end

  class CodeDiff
    attr_reader :diffs, :discard
    attr_accessor :context_line

    def initialize
      @diffs = {}
      @discard = []
      @context_line = 3
    end

    def diff file, diff_file
      diff_lines IO.readlines(file), IO.readlines(diff_file), file, diff_file
    end

    def diff_lines file_lines, diff_file_lines = nil, name = nil, diff_name = nil
      @diffs = {
        :names    => [
          name, diff_name
        ],
        :lines    => {},
        :discard  => []
      }

      lcs = diff_lcs file_lines, diff_file_lines

      a_index = 0
      b_index = 0

      @discard = []

      while b_index < lcs.size
        a_cur_index = lcs[b_index]

        if a_cur_index
          while a_index < a_cur_index
            discard_a a_index, file_lines[a_index]
            a_index += 1
          end

          match
          a_index += 1
        else
          discard_b b_index, diff_file_lines[b_index]
        end

        b_index += 1
      end

      while b_index < diff_file_lines.size
        discard_b b_index, diff_file_lines[b_index]
        b_index += 1
      end

      while a_index < file_lines.size
        discard_a a_index, file_lines[a_index]
        a_index += 1
      end

      match

      lcs.each_with_index do |i, index|
        if not i.nil?
          @diffs[:lines][index] = [i, diff_file_lines[index]]
        end
      end

      add_count = 0
      change_count = 0
      del_count = 0

      @diffs[:discard].each do |discard|
        add_lines = 0
        del_lines = 0

        discard.each do |action, index, line|
          case action
          when '+'
            add_lines += 1
          when '-'
            del_lines += 1
          end
        end

        change_count += [add_lines, del_lines].min

        if add_lines >= del_lines
          add_count += add_lines - del_lines
        else
          del_count += del_lines - add_lines
        end
      end

      [add_count, change_count, del_count]
    end

    def to_diff
      string_io = StringIO.new
      offset = 0

      @diffs[:discard].each do |discard|
        action = discard[0][0]
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          string_io.puts diff_range(first + 1, first + del_count) + 'd' + (first + offset).to_s
        elsif del_count == 0
          string_io.puts (first - offset).to_s + 'a' + diff_range(first + 1, first + add_count)
        else
          string_io.puts diff_range(first + 1, first + del_count) + 'c' + diff_range(first + offset + 1, first + offset + add_count)
        end

        if action == '-'
          last_del = true
        else
          last_del = false
        end

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            string_io.print '< '
          elsif action == '+'
            offset += 1

            if last_del
              last_del = false
              string_io.puts '---'
            end

            string_io.print '> '
          end

          string_io.print line
        end
      end

      string_io.string.strip
    end

    def to_diff_context
      string_io = StringIO.new

      file, diff_file = @diffs[:names]

      if File.file? file
        string_io.puts '*** ' + file + "\t" + File.mtime(file).to_s
      else
        string_io.puts '*** ' + file.to_s
      end

      if File.file? diff_file
        string_io.puts '--- ' + diff_file + "\t" + File.mtime(diff_file).to_s
      else
        string_io.puts '--- ' + diff_file.to_s
      end

      offset = 0
      keys = @diffs[:lines].keys

      @diffs[:discard].each do |discard|
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          a_start = first + 1
          b_start = first + offset + 1
        elsif del_count == 0
          a_start = first - offset + 1
          b_start = first + 1
        else
          a_start = first + 1
          b_start = first + offset + 1
        end

        a_count = del_count
        b_count = add_count

        prefix_lines = []
        suffix_lines = []

        (a_start - 1).times.to_a.reverse.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          prefix_lines.unshift @diffs[:lines][i].last
        end

        ((a_start + a_count - 1)..keys.last).to_a.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          suffix_lines.push @diffs[:lines][i].last
        end

        string_io.puts '***************'

        a_lines = []
        b_lines = []

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            a_lines << line
          elsif action == '+'
            offset += 1
            b_lines << line
          end
        end

        if a_lines.empty? or b_lines.empty?
          action = nil
        else
          action = '! '
        end

        string_io.puts "*** #{a_start - prefix_lines.size},#{a_start + a_count - 1 + suffix_lines.size} ****"

        if not a_lines.empty?
          prefix_lines.each do |line|
            string_io.print '  ' + line
          end

          a_lines.each do |line|
            string_io.print (action || '- ') + line
          end

          suffix_lines.each do |line|
            string_io.print '  ' + line
          end
        end

        if not ["\r", "\n"].include? string_io.string[-1]
          string_io.puts
        end

        string_io.puts "--- #{b_start - prefix_lines.size},#{b_start + b_count - 1 + suffix_lines.size} ----"

        if not b_lines.empty?
          prefix_lines.each do |line|
            string_io.print '  ' + line
          end

          b_lines.each do |line|
            string_io.print (action || '+ ') + line
          end

          suffix_lines.each do |line|
            string_io.print '  ' + line.rstrip
          end
        end
      end

      string_io.string.strip
    end

    def to_diff_unified
      string_io = StringIO.new

      file, diff_file = @diffs[:names]

      if File.file? file
        string_io.puts '--- ' + file + "\t" + File.mtime(file).to_s
      else
        string_io.puts '--- ' + file.to_s
      end

      if File.file? diff_file
        string_io.puts '+++ ' + diff_file + "\t" + File.mtime(diff_file).to_s
      else
        string_io.puts '+++ ' + diff_file.to_s
      end

      offset = 0
      keys = @diffs[:lines].keys

      @diffs[:discard].each do |discard|
        first = discard[0][1]

        add_count = 0
        del_count = 0

        discard.each do |action, index, line|
          if action == '+'
            add_count += 1
          elsif action == '-'
            del_count += 1
          end
        end

        if add_count == 0
          a_start = first + 1
          b_start = first + offset + 1
        elsif del_count == 0
          a_start = first - offset + 1
          b_start = first + 1
        else
          a_start = first + 1
          b_start = first + offset + 1
        end

        a_count = del_count
        b_count = add_count

        prefix_lines = []
        suffix_lines = []

        (a_start - 1).times.to_a.reverse.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          prefix_lines.unshift @diffs[:lines][i].last
        end

        ((a_start + a_count - 1)..keys.last).to_a.each_with_index do |i, index|
          if index >= @context_line or not keys.include?(i)
            break
          end

          suffix_lines.push @diffs[:lines][i].last
        end

        string_io.puts "@@ -#{a_start - prefix_lines.size},#{a_count + prefix_lines.size + suffix_lines.size} +#{b_start - prefix_lines.size},#{b_count + prefix_lines.size + suffix_lines.size} @@"

        prefix_lines.each do |line|
          string_io.print ' ' + line
        end

        discard.each do |action, index, line|
          if action == '-'
            offset -= 1
            string_io.print '-'
          elsif action == '+'
            offset += 1
            string_io.print '+'
          end

          string_io.print line
        end

        suffix_lines.each do |line|
          string_io.print ' ' + line
        end
      end

      string_io.string.strip
    end

    private

    def diff_lcs a, b
      a_start = 0
      a_finish = a.size - 1

      b_start = 0
      b_finish = b.size - 1

      lcs = []

      while a_start <= b_finish and b_start <= b_finish and a[a_start] == b[b_start]
        lcs[b_start] = a_start

        a_start += 1
        b_start += 1
      end

      while a_start <= a_finish and b_start <= b_finish and a[a_finish] == b[b_finish]
        lcs[b_finish] = a_finish

        a_finish -= 1
        b_finish -= 1
      end

      a_matches = reverse_hash a, a_start..a_finish
      thresh = []
      links = []

      (b_start..b_finish).each do |i|
        if not a_matches.has_key? b[i]
          next
        end

        index = nil

        a_matches[b[i]].reverse.each do |j|
          if index and thresh[index] > j and thresh[index - 1] < j
            thresh[index] = j
          else
            index = replace_next_larger thresh, j, index
          end

          if not index.nil?
            if index == 0
              links[index] = [nil, i, j]
            else
              links[index] = [links[index - 1], i, j]
            end
          end
        end
      end

      if not thresh.empty?
        link = links[thresh.size - 1]

        while link
          lcs[link[1]] = link[2]
          link = link[0]
        end
      end

      lcs
    end

    def diff_range a, b
      if a == b
        a.to_s
      else
        [a, b].join ','
      end
    end

    def reverse_hash obj, range = nil
      map = {}
      range ||= 0...obj.size

      range.each do |i|
        map[obj[i]] ||= []
        map[obj[i]] << i
      end

      map
    end

    def replace_next_larger obj, val, high = nil
      high ||= obj.size

      if obj.empty? or val > obj[-1]
        obj << val

        return high
      end

      low = 0

      while low < high
        index = (low + high) / 2
        found = obj[index]

        if val == found
          return nil
        end

        if val > found
          low = index + 1
        else
          high = index
        end
      end

      obj[low] = val

      low
    end

    def discard_a index, line
      @discard << ['+', index, line]
    end

    def discard_b index, line
      @discard << ['-', index, line]
    end

    def match
      if not @discard.empty?
        @diffs[:discard] << @discard
      end

      @discard = []
    end
  end
end