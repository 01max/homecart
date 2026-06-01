module EvidenceImmutable
  extend ActiveSupport::Concern

  included do
    class_attribute :immutable_evidence_attribute_names, default: []

    validate :immutable_evidence_attributes_are_unchanged, on: :update
  end

  class_methods do
    def immutable_evidence_attributes(*attribute_names)
      self.immutable_evidence_attribute_names = attribute_names.map(&:to_s)
    end
  end

  private

  def immutable_evidence_attributes_are_unchanged
    immutable_evidence_attribute_names.each do |attribute_name|
      errors.add(attribute_name, "is immutable") if will_save_change_to_attribute?(attribute_name)
    end
  end
end
