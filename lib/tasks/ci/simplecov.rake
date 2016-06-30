require 'simplecov'

namespace :ci do
  namespace :simplecov do
    desc 'GitLab CI | Merge all coverage results and generate report'
    task merge: :environment do
      merged_result.format!
    end

    private

    def read(file)
      return unless File.exist?(file)
      data = File.read(file)
      return if data.nil? || data.length < 2
      data
    end

    def load(file)
      begin
        JSON.parse(read(file))
      rescue
        {}
      end
    end

    def files
      Dir.glob(File.join(SimpleCov.coverage_path, '*/.resultset.json'))
    end

    def resultsfiles
      files.map { |file| load(file) }
    end

    def resultsets
      resultsfiles.reduce({}, :merge)
    end

    def all_results
      results = []
      resultsets.each do |command_name, data|
        result = SimpleCov::Result.from_hash(command_name => data)
        # Only add result if the timeout is above the configured threshold
        if (Time.now - result.created_at) < SimpleCov.merge_timeout
          results << result
        end
      end
      results
    end

    def merged_result
      merged = {}
      results = all_results
      results.each do |result|
        merged = result.original_result.merge_resultset(merged)
      end
      result = SimpleCov::Result.new(merged)
      # Specify the command name
      result.command_name = results.map(&:command_name).sort.join(", ")
      result
    end
  end
end
