# frozen_string_literal: true

module RuboCop
  module Cop
    module Homecart
      class ServiceClassName < Base
        MSG = "Service classes in app/services must end with Service."

        def on_class(node)
          return unless processed_source.file_path.include?("/app/services/")

          class_name = node.identifier.const_name
          return if class_name&.end_with?("Service")

          add_offense(node.identifier)
        end
      end
    end
  end
end
