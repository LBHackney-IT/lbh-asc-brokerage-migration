class ProgressBar

  def initialize(total:, description:)
    @description  = description
    @total  = total
    @counter = 1
  end

  def set_total(total)
    @total = total
  end

  def increment
    complete = sprintf("%#.2f%%", ((@counter.to_f / @total.to_f) * 100))
    print "\r\e[0K#{@description} #{@counter}/#{@total} (#{complete})"
    @counter += 1
  end

end