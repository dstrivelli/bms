require 'bms/result'

module BMS
  CPU_ORDERS_OF_MAGNITUDE = {
    m: 1000,
    n: 1000000000,
  }.freeze

  RAM_ORDERS_OF_MAGNITUDE = {
    Ki: 1000,
    Mi: 1000000,
  }.freeze

  def self.convert_cores(cores)
    unit = cores[-1].to_sym
    count = cores[0..-2].to_f
    if CPU_ORDERS_OF_MAGNITUDE[unit]
      (count / CPU_ORDERS_OF_MAGNITUDE[unit]).round(2)
    else
      count.round(2)
    end
  end

  def self.convert_ram(ram)
    unit = ram[-2].to_sym
    count = ram[0..-3].to_f
    if RAM_ORDERS_OF_MAGNITUDE[unit]
      (count / RAM_ORDERS_OF_MAGNITUDE[unit]).round(2)
    else
      count.round(2)
    end
  end
end # BMS   
