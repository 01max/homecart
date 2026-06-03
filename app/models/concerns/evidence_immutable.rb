# Application-level guard for append-only receipt evidence.
#
# Including models declare immutable attributes with
# {.immutable_evidence_attributes}. Updates that would change those attributes
# fail validation; database triggers provide the corresponding SQL-level guard.
module EvidenceImmutable
  extend ActiveSupport::Concern

  included do
    class_attribute :immutable_evidence_attribute_names, default: []

    validate :immutable_evidence_attributes_are_unchanged, on: :update
  end

  class_methods do
    # Declare attributes that cannot change after initial persistence.
    #
    # @param attribute_names [Array<Symbol, String>] model attributes to protect
    # @return [Array<String>] normalized protected attribute names
    def immutable_evidence_attributes(*attribute_names)
      self.immutable_evidence_attribute_names = attribute_names.map(&:to_s)
    end
  end

  private

  def immutable_evidence_attributes_are_unchanged
    immutable_evidence_attribute_names.each do |attribute_name|
      errors.add(attribute_name, :immutable) if will_save_change_to_attribute?(attribute_name)
    end
  end
end
