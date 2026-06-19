module Catalogue
  module ProductAlternativeGroups
    # Adds or removes variants from an explicit alternative group.
    class MembershipsController < BaseController
      before_action :load_product_alternative_group

      def create
        membership = @product_alternative_group.product_alternative_group_memberships.new(membership_params)

        if membership.save
          redirect_to catalogue_product_alternative_group_path(@product_alternative_group),
                      notice: t("product_catalog.product_alternative_group_memberships.create.success")
        else
          redirect_with_record_errors(catalogue_product_alternative_group_path(@product_alternative_group), membership)
        end
      end

      def destroy
        membership = @product_alternative_group.product_alternative_group_memberships.find(params[:id])
        membership.destroy!

        redirect_to catalogue_product_alternative_group_path(@product_alternative_group),
                    notice: t("product_catalog.product_alternative_group_memberships.destroy.success")
      end

      private

      def load_product_alternative_group
        @product_alternative_group = ProductAlternativeGroup.find(params[:product_alternative_group_id])
      end

      def membership_params
        params.require(:product_alternative_group_membership).permit(:product_variant_id, :equivalence)
      end
    end
  end
end
