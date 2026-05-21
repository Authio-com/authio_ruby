# frozen_string_literal: true

module Authio
  class Error < StandardError
    attr_reader :code, :status

    def initialize(code:, message:, status: 500)
      super(message)
      @code = code
      @status = status
    end
  end
end
