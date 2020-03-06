module BMS
  class Result < OpenStruct
    def load(path)
      @table = YAML.load(File.read(path))
    end
  end
end
